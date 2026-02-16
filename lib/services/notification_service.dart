import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  // Handle background notification here
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // ────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Request notification permissions
    await _requestPermissions();

    // Initialize local notifications (for Android)
    await _initializeLocalNotifications();

    // Get FCM token
    await _getFCMToken();

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    _setupForegroundNotificationHandler();

    // Handle notification taps
    _setupNotificationTapHandler();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveFCMTokenToFirestore(newToken);
    });
  }

  // ────────────────────────────────────────────────────────────
  // PERMISSIONS
  // ────────────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    // iOS permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
        'Notification permission status: ${settings.authorizationStatus}');

    // Android 13+ permissions
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  // ────────────────────────────────────────────────────────────
  // LOCAL NOTIFICATIONS (ANDROID)
  // ────────────────────────────────────────────────────────────

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'laundrify_notifications',
      'Laundrify Notifications',
      description: 'Notifications for order updates and account activities',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // ────────────────────────────────────────────────────────────
  // FCM TOKEN MANAGEMENT
  // ────────────────────────────────────────────────────────────

  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      debugPrint('FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _saveFCMTokenToFirestore(_fcmToken!);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _saveFCMTokenToFirestore(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // FOREGROUND MESSAGE HANDLER
  // ────────────────────────────────────────────────────────────

  void _setupForegroundNotificationHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received: ${message.messageId}');

      // Show local notification when app is in foreground
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      'laundrify_notifications',
      'Laundrify Notifications',
      channelDescription: 'Notifications for order updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: json.encode(message.data),
    );
  }

  // ────────────────────────────────────────────────────────────
  // NOTIFICATION TAP HANDLER
  // ────────────────────────────────────────────────────────────

  void _setupNotificationTapHandler() {
    // When app is opened from notification (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from terminated state
    _fcm.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = json.decode(response.payload!);
      debugPrint('Notification tapped with data: $data');
      // Handle navigation based on notification data
      _navigateBasedOnNotification(data);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    _navigateBasedOnNotification(message.data);
  }

  void _navigateBasedOnNotification(Map<String, dynamic> data) {
    // Implement navigation logic based on notification type
    final type = data['type'] as String?;
    final orderId = data['orderId'] as String?;

    debugPrint('Navigate to: type=$type, orderId=$orderId');

    // Navigation handled via GlobalKey<NavigatorState> in main.dart
    // Notification tap data is logged above for debugging
  }

  // ────────────────────────────────────────────────────────────
  // PUBLIC METHODS
  // ────────────────────────────────────────────────────────────

  /// Subscribe to a topic (e.g., "all_users", "premium_users")
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteToken() async {
    await _fcm.deleteToken();
    _fcmToken = null;
  }

  /// Get notification badge count (for app icon badge)
  Future<int> getBadgeCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}
