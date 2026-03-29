import 'package:flutter/material.dart';
import 'package:hushnet_frontend/data/node/node_connection.dart';
import 'package:hushnet_frontend/models/node.dart';
import 'package:hushnet_frontend/widgets/button.dart';
import 'package:hushnet_frontend/widgets/connection/bottom_sheet.dart';

class SelectNodeScreen extends StatefulWidget {
  const SelectNodeScreen({super.key});

  @override
  State<SelectNodeScreen> createState() => _SelectNodeScreenState();
}

class _SelectNodeScreenState extends State<SelectNodeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _privateNodeController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _privateNodeController.dispose();
    super.dispose();
  }

  void _connectToNode(String address) {
    String nodeAddress = address.trim();
    if (nodeAddress.endsWith('/')) {
      nodeAddress = nodeAddress.substring(0, nodeAddress.length - 1);
    }
    if (nodeAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a node URL')),
      );
      return;
    }
    showConnectionSheet(context, nodeAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select a Node',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Choose a public node or connect to your own private node.',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Public Nodes'),
                Tab(text: 'Private Node'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPublicNodesTab(),
                _buildPrivateNodeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicNodesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextFormField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            cursorColor: const Color(0xFF3A8DFF),
            decoration: InputDecoration(
              hintText: 'Search by name, country, or host...',
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white54, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF3A8DFF), width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Node>>(
            future: fetchNodes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF3A8DFF),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            color: Colors.grey[600], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load nodes',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final nodes = snapshot.data ?? [];
              final filtered = nodes.where((node) {
                if (_searchQuery.isEmpty) return true;
                return node.name.toLowerCase().contains(_searchQuery) ||
                    node.countryName.toLowerCase().contains(_searchQuery) ||
                    node.host.toLowerCase().contains(_searchQuery) ||
                    node.countryCode.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          color: Colors.grey[600], size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No nodes match your search'
                            : 'No nodes available',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 15),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _buildNodeCard(filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNodeCard(Node node) {
    final isOnline = node.status.toLowerCase() == 'online';
    final latency = node.lastLatencyMs;
    final countryFlag = _countryCodeToEmoji(node.countryCode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _connectToNode(node.apiBaseUrl),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              // Country flag
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  countryFlag,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              // Node info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name.isNotEmpty ? node.name : node.host,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          node.countryName.isNotEmpty
                              ? node.countryName
                              : node.host,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                        if (node.protocolVersion.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '·',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          Text(
                            'v${node.protocolVersion}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status & latency
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.greenAccent
                              : Colors.red[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color:
                              isOnline ? Colors.greenAccent : Colors.red[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (latency != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${latency}ms',
                      style: TextStyle(
                        color: latency < 100
                            ? Colors.greenAccent
                            : latency < 300
                                ? Colors.orangeAccent
                                : Colors.red[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[700], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivateNodeTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF3A8DFF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Connect to a self-hosted or private node by entering its address below.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _privateNodeController,
            style: const TextStyle(color: Colors.white),
            cursorColor: const Color(0xFF3A8DFF),
            decoration: InputDecoration(
              hintText: 'https://node.example.com',
              prefixIcon:
                  const Icon(Icons.link, color: Colors.white54, size: 20),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF3A8DFF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          HushButton(
            label: 'Connect',
            icon: Icons.login,
            fullWidth: true,
            onPressed: () => _connectToNode(_privateNodeController.text),
          ),
        ],
      ),
    );
  }

  String _countryCodeToEmoji(String countryCode) {
    if (countryCode.length != 2) return '🌐';
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }
}
