import 'package:flutter/material.dart';

class EventCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String dateText;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.title, required this.subtitle, required this.dateText, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Text(dateText, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
