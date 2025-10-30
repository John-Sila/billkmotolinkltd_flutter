import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/activity_scheduler.dart';
import 'package:flutter_application_1/pages/asset_manager.dart';
import 'package:flutter_application_1/pages/batteries.dart';
import 'package:flutter_application_1/pages/clock_in.dart';
import 'package:flutter_application_1/pages/clock_out.dart';
import 'package:flutter_application_1/pages/corrections.dart';
import 'package:flutter_application_1/pages/create_a_budget.dart';
import 'package:flutter_application_1/pages/create_a_memo.dart';
import 'package:flutter_application_1/pages/create_a_poll.dart';
import 'package:flutter_application_1/pages/polls.dart';
import 'package:flutter_application_1/pages/profiles.dart';
import 'package:flutter_application_1/pages/require.dart';
import 'package:flutter_application_1/pages/splash_screen.dart';
import 'package:flutter_application_1/pages/user_manager.dart';
import 'pages/dashboard.dart';
import 'pages/reports.dart';
import 'pages/settings.dart';
import 'pages/login.dart';
import 'pages/app_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // generated after Firebase setup

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BillkMotolinkApp());
}

class BillkMotolinkApp extends StatelessWidget {
  const BillkMotolinkApp({super.key});

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await Future.delayed(const Duration(milliseconds: 800)); // optional splash delay
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BILLK MOTOLINK LTD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[100], // Match body background
          elevation: 0.5,
          foregroundColor: Colors.black87, // Dark text color for contrast
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
      ),
      home: FutureBuilder(
        future: _initializeFirebase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Failed to initialize app:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            );
          } else {
            return const AuthGate();
          }
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // User is logged in
          return MainScaffold(
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
            },
          );
        }

        // User not logged in
        return LoginPage(
          onLogin: () async {
            // Firebase automatically triggers a rebuild after login
          },
        );
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  const MainScaffold({super.key, required this.onLogout});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    Dashboard(),
    ClockIn(),
    ClockOut(),
    Corrections(),
    Batteries(),
    Polls(),
    CreateBudget(),
    Requirements(),
    AssetManager(),
    UserManager(),
    Profiles(),
    CreatePoll(),
    CreateMemo(),
    ActivityScheduler(),
    Reports(),
    AppNotifications(),
    Settings(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Clock In',
    'Clock Out',
    'Correction',
    'Batteries',
    'Polls',
    'Create a Budget',
    'Require',
    'Asset Manager',
    'User Manager',
    'Profiles',
    'Create a Poll',
    'Create a Memo',
    'Activity Scheduler',
    'Reports',
    'Notifications',
    'Settings',
  ];
  

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Close the drawer if it's open
    Navigator.pop(context);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    widget.onLogout(); // triggers rebuild
  }

  // Custom drawer item builder with active state styling
  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final bool isSelected = _selectedIndex == index;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.teal.withOpacity(0.15) : Colors.transparent,
        border: isSelected 
            ? Border(
                left: BorderSide(
                  color: Colors.teal,
                  width: 4.0,
                ),
              )
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.teal : Colors.black87,
          size: isSelected ? 24 : 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.teal : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: isSelected ? 16 : 15,
          ),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.arrow_forward_ios,
                color: Colors.teal,
                size: 16,
              )
            : null,
        onTap: () => _onItemTapped(index),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in -> Show login page
        if (!snapshot.hasData) {
          return LoginPage(onLogin: () => setState(() {}));
        }

        // Logged in -> Show main UI
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _titles[_selectedIndex],
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            elevation: 0.5,
            backgroundColor: Colors.grey[100], // Match body background
            iconTheme: const IconThemeData(color: Colors.black87), // Hamburger menu color
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const UserAccountsDrawerHeader(
                  decoration: BoxDecoration(color: Colors.teal),
                  accountName: Text(
                    'BILLK MOTOLINK LTD',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  accountEmail: Text('info@billkmotolink.co.ke'),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      'B',
                      style: TextStyle(fontSize: 30, color: Colors.teal),
                    ),
                  ),
                ),
                _buildDrawerItem(index: 0, icon: Icons.dashboard, title: 'Dashboard'),
                _buildDrawerItem(index: 1, icon: Icons.add_link_outlined, title: 'Clock In'),
                _buildDrawerItem(index: 2, icon: Icons.cloud_sync_sharp, title: 'Clock Out'),
                _buildDrawerItem(index: 3, icon: Icons.webhook_sharp, title: 'Correction'),
                _buildDrawerItem(index: 4, icon: Icons.battery_4_bar_outlined, title: 'Batteries'),
                _buildDrawerItem(index: 5, icon: Icons.poll_rounded, title: 'Polls'),
                _buildDrawerItem(index: 6, icon: Icons.restaurant_menu_rounded, title: 'Create a Budget'),
                _buildDrawerItem(index: 7, icon: Icons.add_comment_sharp, title: 'Require'),
                _buildDrawerItem(index: 8, icon: Icons.electric_bike, title: 'Asset Manager'),
                _buildDrawerItem(index: 9, icon: Icons.verified_user_rounded, title: 'User Manager'),
                _buildDrawerItem(index: 10, icon: Icons.supervised_user_circle_rounded, title: 'Profiles'),
                _buildDrawerItem(index: 11, icon: Icons.how_to_vote_rounded, title: 'Create a Poll'),
                _buildDrawerItem(index: 12, icon: Icons.medical_information_outlined, title: 'Create a Memo'),
                _buildDrawerItem(index: 13, icon: Icons.timer, title: 'Activity Scheduler'),
                _buildDrawerItem(index: 14, icon: Icons.bar_chart_rounded, title: 'Reports'),
                _buildDrawerItem(index: 15, icon: Icons.notifications, title: 'Notifications'),
                _buildDrawerItem(index: 16, icon: Icons.settings, title: 'Settings'),
                const Divider(),
                Container(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: _logout,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.red.withOpacity(0.3)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          body: _pages[_selectedIndex],
        );
      },
    );
  }
}