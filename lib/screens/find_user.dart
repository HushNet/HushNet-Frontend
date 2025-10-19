import 'package:flutter/material.dart';
import 'package:hushnet_frontend/screens/choose_username.dart';
import 'package:hushnet_frontend/screens/conversations_screen.dart';
import 'package:hushnet_frontend/services/node_service.dart';
import 'package:hushnet_frontend/widgets/button.dart';
import 'package:lottie/lottie.dart';

class FindUserScreen extends StatefulWidget {
  const FindUserScreen({super.key, required this.nodeAddress});
  final String nodeAddress;

  @override
  State<FindUserScreen> createState() => _FindUserScreenState();
}

class _FindUserScreenState extends State<FindUserScreen> {
  final NodeService _nodeService = NodeService();
  ValueNotifier<int> stepNotifier = ValueNotifier(0);
  String? username;

  final List<String> _steps = [
    "Generating proof of identity",
    "Sending signed request to node",
    "Verifying identity signature",
    "Fetching user information",
  ];

  bool _isDone = false;

  @override
  void initState() {
    stepNotifier.addListener(() {
      if (mounted) setState(() {});
    });
    _nodeService.loginUser(widget.nodeAddress, stepNotifier).then((value) {
      setState(() {
        username = value;
        _isDone = true;
        stepNotifier.value = 4; // Mark all steps as done
      });
    }).catchError((error) {
      setState(() {
        _isDone = true;
        stepNotifier.value = 4; // Mark all steps as done
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/verify.json', width: 180, height: 180),
              const SizedBox(height: 16),
              if (!_isDone || username == null)
                Text(
                  'Trying to find user…',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
              if (_isDone && username != null)
                Text(
                  'Welcome back, $username!',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(_steps.length, (index) {
                    final done = index <= stepNotifier.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: done ? Colors.greenAccent : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _steps[index],
                              style: TextStyle(
                                color: done ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 32),
              if (_isDone && username != null)
                Text(
                  'You have been automatically logged in using your in-device identity.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              if (_isDone && username == null)
                Text(
                  'No existing user found. We can create a new one.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              if (_isDone) const SizedBox(height: 24),
              if (_isDone)
                HushButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: () {
                    if (username != null) {
                                          Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConversationsScreen(
                        ),
                      ),
                    );
                    } else {
                      Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChooseUsernameScreen(
                          nodeAddress: widget.nodeAddress,
                        ),
                      ),
                    );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
