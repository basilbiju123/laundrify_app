import 'dart:async';
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
      if (kIsWeb) {
        // ── WEB: Requires VAPID key from Firebase Console ──────────────
        // 1. Go to Firebase Console → Project Settings → Cloud Messaging
        // 2. Scroll to "Web Push certificates" → Generate key pair
        // 3. Copy the "Key pair" value and paste it below as vapidKey
        // Until the key is set, push notifications are disabled on web
        //    but the app will still work normally.
        const vapidKey = 'YOUR_VAPID_KEY_HERE'; // ← paste your key here
        if (vapidKey == 'YOUR_VAPID_KEY_HERE') {
          debugPrint('FCM Web: VAPID key not configured. Push notifications disabled on web.');
          debugPrint('To fix: Firebase Console → Project Settings → Cloud Messaging → Web Push certificates');
          return; // Skip — no crash, app works fine without it
        }
        _fcmToken = await _fcm.getToken(vapidKey: vapidKey);
      } else {
        _fcmToken = await _fcm.getToken();
      }
      if (_fcmToken == null) {
        debugPrint('FCM Token: null — push notifications will not work for this session. '
            'Check Firebase project settings and device connectivity.');
        return;
      }
      debugPrint('FCM Token: $_fcmToken');
      await _saveFCMToken(_fcmToken!);
    } catch (e) {
      debugPrint('FCM token error (non-fatal): \$e');
      // App continues normally without push token
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
          _showWebInAppBanner(
            title: message.notification!.title ?? 'Laundrify',
            body: message.notification!.body ?? '',
            data: message.data,
          );
        } else {
          showMobileNotification(message); // mobile only
        }
      }
    });
    // Watch Firestore for new notifications (works even without VAPID key)
    _watchFirestoreNotifications();
  }

  void _showWebInAppBanner({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF080F1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5C518).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_rounded,
                  color: Color(0xFFF5C518), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                  if (body.isNotEmpty)
                    Text(body,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: const Color(0xFFF5C518),
          onPressed: () => _navigateFromData(data),
        ),
      ),
    );
  }

  StreamSubscription<QuerySnapshot>? _firestoreNotifSub;
  // Track notification IDs already shown this session to prevent flash/repeat
  final Set<String> _shownNotifIds = {};
  bool _firestoreListenerInitialized = false;

  void _watchFirestoreNotifications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _firestoreNotifSub?.cancel();
    _firestoreListenerInitialized = false;
    _firestoreNotifSub = _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        // No composite filter — avoids requiring a Firestore index.
        // We order by createdAt only and filter unread client-side.
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snap) {
      // Skip the very first snapshot (existing notifications on subscribe)
      // to avoid flashing old notifications on app start / re-login
      if (!_firestoreListenerInitialized) {
        _firestoreListenerInitialized = true;
        // Seed the shown-set with all current doc IDs so they're suppressed
        for (final doc in snap.docs) {
          _shownNotifIds.add(doc.id);
        }
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          // Skip if we already showed this notification
          if (_shownNotifIds.contains(change.doc.id)) continue;
          _shownNotifIds.add(change.doc.id);
          final d = change.doc.data();
          if (d == null) continue;
          // Client-side unread filter (avoids composite Firestore index)
          if (d['isRead'] == true) continue;
          if (kIsWeb) {
            _showWebInAppBanner(
              title: d['title'] as String? ?? 'Laundrify',
              body: d['body'] as String? ?? '',
              data: {'type': d['type'], 'orderId': d['orderId']},
            );
          } else {
            // Mobile: also show local notification for Firestore-triggered ones
            // (FCM may not deliver foreground notifications on all devices)
            _showMobileLocalBannerFromData(d);
          }
        }
      }
    });
  }

  /// Shows a local notification on mobile for Firestore-triggered alerts.
  void _showMobileLocalBannerFromData(Map<String, dynamic> d) {
    if (kIsWeb) return;
    // Reconstruct a minimal RemoteMessage-like call via showMobileNotification
    // is not possible without firebase_messaging RemoteMessage; use the
    // platform channel indirectly by calling showMobileNotification with a
    // synthetic message via the mobile stub's show API.
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF080F1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5C518).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_rounded,
                  color: Color(0xFFF5C518), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d['title'] as String? ?? 'Laundrify',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                  if ((d['body'] as String? ?? '').isNotEmpty)
                    Text(d['body'] as String,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: const Color(0xFFF5C518),
          onPressed: () => _navigateFromData(
              {'type': d['type'], 'orderId': d['orderId']}),
        ),
      ),
    );
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
      // Fetch all and count client-side — avoids requiring a composite index
      final snap = await _db.collection('users').doc(uid)
          .collection('notifications').get();
      return snap.docs.where((d) => d.data()['isRead'] != true).length;
    } catch (_) { return 0; }
  }

  Future<void> clearAllNotifications() async {
    if (!kIsWeb) await clearMobileNotifications();
  }
}
