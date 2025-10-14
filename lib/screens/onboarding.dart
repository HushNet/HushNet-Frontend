import 'package:flutter/material.dart';
import 'package:hushnet_frontend/screens/select_node.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/hushnet_icon.png', width: 200, height: 200, color: Colors.white),
                  Text('HushNet',
                      style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text('Silent. Secure. Sovereign.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[400])),
              Text('HushNet is a decentralized end-to-end messaging service that prioritizes user privacy and data security.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[400])),
              Text('Join us in building a communication platform that empowers users to take control of their digital interactions.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[400])),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const SelectNodeScreen()));
                },
                child: Text('Get Started', style: Theme.of(context).textTheme.bodyMedium),
              ),
              const Spacer(),
              Text('Completely open source. Made with ❤️ in Marseille.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
