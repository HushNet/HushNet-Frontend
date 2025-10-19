import 'package:flutter/material.dart';
import 'package:hushnet_frontend/screens/user_list_screen.dart';
import 'package:hushnet_frontend/services/session_service.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final List<Map<String, dynamic>> _conversations = [

  ];

  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Row(
          children: [
            // 🟢 LISTE DES CONVERSATIONS (toujours visible)
            Expanded(
              flex: isDesktop ? 2 : 1,
              child: Container(
                color: const Color(0xFF1C1C1C),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildConversationList()),
                  ],
                ),
              ),
            ),

            // 💬 ZONE DE CHAT (visible seulement sur desktop)
            if (isDesktop)
              Expanded(
                flex: 4,
                child: _selectedIndex == null
                    ? _buildEmptyChatPlaceholder()
                    : _buildChatView(_conversations[_selectedIndex!]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF202020),
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "HushNet",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UserListScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              SessionService sessionService = SessionService();
              sessionService.getPendingSessions().then((sessions) {
                debugPrint('Pending sessions: ${sessions.length}');
              });
               sessionService.processPendingSessions();
              debugPrint("Settings pressed");
            },
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        final isSelected = _selectedIndex == index;
        return InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
            // sur mobile, rediriger vers le chat
            if (MediaQuery.of(context).size.width <= 800) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: const Color(0xFF101010),
                    appBar: AppBar(
                      backgroundColor: const Color(0xFF1C1C1C),
                      title: Text(conv["username"]),
                    ),
                    body: _buildChatView(conv),
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
              border: const Border(
                bottom: BorderSide(color: Color(0xFF2F2F2F), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    conv["username"][0],
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv["username"],
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conv["lastMessage"],
                        style: TextStyle(
                          color: Colors.grey[400],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(conv["time"],
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                    if (conv["unread"] > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          conv["unread"].toString(),
                          style: const TextStyle(
                              color: Colors.black, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatView(Map<String, dynamic> conv) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _messageBubble("Hey, how’s everything?", false),
              _messageBubble("All good! Working on HushNet.", true),
              _messageBubble("Nice 🔐", false),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1C),
            border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
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
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.greenAccent : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChatPlaceholder() {
    return const Center(
      child: Text(
        "Select a conversation to start chatting 💬",
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}
