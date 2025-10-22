import 'package:intl/intl.dart';

class ChatView {
  final String id;
  final String chatType;
  final String? partnerUserId;
  final String? partnerUsername;
  final String? name; // for group chats
  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime updatedAt;
  final String displayName;

  ChatView({
    required this.id,
    required this.chatType,
    this.partnerUserId,
    this.partnerUsername,
    this.name,
    this.lastMessageId,
    this.lastMessagePreview,
    required this.updatedAt,
    this.displayName = '',
  });

  factory ChatView.fromJson(Map<String, dynamic> json) {
    return ChatView(
      id: json['id'] ?? '',
      chatType: json['chat_type'] ?? 'direct',
      partnerUserId: json['partner_user_id'],
      partnerUsername: json['partner_username'],
      name: json['name'],
      lastMessageId: json['last_message_id'],
      lastMessagePreview: json['last_message_preview'],
      updatedAt: DateTime.parse(json['updated_at']),
      displayName: json['name'] ?? json['partner_username'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_type': chatType,
      'partner_user_id': partnerUserId,
      'partner_username': partnerUsername,
      'name': name,
      'last_message_id': lastMessageId,
      'last_message_preview': lastMessagePreview,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Optional helper: format the last update nicely for UI
  String get formattedDate {
    return DateFormat('dd/MM HH:mm').format(updatedAt);
  }

  /// Optional helper: title shown in chat list
  String get displayTitle {
    if (chatType == 'group') return name ?? 'Group chat';
    return partnerUsername ?? 'Unknown';
  }

  String get previewText {
    return lastMessagePreview ?? 'Secure session established 🔒';
  }
}
