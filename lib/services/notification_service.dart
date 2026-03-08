import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../main.dart' show navigatorKey;
import '../screens/track_order_page.dart';
import '../screens/notifications_page.dart';

import 'notification_service_mobile.dart'
    if (dart.library.html) 'notification_service_web_stub.dart';

// ─── Background handler (registered before app is fully init) ────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _oneSignalAppId =
      '92ab5f14-7803-43d2-b8b8-47a11527a89a';
  static const _oneSignalRestKey =
      'os_v2_app_skvv6fdyanb5fofyi6qrkj5itj3cx66rowaudiuhmf24jrvmzebfezsaqbc4qcikgnsh5yhy3fib5jbir35u3z45yynr4y6nq4akglq';

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _fcmToken;
  String? _oneSignalPlayerId;
  String? get fcmToken => _fcmToken;

  // ── Main initialise (call once from main.dart after Firebase.initializeApp) ─
  Future<void> initialize() async {
    await _requestPermissions();
    if (!kIsWeb) {
      await initLocalNotifications();
    }
    await _getFCMToken();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _setupForegroundHandler();
    _setupTapHandler();
    _fcm.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveFCMToken(newToken);
      if (!kIsWeb) _registerWithOneSignal(newToken);
    });

    // Restart Firestore listener whenever auth state changes (login/logout)
    // This ensures the listener always uses the correct uid
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // User logged in — restart listener with their uid
        _shownIds.clear();
        _listenerReady = false;
        _firestoreSub?.cancel();
        _watchFirestoreNotifications();
      } else {
        // User logged out — stop listener
        _firestoreSub?.cancel();
        _firestoreSub = null;
        _shownIds.clear();
        _listenerReady = false;
      }
    });
  }

  // ── Permissions ──────────────────────────────────────────────────────────
  Future<void> _requestPermissions() async {
    await _fcm.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    if (!kIsWeb) await requestMobileNotificationPermission();
  }

  // ── Get + save FCM token ─────────────────────────────────────────────────
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = kIsWeb ? null : await _fcm.getToken();
      if (_fcmToken == null) return;
      await _saveFCMToken(_fcmToken!);
      if (!kIsWeb) await _registerWithOneSignal(_fcmToken!);
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  Future<void> _saveFCMToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // Try each collection — employees are NOT in /users
    for (final col in ['delivery_agents', 'managers', 'staff', 'users']) {
      try {
        final doc = await _db.collection(col).doc(uid).get();
        if (doc.exists) {
          await _db.collection(col).doc(uid).update({
            'fcmToken': token,
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }
      } catch (_) {}
    }
  }

  // ── Register device with OneSignal (no SDK needed) ───────────────────────
  // OneSignal /v1/players accepts FCM token as the device identifier.
  // This is how OneSignal knows which device to push to.
  Future<void> _registerWithOneSignal(String fcmToken) async {
    final uid = _auth.currentUser?.uid;
    try {
      // Get user role + existing OneSignal player ID from correct collection
      String role = 'user';
      String? existingId = _oneSignalPlayerId;
      if (uid != null) {
        for (final col in ['delivery_agents', 'managers', 'staff', 'users']) {
          try {
            final doc = await _db.collection(col).doc(uid).get();
            if (doc.exists) {
              role = doc.data()?['role'] as String? ?? 'user';
              existingId ??= doc.data()?['oneSignalPlayerId'] as String?;
              break;
            }
          } catch (_) {}
        }
      }

      final body = <String, dynamic>{
        'app_id': _oneSignalAppId,
        'device_type': 1, // 1 = Android (FCM)
        'identifier': fcmToken,
        'tags': {'role': role, 'userId': uid ?? ''},
        'external_user_id': uid ?? '',
      };

      http.Response response;
      if (existingId != null && existingId.isNotEmpty) {
        // Update existing player
        response = await http.put(
          Uri.parse('https://onesignal.com/api/v1/players/$existingId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else {
        // Create new player
        response = await http.post(
          Uri.parse('https://onesignal.com/api/v1/players'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final playerId = data['id'] as String?;
        if (playerId != null && playerId.isNotEmpty) {
          _oneSignalPlayerId = playerId;
          // Save player ID to Firestore for server-side targeting
          if (uid != null) {
            // Save to whichever collection this user belongs to
            for (final col in ['delivery_agents', 'managers', 'staff', 'users']) {
              try {
                final doc = await _db.collection(col).doc(uid).get();
                if (doc.exists) {
                  await _db.collection(col).doc(uid).update({
                    'oneSignalPlayerId': playerId,
                  });
                  break;
                }
              } catch (_) {}
            }
          }
          debugPrint('OneSignal registered: $playerId');
        }
      } else {
        debugPrint('OneSignal registration: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('OneSignal registration error (non-fatal): $e');
    }
  }

  // ── Foreground message handling ───────────────────────────────────────────
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        if (kIsWeb) {
          _showInAppBanner(
            title: message.notification!.title ?? 'Laundrify',
            body: message.notification!.body ?? '',
            data: message.data,
          );
        } else {
          showMobileNotification(message);
        }
      }
    });
    _watchFirestoreNotifications();
  }

  // ── Tap handler (notification opens app) ─────────────────────────────────
  void _setupTapHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    _fcm.getInitialMessage().then((m) { if (m != null) _handleTap(m); });
  }

  void _handleTap(RemoteMessage m) => _navigateFromData(m.data);

  // ── In-app banner (foreground) ────────────────────────────────────────────
  static int _notifIdCounter = 0;

  void _showInAppBanner({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) {
    // Fire local (lock-screen) notification — works without FCM/OneSignal
    if (!kIsWeb) {
      final id = (_notifIdCounter++ % 2147483647);
      showDirectNotification(title: title, body: body, id: id)
          .catchError((_) {});
    }
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0D1B35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 5),
      content: Row(children: [
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
      ]),
      action: SnackBarAction(
        label: 'View',
        textColor: const Color(0xFFF5C518),
        onPressed: () => _navigateFromData(data),
      ),
    ));
  }

  // ── Firestore real-time listener (in-app notifications) ───────────────────
  StreamSubscription<QuerySnapshot>? _firestoreSub;
  final Set<String> _shownIds = {};
  bool _listenerReady = false;

  void _watchFirestoreNotifications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _firestoreSub?.cancel();
    _listenerReady = false;

    // 1. Personal notifications (userId == uid) — order updates, role changes
    _firestoreSub = _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) => _processNotifSnap(snap));

    // 2. Broadcast to all users
    _db.collection('notifications')
        .where('targetGroup', whereIn: ['all', 'users'])
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snap) => _processNotifSnap(snap));

    // 3. Role-specific broadcasts (delivery, managers, staff)
    // Determine current user's role and subscribe to matching group
    _subscribeToRoleNotifications(uid);

    // Small delay then mark ready — lets streams seed existing IDs first
    Future.delayed(const Duration(milliseconds: 800), () {
      _listenerReady = true;
    });
  }

  Future<void> _subscribeToRoleNotifications(String uid) async {
    try {
      // Find which role collection this user belongs to
      String? roleGroup;
      for (final entry in {
        'delivery': 'delivery_agents',
        'manager': 'managers',
        'staff': 'staff',
      }.entries) {
        final doc = await _db.collection(entry.value).doc(uid).get();
        if (doc.exists) { roleGroup = entry.key; break; }
      }
      // Also check /users for role field
      if (roleGroup == null) {
        final userDoc = await _db.collection('users').doc(uid).get();
        final role = userDoc.data()?['role'] as String?;
        if (role != null && role != 'user') roleGroup = role;
      }
      if (roleGroup == null) return;

      // Listen for notifications targeting this role group
      _db.collection('notifications')
          .where('targetGroup', isEqualTo: roleGroup)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .listen((snap) => _processNotifSnap(snap));
    } catch (_) {}
  }

  void _processNotifSnap(QuerySnapshot snap) {
    if (!_listenerReady) {
      // Seed existing IDs so we don't show old notifications as banners
      for (final doc in snap.docs) { _shownIds.add(doc.id); }
      return;
    }
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      if (_shownIds.contains(change.doc.id)) continue;
      _shownIds.add(change.doc.id);
      final d = change.doc.data() as Map<String, dynamic>?;
      if (d == null || d['isRead'] == true) continue;
      _showInAppBanner(
        title: d['title'] as String? ?? 'Laundrify',
        body: d['message'] as String? ?? d['body'] as String? ?? '',
        data: {
          'type': d['type'] ?? '',
          'orderId': d['orderId'] ?? '',
        },
      );
    }
  }

  // ── Navigate from notification data ──────────────────────────────────────
  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final orderId = data['orderId'] as String?;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    if (type == 'order_update' && orderId != null && orderId.isNotEmpty) {
      nav.push(MaterialPageRoute(
          builder: (_) => TrackOrderPage(orderId: orderId)));
    } else {
      nav.push(MaterialPageRoute(
          builder: (_) => const NotificationsPage()));
    }
  }

  // ── Static send methods (called from admin/order pages) ──────────────────

  /// Broadcast to a segment or role tag
  static Future<bool> sendPushToSegment({
    required String title,
    required String message,
    required String targetGroup, // 'all' | 'users' | 'delivery' | 'managers' | 'staff'
    Map<String, String> data = const {},
  }) async {
    try {
      final body = <String, dynamic>{
        'app_id': _oneSignalAppId,
        'headings': {'en': title},
        'contents': {'en': message},
        'data': data,
      };

      if (targetGroup == 'all') {
        body['included_segments'] = ['Subscribed Users'];
      } else {
        final roleTag = const {
          'users': 'user',
          'delivery': 'delivery',
          'managers': 'manager',
          'staff': 'staff',
        }[targetGroup] ?? targetGroup;
        body['filters'] = [
          {'field': 'tag', 'key': 'role', 'relation': '=', 'value': roleTag}
        ];
      }

      final res = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_oneSignalRestKey',
        },
        body: jsonEncode(body),
      );
      debugPrint('OneSignal segment push: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('OneSignal segment push error: $e');
      return false;
    }
  }

  /// Push to a specific user by their OneSignal player ID (stored in Firestore)
  static Future<bool> sendPushToUser({
    required String userId,
    required String title,
    required String message,
    Map<String, String> data = const {},
  }) async {
    try {
      // Look up the user's OneSignal player ID — check all collections
      String? playerId;
      for (final col in ['delivery_agents', 'managers', 'staff', 'users']) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection(col)
              .doc(userId)
              .get();
          if (doc.exists) {
            playerId = doc.data()?['oneSignalPlayerId'] as String?;
            break;
          }
        } catch (_) {}
      }

      if (playerId == null || playerId.isEmpty) {
        debugPrint('No OneSignal player ID for user $userId — skipping push');
        return false;
      }

      final res = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_oneSignalRestKey',
        },
        body: jsonEncode({
          'app_id': _oneSignalAppId,
          'include_player_ids': [playerId],
          'headings': {'en': title},
          'contents': {'en': message},
          'data': data,
        }),
      );
      debugPrint('OneSignal user push: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('OneSignal user push error: $e');
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<void> subscribeToTopic(String t) => _fcm.subscribeToTopic(t);
  Future<void> unsubscribeFromTopic(String t) => _fcm.unsubscribeFromTopic(t);

  Future<void> deleteToken() async {
    await _fcm.deleteToken();
    _fcmToken = null;
    _oneSignalPlayerId = null;
  }

  Future<int> getBadgeCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final snap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearAllNotifications() async {
    if (!kIsWeb) await clearMobileNotifications();
  }
  // ── Direct local notification convenience methods ────────────────────────
  // These fire instantly on the device — no FCM, no internet, perfect for demos.

  Future<void> showOrderNotification({
    required String title,
    required String body,
    String? orderId,
  }) async {
    _showInAppBanner(
      title: title,
      body: body,
      data: {'type': 'order_update', 'orderId': orderId ?? ''},
    );
  }

  Future<void> showRoleNotification({
    required String name,
    required String newRole,
  }) async {
    _showInAppBanner(
      title: '🔄 Role Updated',
      body: 'Hi $name, your role is now ${newRole.toUpperCase()}. Re-login to access your dashboard.',
      data: {'type': 'role_change'},
    );
  }

  Future<void> showDeliveryNotification({
    required String title,
    required String body,
    String? orderId,
  }) async {
    _showInAppBanner(
      title: title,
      body: body,
      data: {'type': 'order_update', 'orderId': orderId ?? ''},
    );
  }


  // ── Notification opt-in / opt-out (syncs with OneSignal) ─────────────────
  static Future<void> optInToNotifications() async {
    // OneSignal opt-in: handled via native platform channel in notification_service_mobile.dart
    // No-op here — push notifications remain active unless user revokes OS permission
  }

  static Future<void> optOutOfNotifications() async {
    // OneSignal opt-out: best effort — user can revoke permission in device settings
    // No-op here to avoid importing onesignal_flutter in this file
  }


}
