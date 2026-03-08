import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

final _localNotifications = FlutterLocalNotificationsPlugin();

Future<void> initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await _localNotifications.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );
  const channel = AndroidNotificationChannel(
    'laundrify_notifications', 'Laundrify Notifications',
    description: 'Order updates and account activities',
    importance: Importance.high, playSound: true, enableVibration: true,
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> requestMobileNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> showMobileNotification(RemoteMessage message) async {
  final n = message.notification;
  if (n == null) return;
  final androidDetails = AndroidNotificationDetails(
    'laundrify_notifications', 'Laundrify Notifications',
    channelDescription: 'Order updates',
    importance: Importance.high, priority: Priority.high,
    playSound: true, enableVibration: true, icon: '@mipmap/ic_launcher',
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true, presentBadge: true, presentSound: true,
  );
  await _localNotifications.show(
    n.hashCode, n.title, n.body,
    NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: json.encode(message.data),
  );
}

Future<void> clearMobileNotifications() => _localNotifications.cancelAll();

/// Shows a local notification directly — no FCM/OneSignal needed.
/// Call this anywhere in the app for instant demo-ready notifications.
Future<void> showDirectNotification({
  required String title,
  required String body,
  String? payload,
  int id = 0,
}) async {
  final androidDetails = AndroidNotificationDetails(
    'laundrify_notifications', 'Laundrify Notifications',
    channelDescription: 'Order updates',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    ticker: title,
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  await _localNotifications.show(
    id,
    title,
    body,
    NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: payload,
  );
}
