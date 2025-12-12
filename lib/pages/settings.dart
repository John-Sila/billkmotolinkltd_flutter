import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/my_profile.dart';

class UserSettings extends StatelessWidget {
  const UserSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Application Settings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.person_outline, color: Colors.teal),
          title: const Text(
            'My Account',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MyProfile()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.format_list_bulleted_add, color: Colors.teal),
          title: const Text(
            'Terms of Service',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MyProfile()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.calendar_month_sharp, color: Colors.teal),
          title: const Text(
            'Company Calendar',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MyProfile()),
            );
          },
        ),
        const Divider(height: 40),
        SwitchListTile(
          value: true,
          title: const Text('Enable Notifications'),
          subtitle: const Text('Receive updates on new activity'),
          activeThumbColor: Colors.teal,
          onChanged: (bool value) {},
        ),
        SwitchListTile(
          value: false,
          title: const Text('Dark Mode'),
          subtitle: const Text('Switch between light and dark themes'),
          activeThumbColor: Colors.teal,
          onChanged: (bool value) {},
        ),
        const Divider(height: 40),
        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.teal),
          title: const Text('About BILLK MOTOLINK LTD'),
          subtitle: const Text('Learn more about the company'),
          onTap: () {},
        ),
      ],
    );
  }
}
