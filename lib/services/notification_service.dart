import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show navigatorKey;
import '../screens/track_order_page.dart';
import '../screens/notifications_page.dart';

// Only import mobile-only packages when NOT on web
import 'notification_service_mobile.dart'
    if (dart.library.html) 'notification_service_web_stub.dart';

// Top-level background handler (mobile/desktop only)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    await _requestPermissions();
    if (!kIsWeb) {
      await initLocalNotifications(); // mobile only
    }
    await _getFCMToken();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _setupForegroundHandler();
    _setupTapHandler();
    _fcm.onTokenRefresh.listen((t) {
      _fcmToken = t;
      _saveFCMToken(t);
    });
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');
    if (!kIsWeb) {
      await requestMobileNotificationPermission(); // permission_handler (mobile only)
    }
  }

  Future<void> _getFCMToken() async {
    try {
      // Web FCM requires VAPID key — set vapidKey if you have one
      _fcmToken = kIsWeb
          ? await _fcm.getToken(
              vapidKey: 'YOUR_VAPID_KEY_HERE', // replace with your VAPID key from Firebase console
            )
          : await _fcm.getToken();
      debugPrint('FCM Token: $_fcmToken');
      if (_fcmToken != null) await _saveFCMToken(_fcmToken!);
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _saveFCMToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      await _subscribeToRoleTopics(uid);
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> _subscribeToRoleTopics(String uid) async {
    try {
      await _fcm.subscribeToTopic('all_users');
      final doc = await _db.collection('users').doc(uid).get();
      final role = doc.data()?['role'] as String? ?? 'customer';
      switch (role) {
        case 'customer': await _fcm.subscribeToTopic('customers'); break;
        case 'delivery': await _fcm.subscribeToTopic('delivery_agents'); break;
        case 'manager': await _fcm.subscribeToTopic('managers'); break;
        case 'admin': await _fcm.subscribeToTopic('admins'); break;
      }
    } catch (e) {
      debugPrint('Error subscribing to topics: $e');
    }
  }

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        if (kIsWeb) {
          // Web: FCM handles notifications natively via service worker
          debugPrint('Web foreground notification: ${message.notification?.title}');
        } else {
          showMobileNotification(message); // mobile only
        }
      }
    });
  }

  void _setupTapHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    _fcm.getInitialMessage().then((m) { if (m != null) _handleTap(m); });
  }

  void _handleTap(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final orderId = data['orderId'] as String?;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    if (type == 'order_update' && orderId != null && orderId.isNotEmpty) {
      nav.push(MaterialPageRoute(builder: (_) => TrackOrderPage(orderId: orderId)));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    }
  }

  Future<void> subscribeToTopic(String topic) => _fcm.subscribeToTopic(topic);
  Future<void> unsubscribeFromTopic(String topic) => _fcm.unsubscribeFromTopic(topic);
  Future<void> deleteToken() async { await _fcm.deleteToken(); _fcmToken = null; }

  Future<void> unsubscribeAllTopics() async {
    for (final t in ['all_users','customers','delivery_agents','managers','admins']) {
      await _fcm.unsubscribeFromTopic(t);
    }
  }

  Future<int> getBadgeCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final snap = await _db.collection('users').doc(uid)
          .collection('notifications').where('isRead', isEqualTo: false).count().get();
      return snap.count ?? 0;
    } catch (_) { return 0; }
  }

  Future<void> clearAllNotifications() async {
    if (!kIsWeb) await clearMobileNotifications();
  }
}
