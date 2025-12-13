import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/pages/charge_batteries.dart';
import 'package:flutter_application_1/pages/settings.dart';
import 'package:flutter_application_1/pages/swap_batteries.dart';
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
import 'pages/activity_scheduler.dart';
import 'pages/reports.dart';
import 'pages/app_notifications.dart';
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

class _MainScaffoldState extends State<MainScaffold> with SingleTickerProviderStateMixin {


  int _selectedIndex = 0;
  bool _isDarkMode = false;

  late AnimationController _controller;
  bool _isExpanded = false;
  Timer? _animationTimer;

  final List<Widget> _pages = [
    Dashboard(),
    ClockIn(),
    SwapBatteries(),
    ChargeBatteries(),
    ClockOut(),
    Corrections(),
    Batteries(uid: FirebaseAuth.instance.currentUser!.uid),
    Polls(),
    CreateBudget(),
    Requirements(),
    AssetManager(),
    UserManager(),



    Profiles(),
    CreatePoll(),
    ActivityScheduler(),
    Reports(),
    UserSettings()
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Clock In',
    'Swap Batteries',
    'Charge Batteries',
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
    'Activity Scheduler',
    'Reports',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _loadThemePreference();


     _controller = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
      
      // Start pulsing animation
      _startPulsing();

  }

  void _startPulsing() {
    _animationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isExpanded) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
      _isExpanded = !_isExpanded;
    });
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
  
  @override
  void dispose() {
    _controller.dispose();
    _animationTimer?.cancel();
    super.dispose();
  }




  // 1. Gradient for header (Light/Dark variants)
  List<Color> _getDrawerGradient(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return isDark
        ? [
            Colors.teal.shade900,
            Colors.teal.shade800,
            Colors.teal.shade700,
          ]
        : [
            Colors.teal,
            Colors.teal.shade400,
            Colors.teal.shade600,
          ];
  }

  // 2. Content background color
  Color _getDrawerContentBg(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? Colors.grey.shade900
        : Colors.white;
  }

// 3. Beautiful adaptive header
Widget _buildDrawerHeader(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  
  return Container(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.1)]
                  : [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black.withValues(alpha: 0.3)).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.two_wheeler,
            size: 48,
            color: isDark ? Colors.white : Colors.teal.shade700,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'BILLK MOTOLINK LTD',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Redefining Urban Mobility',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.teal.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            'billkmotolinkltd.netlify.app',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.teal.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

  // 4. Adaptive drawer items
  Widget _buildModernDrawerItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String title,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? (isDark ? Colors.teal.withValues(alpha: 0.3) : Colors.teal.withValues(alpha: 0.12))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(
                color: Colors.teal.withValues(alpha: isDark ? 0.5 : 0.3),
                width: 1.5,
              )
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: isDark ? 0.4 : 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(colors: [Colors.teal.shade500, Colors.teal.shade700])
                : LinearGradient(
                    colors: isDark
                        ? [Colors.white.withValues(alpha: 0.2), Colors.transparent]
                        : [Colors.grey.withValues(alpha: 0.2), Colors.transparent],
                  ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.white70 : Colors.grey[700]),
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected 
                ? Colors.teal.shade900 
                : (isDark ? Colors.white : Colors.grey[800]),
          ),
        ),
        trailing: isSelected
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.teal.shade500, Colors.teal]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 14,
                ),
              )
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onTap: () => _onItemTapped(index),
        hoverColor: Colors.teal.withValues(alpha: isDark ? 0.2 : 0.08),
      ),
    );
  }

  // 5. Adaptive bottom section
  Widget _buildBottomActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: _getDrawerContentBg(theme),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black.withValues(alpha: 0.1)).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.brightness_6, color: Colors.teal, size: 22),
            ),
            title: Text(
              'Dark Mode',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            value: _isDarkMode,
            onChanged: (value) async {
              await widget.onThemeChanged(value);
              setState(() => _isDarkMode = value);
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [Colors.red.shade700, Colors.red.shade500]
                    : [Colors.red, Colors.redAccent],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _logout,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        actions: [
          // Notification icon with count badge
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              // Get the notification count
              final notificationCount = snapshot.data?.data() is Map<String, dynamic>
                  ? (snapshot.data!.data() as Map<String, dynamic>)['numberOfNotifications'] ?? 0
                  : 0;
              
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppNotifications(),
                        ),
                      );
                    },
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 0.75 + (_controller.value * 0.2), // Expands by 20%
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                notificationCount > 9 ? '9+' : notificationCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                
                
                ],
              );
            },
          ),
        ],
      ),


  drawer: Drawer(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _getDrawerGradient(Theme.of(context)),
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Adaptive Header
            _buildDrawerHeader(context),
            
            // Menu Items Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _getDrawerContentBg(Theme.of(context)),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  itemCount: _titles.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedIndex == index;
                    return _buildModernDrawerItem(
                      context: context,
                      index: index,
                      icon: _getDrawerIcon(index),
                      title: _titles[index],
                      isSelected: isSelected,
                    );
                  },
                ),
              ),
            ),
            
            // Adaptive Bottom Actions
            _buildBottomActions(context),
          ],
        ),
      ),
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
        return Icons.swap_horiz;
      
      case 3:
        return Icons.battery_charging_full;
      
      case 4:
        return Icons.cloud_sync_sharp;
      case 5:
        return Icons.webhook_sharp;
      case 6:
        return Icons.battery_4_bar_outlined;
      case 7:
        return Icons.poll_rounded;
      case 8:
        return Icons.restaurant_menu_rounded;
      case 9:
        return Icons.add_comment_sharp;
      case 10:
        return Icons.electric_bike;
      case 11:
        return Icons.verified_user_rounded;
      case 12:
        return Icons.supervised_user_circle_rounded;
      case 13:
        return Icons.how_to_vote_rounded;
      case 14:
        return Icons.timer;
      case 15:
        return Icons.bar_chart_rounded;
      case 16:
        return Icons.settings;
      default:
        return Icons.circle;
    }
  }
}
