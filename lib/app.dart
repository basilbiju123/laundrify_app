import 'package:flutter/material.dart';
import 'main.dart' show navigatorKey;
import 'services/theme_service.dart';
import 'app_entry_point.dart';
import 'theme/app_theme.dart';
import 'screens/role_redirect_page.dart';
import 'screens/auth_options_page.dart';

class LaundrifyApp extends StatelessWidget {
  const LaundrifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Laundrify',
          navigatorKey: navigatorKey,
          themeMode: themeService.themeMode,
          theme: AppThemeData.light(),
          darkTheme: AppThemeData.dark(),
          home: const AppEntryPoint(),
          routes: {
            '/auth': (_) => const AuthOptionsPage(),
            '/role-redirect': (_) => const RoleRedirectPage(),
          },
        );
      },
    );
  }
}
