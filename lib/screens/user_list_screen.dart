import 'package:flutter/material.dart';
import 'package:hushnet_frontend/data/node/sessions/create_session.dart';
import 'package:hushnet_frontend/data/node/users/fetch_users.dart';
import 'package:hushnet_frontend/models/users.dart';
import 'package:hushnet_frontend/services/node_service.dart';
import 'package:hushnet_frontend/utils/federation.dart';
import 'package:google_fonts/google_fonts.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _federatedCtrl = TextEditingController();
  final NodeService _nodeService = NodeService();
  late final TabController _tabCtrl;

  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _loading = true;
  bool _federatedLoading = false;
  String? _federatedError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchUsers();
    _searchCtrl.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _federatedCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final nodeUrl = await _nodeService.getCurrentNodeUrl();
      final users = await fetchUsers(nodeUrl!);
      final userId = await _nodeService.getCurrentUserId();
      users.removeWhere((user) => user.id == userId);
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching users: $e");
      setState(() => _loading = false);
    }
  }

  void _filterUsers() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers
          .where((u) => u.username.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _onUserTap(User user) async {
    final confirm = await _showConfirmDialog(
      title: "Start secure session",
      body: "Create an encrypted session with ${user.username}?",
    );
    if (confirm != true) return;

    final nodeUrl = await _nodeService.getCurrentNodeUrl();
    final success = await createSession(nodeUrl!, user.id);
    if (!mounted) return;
    _showResultSnackBar(
      success: success,
      successMsg: "Session started with ${user.username}",
      failMsg: "Failed to create session",
    );
  }

  Future<void> _onFederatedConnect() async {
    final raw = _federatedCtrl.text.trim();
    final addr = FederatedAddress.tryParse(raw);
    if (addr == null) {
      setState(() => _federatedError = "Invalid address — use user@node format");
      return;
    }

    final nodeUrl = await _nodeService.getCurrentNodeUrl();
    if (nodeUrl != null && addr.isLocal(nodeUrl)) {
      setState(() => _federatedError = "That user is on your node — use the Local tab");
      return;
    }

    final confirm = await _showConfirmDialog(
      title: "Connect to ${addr.full}",
      body: "Start an encrypted session with ${addr.full}?\n\nThis user is on an external HushNet node.",
      isRemote: true,
    );
    if (confirm != true) return;

    setState(() {
      _federatedLoading = true;
      _federatedError = null;
    });

    try {
      // Nil UUID is ignored server-side for federated sessions
      const placeholderUuid = '00000000-0000-0000-0000-000000000000';
      final success = await createSession(
        nodeUrl!,
        placeholderUuid,
        recipientUserAddress: addr.full,
      );
      if (!mounted) return;
      if (success) {
        _federatedCtrl.clear();
        _showResultSnackBar(
          success: true,
          successMsg: "Session request sent to ${addr.full}",
          failMsg: '',
        );
      } else {
        setState(() => _federatedError = "Failed to reach ${addr.nodeHost}");
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _federatedError = _mapFederatedError(msg);
      });
    } finally {
      if (mounted) setState(() => _federatedLoading = false);
    }
  }

  String _mapFederatedError(String raw) {
    if (raw.contains('HTTP 400')) return "Invalid federated address format";
    if (raw.contains('HTTP 403')) return "Remote node is unavailable or blocked";
    if (raw.contains('HTTP 404')) return "User not found on remote node";
    if (raw.contains('HTTP 502') || raw.contains('HTTP 503')) {
      return "Remote node unreachable — delivery will be retried automatically";
    }
    return "Connection failed — check the address and try again";
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    bool isRemote = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            if (isRemote) ...[
              const Icon(Icons.public, color: Color(0xFF3A8DFF), size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          body,
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: GoogleFonts.inter(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A8DFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Connect"),
          ),
        ],
      ),
    );
  }

  void _showResultSnackBar({
    required bool success,
    required String successMsg,
    required String failMsg,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? const Color(0xFF3A8DFF) : Colors.redAccent,
        content: Text(
          success ? successMsg : failMsg,
          style: GoogleFonts.inter(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 700;
    final maxWidth = isDesktop ? 600.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: Text(
          "New conversation",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF3A8DFF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.person, size: 18), text: "Local"),
            Tab(icon: Icon(Icons.public, size: 18), text: "Federated"),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildLocalTab(),
                _buildFederatedTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Search user...",
              prefixIcon: Icon(Icons.search, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3A8DFF)),
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      "No users found",
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (_, i) {
                      final user = _filteredUsers[i];
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          onTap: () => _onUserTap(user),
                          title: Text(
                            user.username,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          leading: const Icon(
                            Icons.person,
                            color: Color(0xFF3A8DFF),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white24,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFederatedTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3A8DFF).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.public, color: Color(0xFF3A8DFF), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Connect to a user on another HushNet node using their full address, e.g. alice@node-a.hushnet.net",
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _federatedCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onSubmitted: (_) => _onFederatedConnect(),
            decoration: InputDecoration(
              hintText: "user@node-host.example.com",
              prefixIcon: const Icon(Icons.alternate_email, color: Colors.grey),
              errorText: _federatedError,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _federatedLoading ? null : _onFederatedConnect,
              icon: _federatedLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link, size: 18),
              label: Text(
                _federatedLoading ? "Connecting..." : "Connect",
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A8DFF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
