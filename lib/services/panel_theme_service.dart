import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_service.dart';

// ═══════════════════════════════════════════════════════════════════
// PANEL THEME SERVICE
// Provides isolated dark-mode state per dashboard panel.
// Each panel (user, admin, manager, delivery, employee) stores its
// own preference under a unique SharedPreferences key so toggling
// dark mode in one panel never affects any other.
//
// Panel keys:
//   'user'     → User / customer dashboard
//   'admin'    → Admin dashboard
//   'manager'  → Manager dashboard
//   'delivery' → Delivery dashboard
//   'employee' → Employee / staff dashboard
// ═══════════════════════════════════════════════════════════════════

class PanelThemeService extends ChangeNotifier {
  final String panelKey;

  bool _isDark = false;
  bool get isDark => _isDark;

  // Cache shared with PanelThemeScope so the same instance is used everywhere
  static final Map<String, PanelThemeService> _cache = {};

  /// Get (or create) the shared instance for a given panel key.
  /// Use this when you need the service outside of a PanelThemeScope subtree.
  static PanelThemeService forKey(String key) =>
      _cache.putIfAbsent(key, () => PanelThemeService._(key));

  PanelThemeService(this.panelKey) {
    _load();
  }

  PanelThemeService._(this.panelKey) {
    _load();
  }

  String get _prefKey => 'panel_dark_$panelKey';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefKey) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  Future<void> toggle() => setDark(!_isDark);
}

// ═══════════════════════════════════════════════════════════════════
// PANEL THEME SCOPE
// Wrap each dashboard's root widget with this.
// It provides its own Theme (light or dark) isolated from the global
// MaterialApp theme, so dark mode only affects its subtree.
//
// Usage:
//   PanelThemeScope(
//     panelKey: 'admin',
//     child: AdminDashboard(),
//   )
// ═══════════════════════════════════════════════════════════════════

class PanelThemeScope extends StatefulWidget {
  final String panelKey;
  final Widget child;

  const PanelThemeScope({
    super.key,
    required this.panelKey,
    required this.child,
  });

  @override
  State<PanelThemeScope> createState() => _PanelThemeScopeState();

  /// Retrieve the nearest PanelThemeService from context.
  static PanelThemeService of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PanelThemeInherited>()!
        .service;
  }

  /// Retrieve without subscribing (for one-time reads).
  static PanelThemeService read(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_PanelThemeInherited>()!
        .service;
  }
}

class _PanelThemeScopeState extends State<PanelThemeScope> {
  late PanelThemeService _service;

  @override
  void initState() {
    super.initState();
    _service = PanelThemeService.forKey(widget.panelKey);
    _service.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final themeData =
        _service.isDark ? ThemeService.darkTheme : ThemeService.lightTheme;

    return _PanelThemeInherited(
      service: _service,
      child: Theme(
        data: themeData,
        child: widget.child,
      ),
    );
  }
}

class _PanelThemeInherited extends InheritedWidget {
  final PanelThemeService service;

  const _PanelThemeInherited({
    required this.service,
    required super.child,
  });

  @override
  bool updateShouldNotify(_PanelThemeInherited old) =>
      old.service != service || old.service.isDark != service.isDark;
}
