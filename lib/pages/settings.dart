import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/help_and_faq.dart';
import 'package:flutter_application_1/pages/my_profile.dart';
import 'package:flutter_application_1/pages/terms_and_conditions.dart';
import 'package:flutter_application_1/pages/view_and_clear_app_data.dart';

class UserSettings extends StatefulWidget {
  const UserSettings({super.key});

  @override
  State<UserSettings> createState() => _UserSettingsState();
}

class _UserSettingsState extends State<UserSettings> {

  Future<void> logout() async {
    // Implement your logout logic here
    FirebaseAuth.instance.signOut();
  }



  @override
  Widget build(BuildContext context) {
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

          // Data & Storage
          _buildSectionHeader('Data & Storage'),
          _buildNavTile(
            context,
            Icons.storage,
            'Manage Storage',
            'View and clear app data',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ViewAndClearAppData()),
            ),
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
            'Version 2.1.1 | Learn more about us',
            () {},
          ),

          const SizedBox(height: 32),
          
          // Logout
          _buildDestructiveTile(
            context,
            Icons.logout,
            'Log Out',
            () {
              logout();
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


Widget _buildDestructiveTile(
  BuildContext context,
  IconData icon,
  String title,
  VoidCallback onTap,
) {
  Theme.of(context);
  
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.red.withValues(alpha: 0.15),
          Colors.red.shade50,
          Colors.red.withValues(alpha: 0.1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.red.withValues(alpha: 0.4),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.red.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.red.withValues(alpha: 0.15),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        splashColor: Colors.red.withValues(alpha: 0.2),
        highlightColor: Colors.red.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(
            children: [
              // Animated Icon Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade500, Colors.red.shade700],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              
              // Title with gradient text
              Expanded(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.red.shade800, Colors.red.shade600],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Trailing arrow with glow
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.6),
                      blurRadius: 12,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}



}
