import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyProvider {
  static final KeyProvider _instance = KeyProvider._internal();
  factory KeyProvider() => _instance;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final identityAlgorithm = Ed25519();
  final keyExchangeAlgorithm = X25519();
  static const _identityKey = 'identity_key';
  static const _preKey = 'pre_key';

  KeyProvider._internal();
  Future<void> initialize(ValueNotifier<int>? stepNotifier) async {
    final idKeyExists = await _storage.containsKey(key: _identityKey);
    if (!idKeyExists) {
      await generateAndStoreKeys(stepNotifier);
    } else {
      stepNotifier?.value = 5; // Skip to enrollment step if keys exist
    }
  }

  Future<void> generateAndStoreKeys(ValueNotifier<int>? stepNotifier) async {
    final keyPair = await identityAlgorithm.newKeyPair();
    // Generate Pre-Key (PK)
    final preKeyPair = await keyExchangeAlgorithm.newKeyPair();

    final idPrivateKey = await keyPair.extractPrivateKeyBytes(); // IK
    stepNotifier?.value += 1;
    final idPublicKey = await keyPair.extractPublicKey().then((pk) => pk.bytes); // IKpub
    stepNotifier?.value += 1;
    final prePrivateKey = await preKeyPair.extractPrivateKeyBytes(); // PK
    final prePublicKey = await preKeyPair.extractPublicKey().then((pk) => pk.bytes); // PKpub

    final identityKeyData = jsonEncode({
      'private': base64Encode(idPrivateKey),
      'public': base64Encode(idPublicKey),
    });
    final preKeyData = jsonEncode({
      'private': base64Encode(prePrivateKey),
      'public': base64Encode(prePublicKey),
    });

    await _storage.write(key: _identityKey, value: identityKeyData);
    await _storage.write(key: _preKey, value: preKeyData);

    // Generate Signed PreKey (SPK)
    // Generate Signed PreKey (SPK) — X25519 key signed by IK (Ed25519)
    final spkPair = await keyExchangeAlgorithm.newKeyPair();
    final spkPrivateKey = await spkPair.extractPrivateKeyBytes();
    final spkPublicKey = (await spkPair.extractPublicKey()).bytes;

    // Charge la clé privée Ed25519 pour signer
    final identityData = jsonDecode(identityKeyData);
    final identityPriv = base64Decode(identityData['private']);
    final identityKeyPair = await identityAlgorithm.newKeyPairFromSeed(identityPriv);

    // Signe la SPK publique avec la clé Ed25519
    final signature = await identityAlgorithm.sign(
      spkPublicKey,
      keyPair: identityKeyPair,
    );

    // Stocke la SPK
    await _storage.write(key: 'signed_pre_key', value: jsonEncode({
      'private': base64Encode(spkPrivateKey),
      'public': base64Encode(spkPublicKey),
      'signature': base64Encode(signature.bytes),
    }));
    // One Time Pre-Key (OPK)
    for (int i = 0; i < 5; i++) {
      final opkPair = await keyExchangeAlgorithm.newKeyPair();
      final opkPrivateKey = await opkPair.extractPrivateKeyBytes(); // OPK
      final opkPublicKey = await opkPair.extractPublicKey().then((pk) => pk.bytes); // OPKpub
      await _storage.write(key: 'one_time_pre_key_$i', value: jsonEncode({
        'private': base64Encode(opkPrivateKey),
        'public': base64Encode(opkPublicKey),
      }));
    }
    stepNotifier?.value = 6; // Keys generated, proceed to enrollment
  }

  Future<Map<String, Uint8List>?> getIdentityKeyPair() async {
    final data = await _storage.read(key: _identityKey);
    if (data == null) return null;
    final jsonData = jsonDecode(data);
    return {
      'private': base64Decode(jsonData['private']),
      'public': base64Decode(jsonData['public']),
    };
  }

  Future<Map<String, Uint8List>?> getPreKeyPair() async {
    final data = await _storage.read(key: _preKey);
    if (data == null) return null;
    final jsonData = jsonDecode(data);
    return {
      'private': base64Decode(jsonData['private']),
      'public': base64Decode(jsonData['public']),
    };
  }
  
  Future<Map<String, Uint8List>?> getSignedPreKey() async {
    final data = await _storage.read(key: 'signed_pre_key');
    if (data == null) return null;
    final jsonData = jsonDecode(data);
    return {
      'private': base64Decode(jsonData['private']),
      'public': base64Decode(jsonData['public']),
      'signature': base64Decode(jsonData['signature']),
    };
  }


  Future<List<Map<String, Uint8List>>> getOneTimePreKeys() async {
    List<Map<String, Uint8List>> opks = [];
    for (int i = 0; i < 5; i++) {
      final data = await _storage.read(key: 'one_time_pre_key_$i');
      if (data != null) {
        final jsonData = jsonDecode(data);
        opks.add({
          'private': base64Decode(jsonData['private']),
          'public': base64Decode(jsonData['public']),
        });
      }
    }
    return opks;
  }

  Future<Map<String, dynamic>> getKeyBundle() async {
    final identityKey = await getIdentityKeyPair();
    final preKey = await getPreKeyPair();
    final signedPreKey = await getSignedPreKey();
    final oneTimePreKeys = await getOneTimePreKeys();

    if (identityKey == null || preKey == null || signedPreKey == null) {
      throw Exception('Keys not initialized');
    }


    return {
      'identity_pubkey': base64Encode(identityKey['public']!),
      'signed_prekey' : {
        'key': base64Encode(signedPreKey['public']!),
        'signature': base64Encode(signedPreKey['signature']!),
      },
      'one_time_prekeys': oneTimePreKeys.map((k) => {"key": base64Encode(k['public']!)}).toList(),
    };
  }
}
