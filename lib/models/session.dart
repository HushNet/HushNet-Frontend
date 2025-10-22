import 'dart:convert';

class Session {
  final String id;
  final String chatId;
  final String senderDeviceId;
  final String receiverDeviceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Session({
    this.id = '',
    this.chatId = '',
    required this.senderDeviceId,
    required this.receiverDeviceId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] ?? '',
      chatId: json['chat_id'] ?? '',
      senderDeviceId: json['sender_device_id'],
      receiverDeviceId: json['receiver_device_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_device_id': senderDeviceId,
      'receiver_device_id': receiverDeviceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// This JSON is used when confirming a pending session with the node.
  /// Only non-sensitive metadata is uploaded — the actual ratchet keys remain client-side.
  Map<String, dynamic> toConfirmJson() {
    return {
      'sender_device_id': senderDeviceId,
      'receiver_device_id': receiverDeviceId,
    };
  }
}
