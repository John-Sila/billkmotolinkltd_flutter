import 'package:flutter/material.dart';

class Reports extends StatelessWidget {
  const Reports({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Reports Center',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Access your business analytics, financial summaries, and performance metrics here.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 30),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.teal),
            title: const Text('Weekly Analysis Report'),
            subtitle: const Text('View total rider revenue trends for the week.'),
            onTap: () {},
          ),
        ),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.people, color: Colors.teal),
            title: const Text('Rider Daily Statistics'),
            subtitle: const Text('View rider engagement insights.'),
            onTap: () {},
          ),
        ),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.restaurant_menu_rounded, color: Colors.teal),
            title: const Text('Human Resource'),
            subtitle: const Text('See reports that await action.'),
            onTap: () {},
          ),
        ),
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.bar_chart_rounded, color: Colors.teal),
            title: const Text('General As-Is State'),
            subtitle: const Text('See how the company is doing this week.'),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
