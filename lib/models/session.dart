import 'dart:convert';
import 'dart:typed_data';

class Session {
  final String id;
  final String chatId;
  final String senderDeviceId;
  final String receiverDeviceId;
  final Uint8List rootKey;
  final Uint8List? sendChainKey;
  final Uint8List? recvChainKey;
  final int sendCounter;
  final int recvCounter;
  final Uint8List ratchetPub;
  final Uint8List? ratchetPriv;
  final Uint8List? lastRemotePub;
  final DateTime createdAt;
  final DateTime updatedAt;

  Session({
     this.id = '',
     this.chatId = '',
    required this.senderDeviceId,
    required this.receiverDeviceId,
    required this.rootKey,
    this.sendChainKey,
    this.recvChainKey,
    this.sendCounter = 0,
    this.recvCounter = 0,
    required this.ratchetPub,
    this.ratchetPriv,
    this.lastRemotePub,
    required this.createdAt,
    required this.updatedAt,
  });
  

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      chatId: json['chat_id'],
      senderDeviceId: json['sender_device_id'],
      receiverDeviceId: json['receiver_device_id'],
      rootKey: base64Decode(json['root_key']),
      sendChainKey: json['send_chain_key'] != null
          ? base64Decode(json['send_chain_key'])
          : null,
      recvChainKey: json['recv_chain_key'] != null
          ? base64Decode(json['recv_chain_key'])
          : null,
      sendCounter: json['send_counter'] ?? 0,
      recvCounter: json['recv_counter'] ?? 0,
      ratchetPub: base64Decode(json['ratchet_pub']),
      ratchetPriv: json['ratchet_priv'] != null
          ? base64Decode(json['ratchet_priv'])
          : null,
      lastRemotePub: json['last_remote_pub'] != null
          ? base64Decode(json['last_remote_pub'])
          : null,
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
      'root_key': base64Encode(rootKey),
      if (sendChainKey != null)
        'send_chain_key': base64Encode(sendChainKey!),
      if (recvChainKey != null)
        'recv_chain_key': base64Encode(recvChainKey!),
      'send_counter': sendCounter,
      'recv_counter': recvCounter,
      'ratchet_pub': base64Encode(ratchetPub),
      if (ratchetPriv != null)
        'ratchet_priv': base64Encode(ratchetPriv!),
      if (lastRemotePub != null)
        'last_remote_pub': base64Encode(lastRemotePub!),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  Map<String, dynamic> toConfirmJson() {
  return {
    "sender_device_id": senderDeviceId,
    "receiver_device_id": receiverDeviceId,
    "root_key": base64Encode(rootKey),
    "ratchet_pub": base64Encode(ratchetPub),
    if (lastRemotePub != null)
      "last_remote_pub": base64Encode(lastRemotePub!),
  };
}
}
