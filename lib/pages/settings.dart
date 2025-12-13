import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/help_and_faq.dart';
import 'package:flutter_application_1/pages/my_profile.dart';
import 'package:flutter_application_1/pages/terms_and_conditions.dart';

class UserSettings extends StatefulWidget {
  const UserSettings({super.key});

  @override
  State<UserSettings> createState() => _UserSettingsState();
}

class _UserSettingsState extends State<UserSettings> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _biometricEnabled = true;
  double _volume = 0.7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          // Account Section
          _buildSectionHeader('Account'),
          _buildNavTile(
            context,
            Icons.person_outline,
            'My Profile',
            'Manage your account details',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyProfile()),
            ),
          ),

          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader('Appearance'),
          SwitchListTile.adaptive(
            value: _darkModeEnabled,
            onChanged: (value) => setState(() => _darkModeEnabled = value),
            title: Text('Dark Mode', style: theme.textTheme.titleMedium),
            subtitle: const Text('Switch between light and dark themes'),
            activeThumbColor: Colors.teal,
            activeTrackColor: Colors.teal.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.only(left: 4, right: 16),
          ),

          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _biometricEnabled,
            onChanged: (value) => setState(() => _biometricEnabled = value),
            title: Text('Biometric Login', style: theme.textTheme.titleMedium),
            subtitle: const Text('Use fingerprint or face ID'),
            activeThumbColor: Colors.teal,
            activeTrackColor: Colors.teal.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.only(left: 4, right: 16),
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          SwitchListTile.adaptive(
            value: _notificationsEnabled,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
            title: Text('Push Notifications', style: theme.textTheme.titleMedium),
            subtitle: const Text('Receive updates on new activity'),
            activeThumbColor: Colors.teal,
            activeTrackColor: Colors.teal.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.only(left: 4, right: 16),
          ),
          _buildSliderTile(
            context,
            Icons.volume_up,
            'Notification Volume',
            _volume,
            (value) => setState(() => _volume = value),
          ),

          const SizedBox(height: 24),

          // Data & Storage
          _buildSectionHeader('Data & Storage'),
          _buildNavTile(
            context,
            Icons.storage,
            'Manage Storage',
            'View and clear app data',
            () {},
          ),
          _buildNavTile(
            context,
            Icons.history_edu_outlined,
            'Download History',
            'View downloaded content',
            () {},
          ),

          const SizedBox(height: 24),

          // Support Section
          _buildSectionHeader('Support'),
          _buildNavTile(
            context,
            Icons.help_outline,
            'Help & FAQ',
            'Get help with common issues',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpAndFAQ()),
            ),
          ),
          _buildNavTile(
            context,
            Icons.format_list_bulleted,
            'Terms of Service',
            'Review our terms and conditions',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TermsAndConditions()),
            ),
          ),
          _buildNavTile(
            context,
            Icons.calendar_month,
            'Company Calendar',
            'View company events',
            () {},
          ),
          _buildNavTile(
            context,
            Icons.info_outline,
            'About BILLK MOTOLINK LTD',
            'Version 2.1.3 | Learn more about us',
            () {},
          ),

          const SizedBox(height: 32),
          
          // Logout
          _buildDestructiveTile(
            context,
            Icons.logout,
            'Log Out',
            () {
              // Handle logout
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.teal, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, 
                   color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context,
    IconData icon,
    String title,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: onChanged,
              activeColor: Colors.teal,
              inactiveColor: Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestructiveTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.red, size: 24),
              const SizedBox(width: 16),
              Text(title, 
                   style: const TextStyle(
                     color: Colors.red,
                     fontWeight: FontWeight.w600,
                     fontSize: 16,
                   )),
            ],
          ),
        ),
      ),
    );
  }
}
