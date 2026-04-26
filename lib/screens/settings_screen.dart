import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hushnet_frontend/screens/onboarding.dart';
import 'package:hushnet_frontend/services/node_service.dart';
import 'package:hushnet_frontend/services/secure_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

const _kAppVersion = '1.0.0';
const _kBuildNumber = '1';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NodeService _nodeService = NodeService();
  final SecureStorageService _storage = SecureStorageService();

  String? _username;
  String? _userId;
  String? _deviceId;
  String? _nodeUrl;
  bool _wsConnected = false;
  bool _pinging = false;
  String? _pingResult;

  @override
  void initState() {
    super.initState();
    _load();
    _wsConnected = _nodeService.isConnected;
    _nodeService.connectionState.listen((v) {
      if (!mounted) return;
      setState(() => _wsConnected = v);
    });
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _storage.read('username'),
      _storage.read('user_id'),
      _storage.read('device_id'),
      _storage.read('node_url'),
    ]);
    if (!mounted) return;
    setState(() {
      _username = results[0];
      _userId = results[1];
      _deviceId = results[2];
      _nodeUrl = results[3];
    });
  }

  Future<void> _ping() async {
    setState(() {
      _pinging = true;
      _pingResult = null;
    });
    final sw = Stopwatch()..start();
    try {
      await _nodeService.connectWebSocket();
      sw.stop();
      setState(() => _pingResult = '${sw.elapsedMilliseconds} ms');
    } catch (_) {
      setState(() => _pingResult = 'unreachable');
    } finally {
      setState(() => _pinging = false);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _copy(url, 'Link');
    }
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2A2A2A),
        content: Text(
          '$label copied',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Sign out?',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'All local keys and session data will be cleared. This cannot be undone.',
          style: GoogleFonts.inter(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Sign out', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    _nodeService.disconnectWebSocket();
    await _storage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildProfile(),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.dns_outlined,
              title: 'Node',
              color: const Color(0xFF3A8DFF),
              children: [
                _buildInfoTile(
                  label: 'URL',
                  value: _nodeUrl ?? '—',
                  onCopy: _nodeUrl != null ? () => _copy(_nodeUrl!, 'Node URL') : null,
                ),
                _buildStatusTile(),
                _buildPingTile(),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.lock_outline,
              title: 'Security',
              color: Colors.greenAccent,
              children: [
                _buildInfoTile(label: 'Encryption', value: 'AES-256-GCM'),
                _buildInfoTile(label: 'Key exchange', value: 'X3DH + Double Ratchet'),
                _buildInfoTile(label: 'Key storage', value: 'Local device only'),
                _buildInfoTile(label: 'Forward secrecy', value: 'Enabled'),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.info_outline,
              title: 'About',
              color: Colors.white54,
              children: [
                _buildInfoTile(label: 'Version', value: '$_kAppVersion (build $_kBuildNumber)'),
                _buildInfoTile(label: 'Made in', value: 'Marseille 🇫🇷'),
                _buildLinkTile(
                  label: 'HushNet',
                  url: 'https://github.com/HushNet',
                ),
                _buildLinkTile(
                  label: 'Frontend',
                  url: 'https://github.com/HushNet/HushNet-Frontend',
                ),
                _buildLinkTile(
                  label: 'Backend',
                  url: 'https://github.com/HushNet/HushNet-Backend',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDangerZone(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile() {
    final initial = (_username ?? '?')[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  color: Colors.greenAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username ?? '—',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _userId != null ? () => _copy(_userId!, 'User ID') : null,
                  child: Text(
                    _truncate(_userId, 28),
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                  ),
                ),
                if (_deviceId != null) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _copy(_deviceId!, 'Device ID'),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android, color: Colors.grey, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          _truncate(_deviceId, 24),
                          style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              ),
            ),
            Flexible(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onCopy != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.copy, color: Colors.grey, size: 13),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile({required String label, required String url}) {
    return InkWell(
      onTap: () => _launch(url),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              ),
            ),
            Flexible(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      url.replaceFirst('https://', ''),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF3A8DFF),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFF3A8DFF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.open_in_new, color: Color(0xFF3A8DFF), size: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'WebSocket',
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _wsConnected ? Colors.greenAccent : Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_wsConnected ? Colors.greenAccent : Colors.orange)
                          .withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _wsConnected ? 'Connected' : 'Reconnecting…',
                style: GoogleFonts.inter(
                  color: _wsConnected ? Colors.greenAccent : Colors.orange,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPingTile() {
    return InkWell(
      onTap: _pinging ? null : _ping,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Ping node',
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              ),
            ),
            if (_pinging)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white38,
                ),
              )
            else if (_pingResult != null)
              Text(
                _pingResult!,
                style: GoogleFonts.inter(
                  color: _pingResult == 'unreachable' ? Colors.redAccent : Colors.greenAccent,
                  fontSize: 13,
                ),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_outlined, color: Colors.redAccent, size: 15),
              const SizedBox(width: 6),
              Text(
                'DANGER ZONE',
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
          ),
          child: InkWell(
            onTap: _signOut,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    'Sign out',
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _truncate(String? s, int max) {
    if (s == null) return '—';
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }
}
