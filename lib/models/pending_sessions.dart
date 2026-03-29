import 'package:hushnet_frontend/models/users.dart';

class PendingSession {
  final String id;
  final String senderDeviceId;
  final String recipientDeviceId;
  final String ephemeralPubkey; // base64
  final String ciphertext; // base64
  final String? senderPrekeyPub; // base64 (nécessaire pour DH1)
  final String createdAt;
  User? senderUser;
  
  PendingSession({
    required this.id,
    required this.senderDeviceId,
    required this.recipientDeviceId,
    required this.ephemeralPubkey,
    required this.ciphertext,
    required this.createdAt,
    this.senderUser,
    this.senderPrekeyPub,
  });

  factory PendingSession.fromJson(Map<String, dynamic> json) {
    return PendingSession(
      id: json['id'],
      senderDeviceId: json['sender_device_id'],
      recipientDeviceId: json['recipient_device_id'],
      ephemeralPubkey: json['ephemeral_pubkey'],
      ciphertext: json['ciphertext'],
      createdAt: json['created_at'] ?? '',
      senderPrekeyPub: json['sender_prekey_pub'],
    );
  }
}
