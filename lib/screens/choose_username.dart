import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hushnet_frontend/screens/conversations_screen.dart';
import 'package:hushnet_frontend/services/key_provider.dart';
import 'package:hushnet_frontend/services/node_service.dart';
import 'package:hushnet_frontend/widgets/textfield.dart';

class ChooseUsernameScreen extends StatefulWidget {
  const ChooseUsernameScreen({super.key, required this.nodeAddress});
  final String nodeAddress;

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  bool _isGenerating = false;
  bool _hasError = false;
  int _errorStepIndex = -1;

  final ValueNotifier<int> _stepNotifier = ValueNotifier(0);
  final NodeService _nodeService = NodeService();
  final KeyProvider _keyProvider = KeyProvider();
  final TextEditingController _usernameController = TextEditingController();

  final List<String> _steps = [
    "Registering user",
    "Generating identity key",
    "Generating signed prekey",
    "Generating one-time prekeys",
    "Signing keys",
    "Storing local identity",
    "Enrolling device with node",
  ];

  @override
  void initState() {
    _stepNotifier.addListener(() {
      if (mounted) setState(() {});
    });
    super.initState();
  }

  Future<void> _startKeyGeneration() async {
    if (_usernameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Username cannot be empty")));
      return;
    }
    if (_usernameController.text.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username cannot contain spaces")),
      );
      return;
    }
    if (_usernameController.text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username must be at least 3 characters")),
      );
      return;
    }
    setState(() {
      _isGenerating = true;
      _hasError = false;
      _errorStepIndex = -1;
    });

    try {
      await _nodeService.registerUser(
        widget.nodeAddress,
        _usernameController.text,
      );
      _stepNotifier.value = 1;
      await _keyProvider.initialize(_stepNotifier);
      await _nodeService.enrollDevice(_stepNotifier);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Keys generated successfully ✅")),
        );
      }
      _stepNotifier.value = _steps.length; // Complete all steps
    } catch (e) {
      if (kDebugMode) {
        print("Error during key generation: $e");
      }
      setState(() {
        _hasError = true;
        _errorStepIndex = _stepNotifier.value;
      });
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorStepIndex = -1;
      _stepNotifier.value = 0;
    });
    _startKeyGeneration();
  }

  Widget _buildCenteredButton({
    required VoidCallback onPressed,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isGenerating) ...[
                    const Icon(
                      Icons.account_circle_rounded,
                      size: 80,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Choose your username',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This username will be the only public information associated with your identity. '
                      'Others can use it to find or contact you.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    HushTextField(
                      hint: 'username',
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '🔒 We don’t store any other data — no phone number, no email.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _buildCenteredButton(
                      onPressed: _startKeyGeneration,
                      label: 'Generate Keys & Enroll Devices',
                      color: const Color(0xFF2563EB),
                      icon: Icons.vpn_key,
                    ),
                    const SizedBox(height: 32),
                    _buildCenteredButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      label: 'Go back',
                      color: const Color(0xFF2563EB),
                      icon: Icons.arrow_back,
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Text(
                      _hasError
                          ? 'An error occurred ❌'
                          : 'Generating your keys...',
                      style: TextStyle(
                        color: _hasError ? Colors.redAccent : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Column(
                      children: _steps.asMap().entries.map((entry) {
                        final i = entry.key;
                        final label = entry.value;
                        final done = i < _stepNotifier.value;
                        final isActive = i == _stepNotifier.value;
                        final isError = _hasError && _errorStepIndex == i;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isError
                                  ? Colors.redAccent
                                  : done
                                  ? Colors.greenAccent
                                  : isActive
                                  ? Colors.blueAccent
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isError
                                    ? Icons.error_outline
                                    : done
                                    ? Icons.check_circle
                                    : isActive
                                    ? Icons.autorenew_rounded
                                    : Icons.radio_button_unchecked,
                                color: isError
                                    ? Colors.redAccent
                                    : done
                                    ? Colors.greenAccent
                                    : isActive
                                    ? Colors.blueAccent
                                    : Colors.white38,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isError
                                        ? Colors.redAccent
                                        : done
                                        ? Colors.greenAccent
                                        : isActive
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    if (_stepNotifier.value >= _steps.length && !_hasError) ...[
                      const SizedBox(height: 32),
                      _buildCenteredButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConversationsScreen(),
                            ),
                          );
                        },
                        label: 'All done! Continue',
                        color: Colors.blueAccent,
                        icon: Icons.check,
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (_hasError) ...[
                      _buildCenteredButton(
                        onPressed: () {
                          setState(() {
                            _isGenerating = false;
                            _hasError = false;
                            _errorStepIndex = -1;
                          });
                        },
                        label: 'Go back',
                        color: Colors.blueAccent,
                        icon: Icons.arrow_back,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredButton(
                        onPressed: _retry,
                        label: 'Retry',
                        color: Colors.redAccent,
                        icon: Icons.refresh,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
