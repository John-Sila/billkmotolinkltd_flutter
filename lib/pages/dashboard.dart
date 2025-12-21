import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:billkmotolinkltd/services/notifier.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  DocumentSnapshot<Map<String, dynamic>>? _userDoc;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _events = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _polls = [];
  bool _loading = true;
  String? _error;
  final NotificationService _notificationService = NotificationService();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadAll();


    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        // User logged in - start notification listeners
        _notificationService.onUserLoggedIn();
        uploadDeviceDataToFirestore(user.uid);
      } else {
        // User logged out - stop notification listeners
        _notificationService.onUserLoggedOut();
      }
    });
  }



  Future<void> _loadAll() async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final uid = user.uid;
      
      // Load user data with null safety
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userSnap.exists || !mounted) {
        setState(() => _loading = false);
        return;
      }

      // Clean old events and get recent ones
      final eventsSnap = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('event_time', descending: true)
          .get();

      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));

      // Delete old events safely
      for (final doc in eventsSnap.docs) {
        final data = doc.data();
        final ts = data['event_time'] as Timestamp?;
        if (ts != null && ts.toDate().isBefore(oneWeekAgo)) {
          await doc.reference.delete().catchError((e) {});
        }
      }

      // Filter valid events
      final validEvents = eventsSnap.docs
          .where((doc) {
            final data = doc.data();
            final ts = data['event_time'] as Timestamp?;
            return ts != null && ts.toDate().isAfter(oneWeekAgo);
          })
          .toList();

      // Get eligible polls safely
      final userData = userSnap.data() ?? {};
      final userRank = userData['userRank']?.toString() ?? '';
      
      List<QueryDocumentSnapshot<Map<String, dynamic>>> polls = [];
      if (userRank.isNotEmpty) {
        try {
          final pollsSnap = await FirebaseFirestore.instance
              .collection('polls')
              .orderBy('deadline')
              .get();
          polls = pollsSnap.docs;
        } catch (e) {
          // Ignore poll errors
        }
      }

      if (mounted) {
        setState(() {
          _userDoc = userSnap;
          _events = validEvents;
          _polls = polls;
          _loading = false;
        });
      }


      await _notificationService.checkNotificationsManually();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load dashboard: $e';
        });
      }
    }
  }

  Future<void> uploadDeviceDataToFirestore(String uid) async {
    try {
      // Check authentication first
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || uid != user.uid) {
        throw Exception('User not authenticated or UID mismatch');
      }

      // Initialize device info
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      Battery battery = Battery();
      Connectivity connectivity = Connectivity();

      Map<String, dynamic> deviceData = {
        'lastUploadTimestamp': FieldValue.serverTimestamp(),
        'uid': uid,
        'userEmail': user.email,
      };

      // Device hardware/software info - CORRECTED PROPERTIES
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceData.addAll({
          'platform': 'android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
          'deviceId': androidInfo.id,
          'product': androidInfo.product,
          'hardware': androidInfo.hardware,
          'display': androidInfo.display,
          'host': androidInfo.host,
          'osVersion': androidInfo.version.release,
          'apiLevel': androidInfo.version.sdkInt,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
          'supportedAbis': androidInfo.supportedAbis,
        });
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceData.addAll({
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'localizedModel': iosInfo.localizedModel,
          'utsnameMachine': iosInfo.utsname.machine,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        });
      }

      // Battery information
      try {
        deviceData['batteryLevel'] = await battery.batteryLevel;
        BatteryState state = await battery.batteryState;
        // Convert enum to readable string
        switch (state) {
          case BatteryState.full:
            deviceData['batteryState'] = 'Full';
            break;
          case BatteryState.charging:
            deviceData['batteryState'] = 'Charging';
            break;
          case BatteryState.discharging:
            deviceData['batteryState'] = 'Discharging';
            break;
          case BatteryState.unknown:
            deviceData['batteryState'] = 'Unknown';
            break;
          case BatteryState.connectedNotCharging:
            deviceData['batteryState'] = 'Connected (Not Charging)';
            break;
        }
      } catch (e) {
        deviceData['batteryLevel'] = null;
        deviceData['batteryState'] = 'Error';
        deviceData['batteryError'] = e.toString();
      }


      // Network connectivity - FIXED for new connectivity_plus API
      try {
        List<ConnectivityResult> results = await connectivity.checkConnectivity();
        
        // Take first result or prioritize (WiFi > Mobile > Other)
        ConnectivityResult primaryResult = ConnectivityResult.none;
        if (results.contains(ConnectivityResult.wifi)) {
          primaryResult = ConnectivityResult.wifi;
        } else if (results.contains(ConnectivityResult.mobile)) {
          primaryResult = ConnectivityResult.mobile;
        } else if (results.isNotEmpty) {
          primaryResult = results.first;
        }
        
        // Convert to readable string
        switch (primaryResult) {
          case ConnectivityResult.wifi:
            deviceData['networkType'] = 'WiFi';
            break;
          case ConnectivityResult.mobile:
            deviceData['networkType'] = 'Mobile Data';
            break;
          case ConnectivityResult.ethernet:
            deviceData['networkType'] = 'Ethernet';
            break;
          case ConnectivityResult.vpn:
            deviceData['networkType'] = 'VPN';
            break;
          case ConnectivityResult.bluetooth:
            deviceData['networkType'] = 'Bluetooth';
            break;
          case ConnectivityResult.other:
            deviceData['networkType'] = 'Other';
            break;
          case ConnectivityResult.none:
            deviceData['networkType'] = 'Offline';
            break;
        }
      } catch (e) {
        deviceData['networkType'] = 'Unknown';
      }



      // Screen information (Flutter 3+ compatible)
      final window = WidgetsBinding.instance.window;
      final mediaQuery = MediaQueryData.fromView(window);
      deviceData.addAll({
        'screenWidth': mediaQuery.size.width,
        'screenHeight': mediaQuery.size.height,
        'pixelRatio': mediaQuery.devicePixelRatio,
        'screenPadding': {
          'top': mediaQuery.padding.top,
          'bottom': mediaQuery.padding.bottom,
          'left': mediaQuery.padding.left,
          'right': mediaQuery.padding.right,
        },
      });

      // Update as a map in users/{uid}/device_info document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            'device_info': deviceData,
          }, SetOptions(merge: true));

    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAll,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Safe user data access
    final userData = _userDoc?.data() ?? {};
    final userName = userData['userName']?.toString() ?? 'User';
    final userRank = userData['userRank']?.toString() ?? 'User';

    final now = DateTime.now();
    final hour = now.hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: true,
              snap: true,
              pinned: true,
              collapsedHeight: kToolbarHeight,
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,

              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.waving_hand,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Welcome',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),







              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                        theme.colorScheme.primaryContainer,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          greeting,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),


                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 2),
                                blurRadius: 10,
                                color: Colors.black.withOpacity(0.4),
                              ),
                            ],
                            letterSpacing: 0.8,
                            height: 1.1,
                          ),
                        ),
                      ),

                        
                      ],
                    ),
                  ),
                
                
                
                
                ),
              ),
            ),

            
            
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Events Section
                    if (_events.isNotEmpty) ...[
                      _buildEventsSection(theme),
                      const SizedBox(height: 24),
                    ],

                    // Polls Section
                    if (_polls.isNotEmpty) ...[
                      _buildPollsSection(theme),
                      const SizedBox(height: 24),
                    ],

                    // Stats Cards - Safe null handling
                    _buildStatsCards(theme, userData),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection(ThemeData theme) {
    return Card(
      elevation: 8,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest ?? theme.colorScheme.surfaceVariant!,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.event, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  'Upcoming Events (${_events.length})',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ) ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Events List - Now clickable
            ..._events.map((doc) {
              final data = doc.data();
              final ts = data['event_time'] as Timestamp?;
              if (ts == null) return const SizedBox.shrink();
              
              final dt = ts.toDate();
              final isFuture = dt.isAfter(DateTime.now());
              
              return GestureDetector(
                onTap: () => _showEventDetails(context, doc, theme),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isFuture 
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest?.withValues(alpha: 0.5) ?? Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isFuture 
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : theme.colorScheme.outlineVariant ?? Colors.grey,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: isFuture ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isFuture ? Icons.schedule : Icons.history,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Event Preview Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title']?.toString() ?? 'No Title',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ) ?? const TextStyle(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['description']?.toString() ?? 'No description',
                                style: theme.textTheme.bodyMedium ?? const TextStyle(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Date + Arrow
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat('dd MMM').format(dt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ) ?? const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            DateFormat('HH:mm').format(dt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ) ?? const TextStyle(),
                          ),
                          const SizedBox(height: 4),
                          Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Add this method to your _DashboardState class
  void _showEventDetails(BuildContext context, QueryDocumentSnapshot doc, ThemeData theme) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['event_time'] as Timestamp?;
    final dt = ts?.toDate() ?? DateTime.now();
    final isFuture = dt.isAfter(DateTime.now());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFuture ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isFuture ? Icons.schedule : Icons.history,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data['title']?.toString() ?? 'Event Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date/Time
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(dt),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          DateFormat('HH:mm').format(dt),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Full Description
              Text(
                'Description',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data['description']?.toString() ?? 'No description available',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPollsSection(ThemeData theme) {
    return Card(
      elevation: 8,
      shadowColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest ?? theme.colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.poll, color: theme.colorScheme.secondary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  'Polls (${_polls.length})',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ) ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._polls.map((doc) {
              final data = doc.data();
              final deadlineTs = data['deadline'] as Timestamp?;
              if (deadlineTs == null) return const SizedBox.shrink();
              
              final deadline = deadlineTs.toDate();
              final expired = deadline.isBefore(DateTime.now());
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: expired 
                    ? theme.colorScheme.errorContainer ?? Colors.red.withValues(alpha: 0.1)
                    : theme.colorScheme.secondaryContainer ?? Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: expired 
                      ? theme.colorScheme.error
                      : theme.colorScheme.secondary,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      expired ? Icons.schedule_send : Icons.how_to_vote,
                      color: expired ? theme.colorScheme.error : theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title']?.toString() ?? 'No Title',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ) ?? const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Deadline: ${DateFormat('dd MMM yyyy').format(deadline)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: expired 
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSecondaryContainer ?? Colors.grey,
                            ) ?? const TextStyle(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatHours(Map<String, dynamic> user) {
    final isClockedIn = _toBool(user['isClockedIn']);
    if (!isClockedIn) return 'Unavailable';
    
    final clockInTime = user['clockInTime'] as Timestamp?;
    if (clockInTime == null) return 'Unavailable';
    
    final now = DateTime.now();
    final clockInDate = clockInTime.toDate();
    final hours = now.difference(clockInDate).inHours;
    final minutes = now.difference(clockInDate).inMinutes.remainder(60);
    
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  Widget _buildStatsCards(ThemeData theme, Map<String, dynamic> user) {
    final stats = [
      {'label': 'Daily Target', 'value': _formatNumber(user['dailyTarget'])},
      {'label': 'Sunday Target', 'value': _formatNumber(user['sundayTarget'])},
      {'label': 'Pending Amount', 'value': _formatNumber(user['pendingAmount'])},
      {'label': 'In-App Balance', 'value': _formatNumber(user['currentInAppBalance'])},
      {'label': 'Bike', 'value': (user['currentBike'] ?? 'N/A').toString()},
      {
        'label': 'Hours', 
        'value': _formatHours(user)
      },
    ];


    return Column(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.person, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              'Your Stats',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ) ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: stats.map((stat) => _buildStatCard(theme, stat['label']!, stat['value']!)).toList(),
        ),
        const SizedBox(height: 20),
        _buildStatusRow(theme, user),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, String value) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest ?? theme.colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ) ?? const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant ?? Colors.grey,
                fontWeight: FontWeight.w500,
              ) ?? const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(ThemeData theme, Map<String, dynamic> user) {
    final statuses = [
      {'label': 'Clocked In', 'value': _toBool(user['isClockedIn']), 'icon': Icons.access_time},
      {'label': 'Charging', 'value': _toBool(user['isCharging']), 'icon': Icons.battery_charging_full},
      {'label': 'Active', 'value': _toBool(user['isActive']), 'icon': Icons.power},
      {'label': 'Verified', 'value': _toBool(user['isVerified']), 'icon': Icons.verified},
      {'label': 'Sunday', 'value': _toBool(user['isWorkingOnSunday']), 'icon': Icons.calendar_today},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant ?? Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: statuses.map((status) {
              final isActive = status['value'] as bool;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive 
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : (theme.colorScheme.surfaceContainerHighest ?? Colors.grey).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive 
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant ?? Colors.grey,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status['icon'] as IconData,
                      size: 16,
                      color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant ?? Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status['label'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant ?? Colors.grey,
                      ) ?? const TextStyle(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return 'KSh 0';
    final numValue = value is num ? value : num.tryParse(value.toString()) ?? 0;
    
    if (numValue >= 1000000) {
      return 'KSh ${(numValue / 1000000).toStringAsFixed(1)}M';
    }
    
    // ✅ ALWAYS show full number with commas - no K rounding
    final formatter = NumberFormat('#,##0');
    return 'KSh ${formatter.format(numValue.toInt())}';
  }



  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }

}
