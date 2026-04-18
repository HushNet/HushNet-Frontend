import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  final NodeService _nodeService = NodeService();
  String? _currentUserId;
  final StreamController<List<MessageView>> _messageStreamController =
      StreamController<List<MessageView>>.broadcast();

  bool get _isRemote => widget.chatView.isRemote;

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
      final all = await messageService.getAllMessagesForChat(widget.chatId);
      DateTime normalize(DateTime d) {
        final s = d.toIso8601String();
        if (!s.endsWith('Z') && !s.contains('+')) {
          return DateTime.utc(
            d.year, d.month, d.day,
            d.hour, d.minute, d.second,
            d.millisecond, d.microsecond,
          ).toUtc();
        }
        return d.toUtc();
      }

      for (final msg in all) {
        msg.createdAt = normalize(msg.createdAt);
      }
      all.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        _messages = all;
      });
    } catch (e) {
      debugPrint("Error loading messages: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    try {
      final keyProvider = KeyProvider();
      final recipientUserId = widget.chatView.partnerUserId!;

      // For remote users fetch devices via the federated proxy endpoint so that
      // device IDs match the ones stored in session keys.
      final devices = _isRemote
          ? await keyProvider.getRemoteUserDevicesKeys(
              widget.chatView.federatedAddress!,
            )
          : await keyProvider.getUserDevicesKeys(recipientUserId);

      if (devices.isEmpty) {
        debugPrint('No devices for recipient');
        return;
      }

      final MessageView sentMsg = await messageService.sendMessage(
        chatId: widget.chatId,
        plaintext: text,
        recipientUserId: recipientUserId,
        recipientDeviceIds: devices.map((d) => d.deviceId).toList(),
        toUserAddress: widget.chatView.federatedAddress,
      );

      _messages.add(sentMsg);
      _messageStreamController.add(List.from(_messages));
      _controller.clear();
    } on Exception catch (e) {
      debugPrint("Error sending message: $e");
      if (!mounted) return;
      final msg = e.toString();
      String userMsg;
      if (msg.contains('HTTP 400')) {
        userMsg = "Invalid address format";
      } else if (msg.contains('HTTP 403')) {
        userMsg = "Node unavailable";
      } else if (msg.contains('HTTP 404')) {
        userMsg = "User not found";
      } else if (msg.contains('HTTP 502') || msg.contains('HTTP 503')) {
        userMsg = "Delivery pending — will retry automatically";
      } else {
        userMsg = "Failed to send message";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(userMsg, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget infoRow(String title, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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

    void showMessageInfo(BuildContext context, MessageView msg) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1C1C1C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
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
                infoRow("Message ID", msg.id),
                infoRow("From", msg.fromUserId),
                infoRow("Created at", msg.createdAt.toIso8601String()),
                const Divider(color: Colors.grey),
                const SizedBox(height: 6),
                infoRow("Algorithm", "AES-256-GCM"),
                infoRow("Key Exchange", "X3DH + Double Ratchet"),
                if (_isRemote)
                  infoRow("Remote node", widget.chatView.federatedAddress!.split('@').last),
                if (msg.fromDeviceId == "SELF_DEVICE")
                  infoRow(
                    "Local Ciphertext Length",
                    "${msg.localCiphertext.toString().length} bytes",
                  ),
                if (msg.fromDeviceId == "SELF_DEVICE")
                  infoRow("Local Ciphertext", msg.localCiphertext.toString()),
                const Divider(color: Colors.grey),
                if (msg.fromDeviceId != "SELF_DEVICE")
                  infoRow("Ciphertext Length", "${msg.ciphertext.length} bytes"),
                if (msg.fromDeviceId != "SELF_DEVICE")
                  infoRow("Ciphertext (bytes)", base64Decode(msg.ciphertext).toString()),
                infoRow("Session ID", widget.chatId),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    label: const Text("Close", style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final chatBody = Column(
      children: [
        if (!widget.embedded) _buildAppBar(context),
        if (_isRemote) _buildRemoteBanner(),
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
                  child: Text("No messages yet 💬", style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.fromUserId == _currentUserId;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      textDirection: isMe ? TextDirection.rtl : TextDirection.ltr,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.greenAccent : const Color(0xFF2A2A2A),
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
                          onPressed: () => showMessageInfo(context, msg),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildInputBar(),
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1C1C1C),
      title: Row(
        children: [
          Text(widget.displayName),
          if (_isRemote) ...[
            const SizedBox(width: 8),
            _remoteChip(small: true),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.greenAccent),
          onPressed: _loadMessages,
        ),
      ],
    );
  }

  // Persistent banner shown when the chat partner is on a different node.
  Widget _buildRemoteBanner() {
    final nodeHost = widget.chatView.federatedAddress!.split('@').last;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0D1B2A),
      child: Row(
        children: [
          const Icon(Icons.public, color: Color(0xFF3A8DFF), size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "External node: $nodeHost",
              style: const TextStyle(
                color: Color(0xFF3A8DFF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Tooltip(
            message:
                "End-to-end encrypted across nodes.\n"
                "Your keys never leave your device.",
            child: const Icon(Icons.lock, color: Color(0xFF3A8DFF), size: 14),
          ),
        ],
      ),
    );
  }

  Widget _remoteChip({bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF3A8DFF).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3A8DFF).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public, color: const Color(0xFF3A8DFF), size: small ? 11 : 13),
          const SizedBox(width: 3),
          Text(
            "External",
            style: TextStyle(
              color: const Color(0xFF3A8DFF),
              fontSize: small ? 10 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        border: Border(top: BorderSide(color: Color(0xFF2F2F2F), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _isRemote
                    ? "Message ${widget.chatView.federatedAddress}..."
                    : "Type a message...",
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
    );
  }
}
