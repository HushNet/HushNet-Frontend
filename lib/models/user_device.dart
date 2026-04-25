import 'dart:convert';

class UserDevice {
  final String deviceId;
  final String identityPubkey;
  final String prekeyPubkey;
  final String signedPrekeyPub;
  final String signedPrekeySig;
  final String? oneTimePrekeyPub;

  const UserDevice({
    required this.deviceId,
    required this.prekeyPubkey,
    required this.identityPubkey,
    required this.signedPrekeyPub,
    required this.signedPrekeySig,
    this.oneTimePrekeyPub,
  });

  factory UserDevice.fromJson(Map<String, dynamic> json) {
    return UserDevice(
      deviceId: json['id'] ?? json['device_id'],
      identityPubkey: json['identity_pubkey'],
      prekeyPubkey: json['prekey_pubkey'] ?? json['prekey']?['key'],
      signedPrekeyPub:
          json['signed_prekey_pub'] ?? json['signed_prekey']?['key'],
      signedPrekeySig:
          json['signed_prekey_sig'] ?? json['signed_prekey']?['signature'],
      oneTimePrekeyPub:
          json['one_time_prekeys'][0] ?? json['one_time_prekey']?['key'],
    );
  }

  // Federated endpoint returns a slightly different shape:
  //   device_id, identity_pubkey, signed_prekey_pub, signed_prekey_sig,
  //   one_time_prekeys: ["base64", ...]  (strings, not objects)
  factory UserDevice.fromFederatedJson(Map<String, dynamic> json) {
    final otpks = json['one_time_prekeys'];
    String? otpk;
    if (otpks is List && otpks.isNotEmpty) {
      final first = otpks[0];
      otpk = first is String
          ? first
          : (first is Map ? first['key'] as String? : null);
    }
    return UserDevice(
      deviceId: json['device_id'] ?? json['id'],
      identityPubkey: json['identity_pubkey'],
      prekeyPubkey: json['prekey_pubkey'],
      signedPrekeyPub: json['signed_prekey_pub'],
      signedPrekeySig: json['signed_prekey_sig'],
      oneTimePrekeyPub: otpk,
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'prekey_pubkey': prekeyPubkey,
    'identity_pubkey': identityPubkey,
    'signed_prekey_pub': signedPrekeyPub,
    'signed_prekey_sig': signedPrekeySig,
    'one_time_prekey_pub': oneTimePrekeyPub,
  };

  @override
  String toString() => jsonEncode(toJson());
}
