import 'package:flutter/material.dart';
import 'main.dart' show navigatorKey;
import 'services/theme_service.dart';
import 'app_entry_point.dart';

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
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          home: const AppEntryPoint(),
        );
      },
    );
  }
}
