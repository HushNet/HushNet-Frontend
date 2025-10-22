import 'package:hushnet_frontend/models/chat_view.dart';
import 'package:hushnet_frontend/services/key_provider.dart';
import 'package:hushnet_frontend/services/node_service.dart';

class ChatService {
  final KeyProvider _keyProvider = KeyProvider();
  final NodeService _nodeService = NodeService();

  Future<List<ChatView>> getChats() async {
    final String? nodeUrl = await _nodeService.getCurrentNodeUrl();
    if (nodeUrl == null) {
      throw Exception('Node URL not set');
    }
    final response = await _keyProvider.sendSignedRequest(
      "GET",
      "$nodeUrl/chats",
    );
    if (response.statusCode == 200) {
      final data = response.data as List;
      return data.map((json) => ChatView.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load chats');
    }
  }
}
