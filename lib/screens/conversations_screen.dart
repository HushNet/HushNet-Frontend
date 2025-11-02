import 'package:flutter/material.dart';
import 'package:hushnet_frontend/data/node/sessions/create_session.dart';
import 'package:hushnet_frontend/models/chat_view.dart';
import 'package:hushnet_frontend/screens/chat_view_screen.dart';
import 'package:hushnet_frontend/screens/pending_sessions_screen.dart';
import 'package:hushnet_frontend/screens/user_list_screen.dart';
import 'package:hushnet_frontend/services/chat_service.dart';
import 'package:hushnet_frontend/services/node_service.dart';
import 'package:hushnet_frontend/services/session_service.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatService chatService = ChatService();
  final NodeService nodeService = NodeService();
  int? _selectedIndex;
  List<ChatView> _chats = [];

  @override
  void initState() {
    nodeService.connectWebSocket().then((_) {
      nodeService.stream.listen((event) {
        if (!mounted) return;
        if (event['event_type'] == 'session') {
          setState(() {});
        }
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Row(
          children: [
            // 🟢 Liste des conversations
            Expanded(
              flex: isDesktop ? 2 : 1,
              child: Container(
                color: const Color(0xFF1C1C1C),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: FutureBuilder(
                        future: Future.wait([
                          chatService.getChats(),
                          SessionService()
                              .getPendingSessionsCount(), // 🧠 nouvelle méthode simple
                        ]),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.greenAccent,
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                "Error: ${snapshot.error}",
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            );
                          }

                          List<ChatView> chats = snapshot.data?[0] as List<ChatView>? ?? [];
                          int pendingCount = snapshot.data?[1] as int? ?? 0;

                          if (chats.isEmpty && pendingCount == 0) {
                            return const Center(
                              child: Text(
                                "No conversations yet",
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              if (pendingCount > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: _buildPendingButton(
                                    context,
                                    pendingCount,
                                  ),
                                ),
                              Expanded(child: _buildConversationList(chats)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 💬 Conversation (desktop uniquement)
            if (isDesktop)
              Expanded(
                flex: 4,
                child: _selectedIndex == null
                    ? _buildEmptyChatPlaceholder()
                    : ChatViewScreen(
                        chatId: _chats[_selectedIndex!].id,
                        displayName: _chats[_selectedIndex!].displayName,
                        embedded: true,
                        chatView: _chats[_selectedIndex!],
                      ),
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
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const UserListScreen()));
            },
            icon: const Icon(Icons.add, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
            },
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
              final NodeService nodeService = NodeService();
              final String? nodeUrl = await nodeService.getCurrentNodeUrl();
              final String? userId = await nodeService.getCurrentUserId();
              if (nodeUrl == null || userId == null) return;

              await createSession(nodeUrl, userId);
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingButton(BuildContext context, int count) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PendingSessionsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.key, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              "Pending sessions ($count)",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList(List<ChatView> chats) {
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final isSelected = _selectedIndex == index;

        return InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
            if (MediaQuery.of(context).size.width <= 800) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatViewScreen(
                    chatId: chat.id,
                    displayName: chat.displayName,
                    chatView: chat,
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
                    chat.displayName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.previewText,
                        style: TextStyle(color: Colors.grey[400]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  "${chat.updatedAt.hour}:${chat.updatedAt.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
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
