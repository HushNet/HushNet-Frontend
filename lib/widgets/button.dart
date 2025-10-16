import 'package:flutter/material.dart';

class HushButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color color;
  final bool fullWidth;

  const HushButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = const Color(0xFF2563EB),
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );

    if (fullWidth) return button;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: button,
      ),
    );
  }
}
