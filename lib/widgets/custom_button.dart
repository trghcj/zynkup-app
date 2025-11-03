import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const CustomButton({super.key, required this.label, required this.onTap, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Text(label),
    );
  }
}
