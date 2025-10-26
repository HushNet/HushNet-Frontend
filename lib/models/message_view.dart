import 'package:flutter/material.dart';

class MessageView {
  final String id;
  final String logicalMsgId;
  final String chatId;
  final String fromUserId;
  final String fromDeviceId; // ✅ ajouté
  final String ciphertext;
  String decryptedText = '';
  List<String> localCiphertext;
  DateTime createdAt;
  final bool pending;

  MessageView({
    required this.id,
    required this.logicalMsgId,
    required this.chatId,
    required this.fromUserId,
    required this.fromDeviceId,
    required this.ciphertext,
    this.localCiphertext = const [],
    required this.createdAt,
    this.pending = false,
    this.decryptedText = '',
  });

  factory MessageView.fromJson(Map<String, dynamic> json) {
    debugPrint("Parsing MessageView from JSON: $json");
    return MessageView(
      id: json['id'],
      logicalMsgId: json['logical_msg_id'],
      chatId: json['chat_id'],
      fromUserId: json['from_user_id'],
      fromDeviceId: json['from_device_id'], // ✅
      ciphertext: json['ciphertext'] ?? '',
      decryptedText: json['decrypted_text'] ?? '',
      localCiphertext: json['local_ciphertext'] != null
          ? List<String>.from(json['local_ciphertext'])
          : [],
      createdAt: json['from_device_id'] == "SELF_DEVICE"
          ? DateTime.parse(json['created_at'])
          : DateTime.parse(json['created_at']),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'logical_msg_id': logicalMsgId,
      'chat_id': chatId,
      'from_user_id': fromUserId,
      'from_device_id': fromDeviceId,
      'ciphertext': ciphertext,
      'local_ciphertext': localCiphertext,
      'decrypted_text': decryptedText,
      'created_at': createdAt.toIso8601String(),
      'pending': pending,
    };
  }
}
