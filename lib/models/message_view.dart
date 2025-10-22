class MessageView {
  final String id;
  final String logicalMsgId;
  final String chatId;
  final String fromUserId;
  final String fromDeviceId; // ✅ ajouté
  final String ciphertext;
  DateTime createdAt;
  final bool pending;

  MessageView({
    required this.id,
    required this.logicalMsgId,
    required this.chatId,
    required this.fromUserId,
    required this.fromDeviceId,
    required this.ciphertext,
    required this.createdAt,
    this.pending = false,
  });

  factory MessageView.fromJson(Map<String, dynamic> json) {
    return MessageView(
      id: json['id'],
      logicalMsgId: json['logical_msg_id'],
      chatId: json['chat_id'],
      fromUserId: json['from_user_id'],
      fromDeviceId: json['from_device_id'], // ✅
      ciphertext: json['ciphertext'],
      createdAt: json['from_device_id'] == "SELF_DEVICE"
          ? DateTime.parse(json['created_at'])
          : DateTime.parse(json['created_at']),
    );
  }
}
