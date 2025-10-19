import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hushnet_frontend/models/pending_sessions.dart';
import 'package:hushnet_frontend/services/key_provider.dart';
import 'package:hushnet_frontend/services/node_service.dart';

class SessionService {
  final KeyProvider keyProvider = KeyProvider();
  final Dio dio = Dio();
  final NodeService nodeService = NodeService();

  Future<List<PendingSession>> getPendingSessions() async {
    final String? nodeUrl = await nodeService.getCurrentNodeUrl();
    final req = await keyProvider.sendSignedRequest("GET", "$nodeUrl/sessions/pending");
    final data = req.data;
    final List sessions = (data is List) ? data : (data['sessions'] ?? []);
    return sessions.map((s) => PendingSession.fromJson(s)).toList();
  }

  Future<void> processPendingSessions() async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final aes = AesGcm.with256bits();
    final x25519 = X25519();

    // Load local keys
    final preKey = await keyProvider.getPreKeyPair();
    final signedPreKey = await keyProvider.getSignedPreKey();
    final oneTimePreKeys = await keyProvider.getOneTimePreKeys();

    if (preKey == null || signedPreKey == null) {
      throw Exception('Missing local keys');
    }

    final pendingSessions = await getPendingSessions();

    for (final p in pendingSessions) {
      try {
        debugPrint('Processing pending session ${p.id}');

        final senderEphemeral = base64Decode(p.ephemeralPubkey);
        final senderPrekeyPub = base64Decode(p.senderPrekeyPub!);

        // Our keys (X25519)
        final ikPriv = preKey['private']!;
        final ikPub = preKey['public']!;
        final spkPriv = signedPreKey['private']!;
        final spkPub = signedPreKey['public']!;

        // Build local key pairs
        final ikPair = SimpleKeyPairData(
          ikPriv,
          publicKey: SimplePublicKey(ikPub, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );

        final spkPair = SimpleKeyPairData(
          spkPriv,
          publicKey: SimplePublicKey(spkPub, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );

        final senderIkPub = SimplePublicKey(senderPrekeyPub, type: KeyPairType.x25519);
        final ekAPub = SimplePublicKey(senderEphemeral, type: KeyPairType.x25519);
        debugPrint("Alice EK pub: ${base64Encode(senderEphemeral)}");
        debugPrint("Bob IK Priv: ${base64Encode(ikPriv)}");

        // DH1 = DH(SPK_B, IK_A)
        final dh1 = await x25519.sharedSecretKey(keyPair: spkPair, remotePublicKey: senderIkPub);
        final dh1Bytes = await dh1.extractBytes();

        // DH2 = DH(IK_B, EK_A)
        final dh2 = await x25519.sharedSecretKey(keyPair: ikPair, remotePublicKey: ekAPub);
        final dh2Bytes = await dh2.extractBytes();

        // DH3 = DH(SPK_B, EK_A)
        final dh3 = await x25519.sharedSecretKey(keyPair: spkPair, remotePublicKey: ekAPub);
        final dh3Bytes = await dh3.extractBytes();

        // (optional) DH4 = DH(OPK_B, EK_A)
        List<int> dh4Bytes = [];
        if (oneTimePreKeys.isNotEmpty) {
          final opk = oneTimePreKeys.first;
          final opkPair = SimpleKeyPairData(
            opk['private']!,
            publicKey: SimplePublicKey(opk['public']!, type: KeyPairType.x25519),
            type: KeyPairType.x25519,
          );
          final dh4 = await x25519.sharedSecretKey(keyPair: opkPair, remotePublicKey: ekAPub);
          dh4Bytes = await dh4.extractBytes();
        }

        final combined = [...dh1Bytes, ...dh2Bytes, ...dh3Bytes, ...dh4Bytes];
        debugPrint('DH1 length: ${dh1Bytes.length}');
        debugPrint('DH2 length: ${dh2Bytes.length}');
        debugPrint('DH3 length: ${dh3Bytes.length}');
        debugPrint('DH4 length: ${dh4Bytes.length}');
        debugPrint('Combined length: ${combined.length}');
        debugPrint('DH1: ${base64Encode(dh1Bytes)}');
debugPrint('DH2: ${base64Encode(dh2Bytes)}');
debugPrint('DH3: ${base64Encode(dh3Bytes)}');
debugPrint('DH4: ${base64Encode(dh4Bytes)}');

final rootKey = await hkdf.deriveKey(
  secretKey: SecretKey(combined),
  nonce: utf8.encode('HushNet-Salt'),     // facultatif mais recommandé
  info: utf8.encode('X3DH Root Key'),
);

        final plaintext = await _decryptCiphertext(p.ciphertext, rootKey, aes);
        debugPrint('✅ Decrypted pending session ${p.id}: $plaintext');

        // Delete pending session on server
        // final String? nodeUrl = await nodeService.getCurrentNodeUrl();
        // await dio.delete('$nodeUrl/sessions/${p.id}/complete');
      } catch (e) {
        debugPrint('❌ Failed to process ${p.id}: $e');
      }
    }
  }

  Future<String> _decryptCiphertext(
    String ciphertextB64,
    SecretKey rootKey,
    AesGcm aes,
  ) async {
    final bytes = base64Decode(ciphertextB64);
    const nonceLen = 12;
    const macLen = 16;

    final nonce = bytes.sublist(0, nonceLen);
    final mac = bytes.sublist(bytes.length - macLen);
    final cipher = bytes.sublist(nonceLen, bytes.length - macLen);

    final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
    final clear = await aes.decrypt(box, secretKey: rootKey);
    return utf8.decode(clear);
  }
}
