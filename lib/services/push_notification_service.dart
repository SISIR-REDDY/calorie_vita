import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

/// Service to handle Firebase Cloud Messaging (FCM) push notifications
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  static final LoggerService _logger = LoggerService();
  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  
  // Notification streams
  final StreamController<RemoteMessage> _messageController = StreamController<RemoteMessage>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<RemoteMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  /// Initialize push notification service
  Future<void> initialize() async {
    try {
      _logger.info('Initializing push notification service');
      
      // Initialize Firebase Messaging
      _messaging = FirebaseMessaging.instance;
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permission
      await _requestPermission();
      
      // Configure message handlers
      await _configureMessageHandlers();
      
      // Get FCM token
      await _getFCMToken();
      
      _logger.info('Push notification service initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize push notification service', {'error': e.toString()});
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    
    await _localNotifications!.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      _logger.info('Notification permission status', {'status': settings.authorizationStatus.toString()});
    } catch (e) {
      _logger.error('Failed to request notification permission', {'error': e.toString()});
    }
  }

  /// Configure message handlers
  Future<void> _configureMessageHandlers() async {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle notification tap when app is terminated
    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Get FCM token and save to user profile
  Future<void> _getFCMToken() async {
    try {
      final token = await _messaging!.getToken();
      if (token != null) {
        _logger.info('FCM Token obtained', {'token': token.substring(0, 20) + '...'});
        
        // Save token to user profile
        await _saveTokenToUserProfile(token);
      }
    } catch (e) {
      _logger.error('Failed to get FCM token', {'error': e.toString()});
    }
  }

  /// Save FCM token to user profile
  Future<void> _saveTokenToUserProfile(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        
        _logger.info('FCM token saved to user profile');
      }
    } catch (e) {
      _logger.error('Failed to save FCM token to user profile', {'error': e.toString()});
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.info('Received foreground message', {
      'title': message.notification?.title,
      'body': message.notification?.body,
    });
    
    // Show local notification
    await _showLocalNotification(message);
    
    // Add to stream
    _messageController.add(message);
  }

  /// Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    _logger.info('Notification tapped', {
      'title': message.notification?.title,
      'data': message.data,
    });
    
    // Add to stream for navigation handling
    _notificationController.add(message.data);
  }

  /// Handle notification tap from local notifications
  void _onNotificationTapped(NotificationResponse response) {
    _logger.info('Local notification tapped', {'payload': response.payload});
    
    if (response.payload != null) {
      try {
        final data = Map<String, dynamic>.from(response.payload as Map);
        _notificationController.add(data);
      } catch (e) {
        _logger.error('Failed to parse notification payload', {'error': e.toString()});
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_localNotifications == null) return;
    
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'calorie_vita_channel',
        'Calorie Vita Notifications',
        channelDescription: 'Notifications for Calorie Vita app',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      await _localNotifications!.show(
        message.hashCode,
        message.notification?.title ?? 'Calorie Vita',
        message.notification?.body ?? '',
        platformChannelSpecifics,
        payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
      );
    } catch (e) {
      _logger.error('Failed to show local notification', {'error': e.toString()});
    }
  }

  /// Send notification to all users (Admin function)
  Future<void> sendNotificationToAllUsers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      _logger.info('Sending notification to all users', {'title': title});
      
      // Get all user FCM tokens
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('fcmToken', isNotEqualTo: null)
          .get();
      
      final tokens = usersSnapshot.docs
          .map((doc) => doc.data()['fcmToken'] as String)
          .where((token) => token.isNotEmpty)
          .toList();
      
      if (tokens.isEmpty) {
        _logger.warning('No FCM tokens found for users');
        return;
      }
      
      // Send to Firebase Cloud Functions or use FCM Admin SDK
      // For now, we'll log the notification details
      _logger.info('Notification prepared for sending', {
        'title': title,
        'body': body,
        'recipient_count': tokens.length,
        'data': data,
      });
      
      // TODO: Implement actual FCM sending via Cloud Functions
      // This would typically be done server-side for security
      
    } catch (e) {
      _logger.error('Failed to send notification to all users', {'error': e.toString()});
    }
  }

  /// Send notification to specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      _logger.info('Sending notification to user', {'userId': userId, 'title': title});
      
      // Get user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        _logger.warning('User not found', {'userId': userId});
        return;
      }
      
      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        _logger.warning('User has no FCM token', {'userId': userId});
        return;
      }
      
      // TODO: Implement actual FCM sending
      _logger.info('Notification prepared for user', {
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
      });
      
    } catch (e) {
      _logger.error('Failed to send notification to user', {'error': e.toString()});
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging!.subscribeToTopic(topic);
      _logger.info('Subscribed to topic', {'topic': topic});
    } catch (e) {
      _logger.error('Failed to subscribe to topic', {'error': e.toString()});
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging!.unsubscribeFromTopic(topic);
      _logger.info('Unsubscribed from topic', {'topic': topic});
    } catch (e) {
      _logger.error('Failed to unsubscribe from topic', {'error': e.toString()});
    }
  }

  /// Dispose resources
  void dispose() {
    _messageController.close();
    _notificationController.close();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  final logger = LoggerService();
  logger.info('Handling background message', {
    'title': message.notification?.title,
    'body': message.notification?.body,
  });
}
