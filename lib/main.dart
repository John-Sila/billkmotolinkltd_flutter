import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/firebase_options.dart';

// Pages
import 'pages/dashboard.dart';
import 'pages/clock_in.dart';
import 'pages/clock_out.dart';
import 'pages/corrections.dart';
import 'pages/batteries.dart';
import 'pages/polls.dart';
import 'pages/create_a_budget.dart';
import 'pages/require.dart';
import 'pages/asset_manager.dart';
import 'pages/user_manager.dart';
import 'pages/profiles.dart';
import 'pages/create_a_poll.dart';
import 'pages/create_a_memo.dart';
import 'pages/activity_scheduler.dart';
import 'pages/reports.dart';
import 'pages/app_notifications.dart';
import 'pages/settings.dart';
import 'pages/login.dart';
import 'pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load saved theme before runApp
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(BillkMotolinkApp(initialIsDarkMode: isDarkMode));
}

class BillkMotolinkApp extends StatefulWidget {
  final bool initialIsDarkMode;
  const BillkMotolinkApp({super.key, required this.initialIsDarkMode});

  @override
  State<BillkMotolinkApp> createState() => _BillkMotolinkAppState();
}

class _BillkMotolinkAppState extends State<BillkMotolinkApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialIsDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _toggleTheme(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BILLK MOTOLINK LTD',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: AuthGate(onThemeChanged: _toggleTheme),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.teal,
      scaffoldBackgroundColor: Colors.grey[100],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[100],
        elevation: 0.5,
        foregroundColor: Colors.black87,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
      listTileTheme: const ListTileThemeData(iconColor: Colors.black87),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.teal,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0.5,
        foregroundColor: Colors.white,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF1E1E1E)),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
      colorScheme: const ColorScheme.dark(
        primary: Colors.teal,
        secondary: Colors.tealAccent,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final Function(bool) onThemeChanged;
  const AuthGate({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData) {
          return MainScaffold(
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
            },
            onThemeChanged: onThemeChanged,
          );
        }

        return LoginPage(onLogin: () async {});
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  final Function(bool) onThemeChanged;
  const MainScaffold({
    super.key,
    required this.onLogout,
    required this.onThemeChanged,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  bool _isDarkMode = false;

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

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    widget.onLogout();
  }

  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final bool isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? Colors.teal.withOpacity(0.25) : Colors.teal.withOpacity(0.15))
            : Colors.transparent,
        border: isSelected
            ? const Border(left: BorderSide(color: Colors.teal, width: 4.0))
            : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.teal : theme.iconTheme.color),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.teal : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.arrow_forward_ios, color: Colors.teal, size: 16)
            : null,
        onTap: () => _onItemTapped(index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _isDarkMode = isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              accountName: Text(
                'BILLK MOTOLINK LTD',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              accountEmail: Text('https://billkmotolinkltd.netlify.app'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text('B', style: TextStyle(fontSize: 30, color: Colors.teal)),
              ),
            ),
            for (int i = 0; i < _titles.length; i++)
              _buildDrawerItem(
                index: i,
                icon: _getDrawerIcon(i),
                title: _titles[i],
              ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_6, color: Colors.teal),
              title: const Text('Dark Mode'),
              value: _isDarkMode,
              onChanged: (value) async {
                await widget.onThemeChanged(value);
                setState(() => _isDarkMode = value);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  IconData _getDrawerIcon(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard;
      case 1:
        return Icons.add_link_outlined;
      case 2:
        return Icons.cloud_sync_sharp;
      case 3:
        return Icons.webhook_sharp;
      case 4:
        return Icons.battery_4_bar_outlined;
      case 5:
        return Icons.poll_rounded;
      case 6:
        return Icons.restaurant_menu_rounded;
      case 7:
        return Icons.add_comment_sharp;
      case 8:
        return Icons.electric_bike;
      case 9:
        return Icons.verified_user_rounded;
      case 10:
        return Icons.supervised_user_circle_rounded;
      case 11:
        return Icons.how_to_vote_rounded;
      case 12:
        return Icons.medical_information_outlined;
      case 13:
        return Icons.timer;
      case 14:
        return Icons.bar_chart_rounded;
      case 15:
        return Icons.notifications;
      case 16:
        return Icons.settings;
      default:
        return Icons.circle;
    }
  }
}
