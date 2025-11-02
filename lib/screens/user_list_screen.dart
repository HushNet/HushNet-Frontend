import 'package:flutter/material.dart';
import 'package:hushnet_frontend/data/node/sessions/create_session.dart';
import 'package:hushnet_frontend/data/node/users/fetch_users.dart';
import 'package:hushnet_frontend/models/users.dart';
import 'package:hushnet_frontend/services/node_service.dart';
import 'package:google_fonts/google_fonts.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final NodeService _nodeService = NodeService();
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchCtrl.addListener(_filterUsers);
  }

  Future<void> _fetchUsers() async {
    try {
      final nodeUrl = await _nodeService.getCurrentNodeUrl();
      final users = await fetchUsers(nodeUrl!);
      // Exclude self from user list
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Start secure session",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          "Create an encrypted session with ${user.username}?",
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
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final nodeUrl = await _nodeService.getCurrentNodeUrl();
      final success = await createSession(nodeUrl!, user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? const Color(0xFF3A8DFF) : Colors.redAccent,
          content: Text(
            success
                ? "Session started with ${user.username}"
                : "Failed to create session",
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      );
    }
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
          "Users",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search user...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF3A8DFF),
                          ),
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
          ),
        ),
      ),
    );
  }
}
