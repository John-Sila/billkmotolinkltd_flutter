import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this for DartPluginRegistrant

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  const AndroidInitializationSettings initializationSettingsIOS =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  const InitializationSettings fullInitSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  
  await flutterLocalNotificationsPlugin.initialize(fullInitSettings);
}


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _lastPersonalNotifId;
  String? _lastGeneralNotifId;

  String? _userId; // Store user ID properly

  void startListeners() {
    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (_userId == null) {
      return;
    }
    _listenToPersonalNotifications();
    _listenToGeneralNotifications();
  }

  void _listenToPersonalNotifications() {
    _firestore.collection('users').doc(_userId!).snapshots().listen((userDoc) async {
      if (!userDoc.exists) return;
      
      final data = userDoc.data()!;
      final notifications = data['notifications'] as Map<String, dynamic>? ?? {};
      final numberOfNotifs = data['numberOfNotifications'] as int? ?? 0;
      
      
      if (numberOfNotifs > 0 && notifications.isNotEmpty) {
        String? latestNotifId;
        Timestamp? latestTime;
        
        notifications.forEach((notifId, notifData) {
          final isRead = notifData['isRead'] as bool? ?? true; // Default to true
          final time = notifData['time'] as Timestamp?;
          
          if (!isRead && time != null && 
              (latestTime == null || time.toDate().isAfter(latestTime!.toDate()))) {
            latestTime = time;
            latestNotifId = notifId;
          }
        });
        
        if (latestNotifId != null && latestNotifId != _lastPersonalNotifId) {
          _lastPersonalNotifId = latestNotifId;
          final notifData = notifications[latestNotifId];
          await _showNotification(
            title: 'New Personal Notification',
            body: notifData['message'] ?? 'You have a new notification',
          );
        }
      }
    }, onError: (error) {
    });
  }

  void _listenToGeneralNotifications() async {
    _firestore.collection('notifications').doc('latest').snapshots().listen((doc) async {
      print("General doc changed: ${doc.id}");
      
      if (doc.exists) {
        final data = doc.data()!;
        final targetRoles = List<String>.from(data['targetRoles'] ?? []);
        print("Target roles: $targetRoles");
        
        // Check if current user has matching role
        final userRole = await _getUserRank();
        print("Current user role: $userRole");
        
        if (userRole != null && targetRoles.contains(userRole)) {
          print("✅ User eligible for notification");
          await _showNotification(
            title: data['title'] ?? 'New Update',
            body: data['body'] ?? 'New notification available',
          );
          _lastGeneralNotifId = doc.id;
        } else {
          print("❌ User role '$userRole' not in target roles $targetRoles");
        }
      }
    }, onError: (error) {
      print("General listener error: $error");
    });
  }

  // Helper method to get user's rank
  Future<String?> _getUserRank() async {
    try {
      final userId = _userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return userData['userRank'] as String?;
      }
      return null;
    } catch (e) {
      print("Error getting user rank: $e");
      return null;
    }
  }


  Future<void> _showNotification({required String title, required String body}) async {
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Important app notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails notificationDetails = 
        NotificationDetails(android: androidDetails);
    
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Use seconds, not remainder
      title,
      body,
      notificationDetails,
      payload: 'notification_payload',
    );
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  if (service is AndroidServiceInstance) {
    // CORRECT WAY: Set foreground service with notification
    service.setAsForegroundService();
    
    // CORRECT WAY: Set foreground notification info
    service.setForegroundNotificationInfo(
      title: "Notification Service Active",
      content: "Listening for new notifications...",
    );
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });


  // Initialize Firebase and notifications
  await Firebase.initializeApp();
  await initNotifications();
  
  // Start notification service
  final notificationService = NotificationService();
  notificationService.startListeners();

  // Keep service alive - update notification every 30 seconds
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "BILLK Service Running",
        content: "Running... ${DateTime.now().toString().substring(11, 19)}",
      );
    }
  });
}



Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(),
  );
  
  // Start the service
  await service.startService();
}

