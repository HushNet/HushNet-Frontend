import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hushnet_frontend/services/key_provider.dart';
import 'package:hushnet_frontend/services/node_service.dart';

/// Full X3DH + initial AES-GCM encrypt for each recipient device, then POST /sessions
Future<bool> createSession(String nodeUrl, String recipientUserId) async {
  final keyProvider = KeyProvider();
  final dio = Dio();
  final NodeService nodeService = NodeService();
  final String currentDeviceId = await nodeService.getCurrentDeviceId() ?? '';

  try {
    // 1) load identity (Ed25519) and X25519 preKey (we use preKey as IK for DH)
    final identityKeyPair = await keyProvider
        .getIdentityKeyPair(); // Ed25519 pair bytes
    final preKeyPair = await keyProvider.getPreKeyPair(); // X25519 pair bytes
    if (identityKeyPair == null || preKeyPair == null) {
      throw Exception('Missing identity or prekey on client');
    }

    // 2) get recipient devices (assumes these return X25519 pubs)
    final devices = await keyProvider.getUserDevicesKeys(recipientUserId);
    if (devices.isEmpty) {
      debugPrint('No devices for recipient');
      return false;
    }

    final x25519 = X25519();
    final aes = AesGcm.with256bits();

    final sessionsInit = <Map<String, dynamic>>[];

    // Loop on each device
    for (final device in devices) {
      if (device.deviceId == currentDeviceId) {
        // skip our own device
        continue;
      }
      // Parse recipient pubs from base64 -> bytes
      final recipientIdentityPub = base64Decode(device.prekeyPubkey); // must be X25519 bytes
      final recipientSpkPub = base64Decode(device.signedPrekeyPub);
      final recipientOpkPub = device.oneTimePrekeyPub != null
          ? base64Decode(device.oneTimePrekeyPub!)
          : null;


      // 1. generate ephemeral keypair (X25519)
      final ek = await keyProvider
          .generateEphemeralKeyPair(); // returns {'private', 'public'} bytes
      final ekPriv = ek['private']!;
      final ekPub = ek['public']!;

      // 2. prepare local preKey (used as IK_A in our scheme)
      final ikPriv = preKeyPair['private']!;
      final ikPub = preKeyPair['public']!;

      // 3. compute DHs
      // Build SimpleKeyPairData for our private keys
      final ikKeyPairData = SimpleKeyPairData(
        ikPriv,
        publicKey: SimplePublicKey(ikPub, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      final ekKeyPairData = SimpleKeyPairData(
        ekPriv,
        publicKey: SimplePublicKey(ekPub, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );

      // remote public keys
      final recipientSpkPublic = SimplePublicKey(
        recipientSpkPub,
        type: KeyPairType.x25519,
      );
      final recipientIkPublic = SimplePublicKey(
        recipientIdentityPub,
        type: KeyPairType.x25519,
      );

      // DH1 = DH(IK_A, SPK_B)
      final shared1 = await x25519.sharedSecretKey(
        keyPair: ikKeyPairData,
        remotePublicKey: recipientSpkPublic,
      );
      final bytes1 = await shared1.extractBytes();

      // DH2 = DH(EK_A, IK_B)
      final shared2 = await x25519.sharedSecretKey(
        keyPair: ekKeyPairData,
        remotePublicKey: recipientIkPublic,
      );
      final bytes2 = await shared2.extractBytes();

      // DH3 = DH(EK_A, SPK_B)
      final shared3 = await x25519.sharedSecretKey(
        keyPair: ekKeyPairData,
        remotePublicKey: recipientSpkPublic,
      );
      final bytes3 = await shared3.extractBytes();
      debugPrint("Alice EK pub: ${base64Encode(ekPub)}");
      debugPrint("Bob Signed PreKey pub: ${base64Encode(recipientSpkPub)}");
      // DH4 = DH(EK_A, OPK_B) if present
      List<int> bytes4 = [];
      if (recipientOpkPub != null) {
        final recipientOpkPublic = SimplePublicKey(
          recipientOpkPub,
          type: KeyPairType.x25519,
        );
        final shared4 = await x25519.sharedSecretKey(
          keyPair: ekKeyPairData,
          remotePublicKey: recipientOpkPublic,
        );
        bytes4 = await shared4.extractBytes();
      }

      // 4. concatenate DH bytes
      final combined = <int>[];
      combined.addAll(bytes1);
      combined.addAll(bytes2);
      combined.addAll(bytes3);
      combined.addAll(bytes4);
      debugPrint('DH1: ${base64Encode(bytes1)}');
      debugPrint('DH2: ${base64Encode(bytes2)}');
      debugPrint('DH3: ${base64Encode(bytes3)}');
      debugPrint('DH4: ${base64Encode(bytes4)}');
      debugPrint('Combined DH length: ${combined.length}');

      // 5. derive root key via HKDF-SHA256 (32 bytes)
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final rootKey = await hkdf.deriveKey(
        secretKey: SecretKeyData(combined),
        nonce: utf8.encode('HushNet-Salt'),
        info: utf8.encode('X3DH Root Key'),
      );
      final sendChainKey = await hkdf.deriveKey(
        secretKey: rootKey,
        nonce: utf8.encode('HushNet-Salt'),
        info: utf8.encode('HushNet-Send-Chain'),
      );

      final recvChainKey = await hkdf.deriveKey(
        secretKey: rootKey,
        nonce: utf8.encode('HushNet-Salt'),
        info: utf8.encode('HushNet-Recv-Chain'),
      );

      final ratchetAlgo = X25519();
      final ratchetPair = await ratchetAlgo.newKeyPair();
      final ratchetPub = await ratchetPair.extractPublicKey();
      final ratchetPriv = await ratchetPair.extractPrivateKeyBytes();

      final rootB64 = base64Encode(await rootKey.extractBytes());
      final sendB64 = base64Encode(await sendChainKey.extractBytes());
      final recvB64 = base64Encode(await recvChainKey.extractBytes());
      final ratchetPubB64 = base64Encode(ratchetPub.bytes);
      final ratchetPrivB64 = base64Encode(ratchetPriv);

      await keyProvider.secureStorage.write(
        key: "session_${device.deviceId}_root",
        value: rootB64,
      );
      await keyProvider.secureStorage.write(
        key: "session_${device.deviceId}_send_chain",
        value: sendB64,
      );
      await keyProvider.secureStorage.write(
        key: "session_${device.deviceId}_recv_chain",
        value: recvB64,
      );
      await keyProvider.secureStorage.write(
        key: "session_${device.deviceId}_ratchet_pub",
        value: ratchetPubB64,
      );
      await keyProvider.secureStorage.write(
        key: "session_${device.deviceId}_ratchet_priv",
        value: ratchetPrivB64,
      );
      await keyProvider.secureStorage.write(
        key: "session_${device.deviceId}_send_counter",
        value: "0",
      );
      await keyProvider.secureStorage.write(
        key: "session_${device.deviceId}_recv_counter",
        value: "0",
      );

      // 6. encrypt initial plaintext with AES-GCM-256 using rootKey
      final nonce = aes.newNonce();
      final plaintext = utf8.encode(
        'HushNet initial session message',
      ); // customize initial message as needed
      final secretBox = await aes.encrypt(
        plaintext,
        secretKey: rootKey,
        nonce: nonce,
      );

      // Combine nonce + ciphertext + mac
      final ciphertextBytes = <int>[];
      ciphertextBytes.addAll(nonce);
      ciphertextBytes.addAll(secretBox.cipherText);
      ciphertextBytes.addAll(secretBox.mac.bytes);

      final ciphertextB64 = base64Encode(Uint8List.fromList(ciphertextBytes));
      final ekPubB64 = base64Encode(ekPub);

      sessionsInit.add({
        'recipient_device_id': device.deviceId,
        'ephemeral_pubkey': ekPubB64,
        'sender_identity_pub': base64Encode(ikPub),
        'ciphertext': ciphertextB64,
        'otpk_used': device.oneTimePrekeyPub,
        'sender_prekey_pub': base64Encode(ikPub),
      });
    } // end for devices

    // 7) sign timestamp with Ed25519 identity key for authentication headers
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final ed = Ed25519();

    final signingPair = SimpleKeyPairData(
      identityKeyPair['private']!,
      publicKey: SimplePublicKey(
        identityKeyPair['public']!,
        type: KeyPairType.ed25519,
      ),
      type: KeyPairType.ed25519,
    );
    final signature = await ed.sign(
      utf8.encode(timestamp),
      keyPair: signingPair,
    );

    final headers = {
      'X-Identity-Key': base64Encode(identityKeyPair['public']!),
      'X-Timestamp': timestamp,
      'X-Signature': base64Encode(signature.bytes),
      'Content-Type': 'application/json',
    };

    final payload = {
      'recipient_user_id': recipientUserId,
      'sessions_init': sessionsInit,
    };

    final res = await dio.post(
      '$nodeUrl/sessions',
      data: payload,
      options: Options(headers: headers),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return true;
    } else {
      debugPrint('CreateSessionFull failed http: ${res.statusCode} ${res.data}');
      return false;
    }
  } catch (e, st) {
    debugPrint('createSessionFull error: $e');
    debugPrintStack(stackTrace: st);
    return false;
  }
}
