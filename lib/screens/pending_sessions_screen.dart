import 'package:flutter/material.dart';
import 'package:hushnet_frontend/models/pending_sessions.dart';
import 'package:hushnet_frontend/services/session_service.dart';
import 'package:hushnet_frontend/widgets/button.dart';
import 'package:lottie/lottie.dart';

class PendingSessionsScreen extends StatefulWidget {
  const PendingSessionsScreen({super.key});

  @override
  State<PendingSessionsScreen> createState() => _PendingSessionsScreenState();
}

class _PendingSessionsScreenState extends State<PendingSessionsScreen> {
  final SessionService _sessionService = SessionService();
  bool _loading = true;
  List<PendingSession> _pendingSessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _sessionService
        .getPendingSessions(); // renvoie List<PendingSession>
    for (var session in sessions) {
      await _sessionService.getUserForSession(session);
    }
    setState(() {
      _pendingSessions = sessions;
      _loading = false;
    });
  }

  Future<void> _acceptSession(PendingSession session) async {
    await _sessionService.processPendingSessions(session.id);
    _loadSessions();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session accepted successfully."),
        backgroundColor: Colors.greenAccent,
      ),
    );
  }

  Future<void> _rejectSession(PendingSession session) async {
    // À adapter si tu veux une vraie suppression backend
    _loadSessions();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session rejected."),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        title: const Text("Pending sessions"),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: Lottie.asset('assets/loading.json', width: 120))
          : _pendingSessions.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingSessions.length,
              itemBuilder: (context, index) {
                final session = _pendingSessions[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.devices,
                              color: Colors.greenAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "From user: ${session.senderUser?.username ?? session.senderDeviceId}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "From device: ${session.senderDeviceId}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "To device: ${session.recipientDeviceId}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ephemeral pubkey: ${session.ephemeralPubkey.substring(0, 20)}...",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        if (session.senderPrekeyPub != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Sender prekey: ${session.senderPrekeyPub!.substring(0, 20)}...",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          "Created at: ${session.createdAt}",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => _rejectSession(session),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              child: const Text("Reject"),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () => _acceptSession(session),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text("Accept"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/empty.json', width: 140),
          const SizedBox(height: 16),
          const Text(
            "No pending sessions",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 24),
          HushButton(
            label: 'Back to chats',
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
