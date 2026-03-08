import 'package:firebase_messaging/firebase_messaging.dart';

// Web stubs — notification_service_mobile functions are not available on web.
// Firebase service worker handles push notifications on web.

Future<void> initLocalNotifications() async {}
Future<void> requestMobileNotificationPermission() async {}
Future<void> showMobileNotification(RemoteMessage message) async {}
Future<void> clearMobileNotifications() async {}
Future<void> showDirectNotification({
  required String title,
  required String body,
  String? payload,
  int id = 0,
}) async {}
