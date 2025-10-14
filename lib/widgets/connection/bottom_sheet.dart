import 'package:flutter/material.dart';
import 'package:hushnet_frontend/data/node/node_connection.dart';

void showConnectionSheet(BuildContext context, String nodeAddress) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color.fromRGBO(30, 30, 30, 1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (context) => ConnectionStepsSheet(nodeAddress: nodeAddress),
  );
}

class ConnectionStepsSheet extends StatefulWidget {
    final String nodeAddress;
  const ConnectionStepsSheet({
    super.key, required this.nodeAddress});

  @override
  State<ConnectionStepsSheet> createState() => _ConnectionStepsSheetState();
}

class _ConnectionStepsSheetState extends State<ConnectionStepsSheet> {
  ValueNotifier<int> stepNotifier = ValueNotifier(0);
  ValueNotifier<bool> errorNotifier = ValueNotifier(false);
  final List<String> _steps = [
    "Resolving node address",
    "Fetching metadata",
    "Verifying certificate",
    "Session established",
  ];

  @override
  void initState() {
    super.initState();
    stepNotifier = ValueNotifier(0);
    stepNotifier.addListener(() {
      if (mounted) setState(() {});
    });
    errorNotifier = ValueNotifier(false);
    errorNotifier.addListener(() {
      if (mounted) setState(() {});
    });
    connectToNode(stepNotifier, errorNotifier, widget.nodeAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Text(
            "Connecting to node…",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(_steps.length, (i) {
            final bool done = i < stepNotifier.value;
            final bool current = i == stepNotifier.value;
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Circle indicator
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: done
                            ? Colors.greenAccent
                            : current
                            ? Colors.blueAccent
                            : Colors.grey[700],
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.black,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _steps[i],
                        style: TextStyle(
                          color: done
                              ? Colors.white
                              : current
                              ? Colors.white70
                              : Colors.grey[500],
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (i < _steps.length - 1)
                  Container(
                    margin: const EdgeInsets.only(left: 9, top: 4, bottom: 4),
                    width: 2,
                    height: 20,
                    color: i < stepNotifier.value - 1
                        ? errorNotifier.value
                              ? Colors.red
                              : Colors.greenAccent
                        : Colors.grey[700],
                  ),
              ],
            );
          }),
          if (stepNotifier.value >= _steps.length && !errorNotifier.value)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Continue',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (errorNotifier.value)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Failed to connect to the node. Please check the URL and try again.',
                style: TextStyle(color: Colors.red[400], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),

          if (errorNotifier.value)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Close',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
