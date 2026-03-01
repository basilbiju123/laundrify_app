import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/theme_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

/// Global navigator key — used by NotificationService to navigate
/// when user taps a push notification from background/terminated state.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load saved theme preference before the app renders
  await ThemeService().loadTheme();

  // Initialize push notifications (FCM + local notifications for mobile, FCM only for web)
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Notification init error (non-fatal): $e');
  }

  runApp(const LaundrifyApp());
}
