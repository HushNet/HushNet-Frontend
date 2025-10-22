import 'dart:async';
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
  final bool embedded; // 👈 si affiché à droite (desktop)
  final ChatView chatView;

  const ChatViewScreen({
    super.key,
    required this.chatId,
    required this.displayName,
    this.embedded = false, required this.chatView,
  });

  @override
  State<ChatViewScreen> createState() => _ChatViewScreenState();
}

class _ChatViewScreenState extends State<ChatViewScreen> {
  final MessageService messageService = MessageService();
  final TextEditingController _controller = TextEditingController();
  List<MessageView> _messages = [];
  bool _loading = true;
  late Timer _refreshTimer;
  final NodeService _nodeService = NodeService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _nodeService.getCurrentUserId().then((id) {
      setState(() {
        _currentUserId = id;
      });
    });
    _loadMessages();
    // auto refresh toutes les 10 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _controller.dispose();
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
      final res =  DateTime.utc(
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
      print('Message from ${msg.fromUserId}: ${msg.ciphertext} at ${msg.createdAt}');
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
    await messageService.sendMessage(
      chatId: widget.chatId,
      plaintext: text,
      recipientUserId: recipientUserId,
      recipientDeviceIds: devices.map((d) => d.deviceId).toList(),
    );

    // 6️⃣ Reset input et refresh UI
    _controller.clear();
    await _loadMessages();

  } catch (e) {
    debugPrint("❌ Error sending message: $e");
  }
}

  @override
  Widget build(BuildContext context) {
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
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: Colors.greenAccent))
              : _messages.isEmpty
                  ? const Center(
                      child: Text("No messages yet 💬",
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      reverse: false,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.fromUserId == _currentUserId;
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.greenAccent
                                  : const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              msg.ciphertext,
                              style: TextStyle(
                                color: isMe ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1C),
            border: Border(
                top: BorderSide(color: Color(0xFF2F2F2F), width: 0.5)),
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
      return Container(
        color: const Color(0xFF101010),
        child: chatBody,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(child: chatBody),
    );
  }
}