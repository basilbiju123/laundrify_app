import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_entry_point.dart';

class LaundrifyApp extends StatefulWidget {
  const LaundrifyApp({super.key});

  @override
  State<LaundrifyApp> createState() => _LaundrifyAppState();
}

class _LaundrifyAppState extends State<LaundrifyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laundrify',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1B4FD8),
        scaffoldBackgroundColor: const Color(0xFFF0F4FF),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1B4FD8),
          secondary: Color(0xFFF5C518),
          surface: Colors.white,
          error: Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF080F1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      
      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF3B82F6),
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFFFDE68A),
          surface: Color(0xFF111827),
          error: Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF080F1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),

      home: const AppEntryPoint(),
    );
  }
}
