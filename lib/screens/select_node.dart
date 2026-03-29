import 'package:flutter/material.dart';
import 'package:hushnet_frontend/widgets/button.dart';
import 'package:hushnet_frontend/widgets/connection/bottom_sheet.dart';
import 'package:hushnet_frontend/widgets/textfield.dart';
import 'package:lottie/lottie.dart';

class SelectNodeScreen extends StatelessWidget {
  const SelectNodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _nodeController = TextEditingController();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/node.json', width: 200, height: 200),

              Text(
                'Select your node',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'With HushNet, you can choose to connect to any node that supports our protocol. This gives you the freedom to select a node that aligns with your privacy and security preferences.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
              ),
              Text(
                'When you select a node, you are choosing the server that will handle your messages and data.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              Text(
                'Once the URL is entered, its privacy features will be displayed, allowing you to make an informed decision.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
              ),
              const SizedBox(height: 32),
              HushTextField(
                hint: 'Enter node URL',
                icon: Icons.link,
                controller: _nodeController,
              ),
              const SizedBox(height: 32),
              HushButton(
                label: "Connect",
                icon: Icons.link,
                onPressed: () {
                  String nodeAddress = _nodeController.text.trim();
                  // Remove trailing slash if present
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
                },
              ),
              const SizedBox(height: 16),
              HushButton(
                label: "Go back",
                icon: Icons.arrow_back,
                color: Colors.grey[700]!,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
