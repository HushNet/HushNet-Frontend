import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hushnet_frontend/data/node/sessions/create_session.dart';
import 'package:hushnet_frontend/models/chat_view.dart';
import 'package:hushnet_frontend/models/message_view.dart';
import 'package:hushnet_frontend/services/key_provider.dart';
import 'package:hushnet_frontend/services/message_service.dart';
import 'package:hushnet_frontend/services/node_service.dart';

class ChatViewScreen extends StatefulWidget {
  final String chatId;
  final String displayName;
  final bool embedded;
  final ChatView chatView;

  const ChatViewScreen({
    super.key,
    required this.chatId,
    required this.displayName,
    this.embedded = false,
    required this.chatView,
  });

  @override
  State<ChatViewScreen> createState() => _ChatViewScreenState();
}

class _ChatViewScreenState extends State<ChatViewScreen> {
  final MessageService messageService = MessageService();
  final TextEditingController _controller = TextEditingController();
  List<MessageView> _messages = [];
  bool _loading = true;
  final NodeService _nodeService = NodeService();
  String? _currentUserId;
  final StreamController<List<MessageView>> _messageStreamController =
      StreamController<List<MessageView>>.broadcast();

  @override
  void initState() {
    super.initState();
    _nodeService.getCurrentUserId().then((id) {
      setState(() {
        _currentUserId = id;
      });
    });

    _loadMessages().then((_) {
      _messageStreamController.add(_messages);
    });

    _nodeService.connectWebSocket().then((_) {
      _nodeService.stream.listen((event) async {
        if (!mounted) return;
        if (event['payload']['type'] == 'message' &&
            event['payload']['chat_id'] == widget.chatId) {
          final newMessages = await messageService.getAllMessagesForChat(
            widget.chatId,
          );
          _messages = newMessages;
          _messageStreamController.add(_messages);
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageStreamController.close();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => _loading = true);
      final all = await messageService.getAllMessagesForChat(widget.chatId);
      // 🕒 tri croissant (vieux → récents)
      DateTime normalize(DateTime d) {
        final s = d.toIso8601String();
        print("normalizing date string: $s");
        // Si la date n'a pas de "Z" ni d'offset, on la traite comme locale et on force en UTC
        if (!s.endsWith('Z') && !s.contains('+')) {
          print("manque zone info, normalizing to UTC for $s");
          final res = DateTime.utc(
            d.year,
            d.month,
            d.day,
            d.hour,
            d.minute,
            d.second,
            d.millisecond,
            d.microsecond,
          ).toUtc();
          print("normalized date: ${res.toIso8601String()}");
          return res;
        }
        return d.toUtc();
      }

      for (final msg in all) {
        msg.createdAt = normalize(msg.createdAt);
      }
      all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final msg in all) {
        print(
          'Message from ${msg.fromUserId}: ${msg.ciphertext} at ${msg.createdAt}',
        );
      }

      setState(() {
        _messages = all;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading messages: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    try {
      final keyProvider = KeyProvider();

      // 1️⃣ Identifier le destinataire
      final recipientUserId = widget.chatView.partnerUserId!;

      // 2️⃣ Récupérer les devices actifs du destinataire
      final devices = await keyProvider.getUserDevicesKeys(recipientUserId);
      if (devices.isEmpty) {
        debugPrint('No devices for recipient');
        return;
      }

      // 5️⃣ Envoi du message
      MessageView sentMsg = await messageService.sendMessage(
        chatId: widget.chatId,
        plaintext: text,
        recipientUserId: recipientUserId,
        recipientDeviceIds: devices.map((d) => d.deviceId).toList(),
      );

      _messages.add(sentMsg);
      _messageStreamController.add(
        List.from(_messages),
      ); // push nouveau snapshot
      _controller.clear();
    } catch (e) {
      debugPrint("❌ Error sending message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget _infoRow(String title, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    void _showMessageInfo(BuildContext context, MessageView msg) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1C1C1C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          debugPrint(msg.toJson().toString());
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🔒 Message Encryption Info",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow("Message ID", msg.id ?? "unknown"),
                _infoRow("From", msg.fromUserId ?? "unknown"),
                _infoRow("Created at", msg.createdAt.toIso8601String()),
                const Divider(color: Colors.grey),
                const SizedBox(height: 6),
                _infoRow("Algorithm", "AES-256-GCM"),
                _infoRow("Key Exchange", "X3DH + Double Ratchet"),
                if (msg.fromDeviceId == "SELF_DEVICE")
                  _infoRow(
                    "Local Ciphertext Length",
                    "${msg.localCiphertext!.toString().length} bytes",
                  ),
                if (msg.fromDeviceId == "SELF_DEVICE")
                  _infoRow("Local Ciphertext", msg.localCiphertext.toString()),
                const Divider(color: Colors.grey),
                if (msg.fromDeviceId != "SELF_DEVICE")
                  _infoRow(
                    "Ciphertext Length",
                    "${msg.ciphertext.length} bytes",
                  ),
                if (msg.fromDeviceId != "SELF_DEVICE")
                  _infoRow(
                    "Ciphertext (bytes)",
                    base64Decode(msg.ciphertext).toString(),
                  ),
                _infoRow("Session ID", widget.chatId),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    label: const Text(
                      "Close",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    final chatBody = Column(
      children: [
        if (!widget.embedded)
          AppBar(
            backgroundColor: const Color(0xFF1C1C1C),
            title: Text(widget.displayName),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.greenAccent),
                onPressed: _loadMessages,
              ),
            ],
          ),
        Expanded(
          child: StreamBuilder<List<MessageView>>(
            stream: _messageStreamController.stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.greenAccent),
                );
              }

              final messages = snapshot.data!;
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    "No messages yet 💬",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.fromUserId == _currentUserId;

                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      textDirection: isMe
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.greenAccent
                                : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg.decryptedText,
                            style: TextStyle(
                              color: isMe ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.info_outline,
                            color: isMe ? Colors.greenAccent : Colors.grey[400],
                            size: 18,
                          ),
                          onPressed: () => _showMessageInfo(context, msg),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1C),
            border: Border(
              top: BorderSide(color: Color(0xFF2F2F2F), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.greenAccent),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Container(color: const Color(0xFF101010), child: chatBody);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(child: chatBody),
    );
  }
}
