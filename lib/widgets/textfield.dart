import 'package:flutter/material.dart';

class HushTextField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final TextEditingController? controller;
  final bool obscure;

  const HushTextField({
    super.key,
    required this.hint,
    this.icon,
    this.controller,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          cursorColor: const Color(0xFF3A8DFF),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon:
                icon != null ? Icon(icon, color: Colors.white70) : null,
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            hintStyle: const TextStyle(color: Colors.white54),
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
      ),
    );
  }
}
