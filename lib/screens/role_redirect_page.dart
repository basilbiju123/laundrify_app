import 'package:flutter/material.dart';
import '../services/role_based_auth_service.dart'
    show RoleBasedAuthService, isHardcodedAdmin, kAdminAllRoutes;
import 'dashboard.dart';
import 'admin_switcher.dart';
import 'manager_dashboard.dart';
import 'delivery_dashboard.dart';
import 'employee_dashboard.dart';
import 'location_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Shown after login (or on app resume with saved session) to route the user.
///
/// Flow:
///   Super-admin emails  → AdminDashboardPickerPage (choose any of 5)
///   Firestore admin     → AdminDashboardPickerPage (choose any of 5)
///   Role = manager      → ManagerDashboard
///   Role = delivery     → DeliveryDashboard
///   Role = staff        → EmployeeDashboard
///   Role = user (no loc)→ LocationPage → DashboardPage
///   Role = user (loc ✓) → DashboardPage
class RoleRedirectPage extends StatefulWidget {
  const RoleRedirectPage({super.key});

  @override
  State<RoleRedirectPage> createState() => _RoleRedirectPageState();
}

class _RoleRedirectPageState extends State<RoleRedirectPage> {
  final RoleBasedAuthService _roleService = RoleBasedAuthService();

  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/auth');
      return;
    }

    // ── Super-admin email bypass ────────────────────────────────────
    if (isHardcodedAdmin(user.email)) {
      _showAdminPicker(user, List<String>.from(kAdminAllRoutes));
      return;
    }

    final route = await _roleService.getDashboardRoute();
    final accessibleRoutes = await _roleService.getUserAccessibleRoles();
    if (!mounted) return;

    if (route == '/admin-dashboard') {
      _showAdminPicker(user, accessibleRoutes);
      return;
    }
    if (route == '/manager-dashboard') {
      _push(const ManagerDashboard());
      return;
    }
    if (route == '/delivery-dashboard') {
      _push(const DeliveryDashboard());
      return;
    }
    if (route == '/employee-dashboard') {
      _push(const EmployeeDashboard());
      return;
    }
    await _routeUser(user);
  }

  Future<void> _routeUser(User user) async {
    bool hasLocation = false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      hasLocation = data != null &&
          data['location'] != null &&
          data['location']['latitude'] != null;
    } catch (_) {}

    if (!mounted) return;
    _push(hasLocation ? const DashboardPage() : const LocationPage());
  }

  void _showAdminPicker(User user, List<String> routes) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _AdminPickerPage(
          accessibleRoutes: routes,
          userEmail: user.email ?? '',
          userName: user.displayName ?? '',
          userPhoto: user.photoURL,
          onPicked: _navigateToRoute,
        ),
      ),
    );
  }

  Future<void> _navigateToRoute(String route) async {
    if (!mounted) return;
    if (route == '/dashboard') {
      final user = FirebaseAuth.instance.currentUser;
      bool hasLocation = false;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final data = doc.data();
          hasLocation = data != null &&
              data['location'] != null &&
              data['location']['latitude'] != null;
        } catch (_) {}
      }
      if (!mounted) return;
      _push(hasLocation ? const DashboardPage() : const LocationPage());
      return;
    }
    switch (route) {
      case '/admin-dashboard':
        _push(const AdminSwitcherWrapper());
        break;
      case '/manager-dashboard':
        _push(const ManagerDashboard());
        break;
      case '/delivery-dashboard':
        _push(const DeliveryDashboard());
        break;
      case '/employee-dashboard':
        _push(const EmployeeDashboard());
        break;
      default:
        _push(const DashboardPage());
    }
  }

  void _push(Widget page) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF080F1E),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF5C518),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

// ── Inline admin picker (same design as auth_options_page version) ──────────
class _AdminPickerPage extends StatefulWidget {
  final List<String> accessibleRoutes;
  final String userEmail;
  final String userName;
  final String? userPhoto;
  final Future<void> Function(String route) onPicked;

  const _AdminPickerPage({
    required this.accessibleRoutes,
    required this.userEmail,
    required this.userName,
    this.userPhoto,
    required this.onPicked,
  });

  @override
  State<_AdminPickerPage> createState() => _AdminPickerPageState();
}

class _AdminPickerPageState extends State<_AdminPickerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int? _hovered;
  bool _loading = false;

  static const _navy  = Color(0xFF080F1E);
  static const _navyM = Color(0xFF0D1A2E);
  static const _navyC = Color(0xFF111F35);
  static const _navyB = Color(0xFF1C2F4A);
  static const _gold  = Color(0xFFF5C518);
  static const _goldS = Color(0xFFFDE68A);
  static const _textHi = Color(0xFFF1F5F9);
  static const _textMd = Color(0xFF94A3B8);

  static const _all = [
    _D('/admin-dashboard',    'Admin Panel',     'Full control — users, orders, analytics, employees', Icons.admin_panel_settings_rounded, Color(0xFFF5C518), Color(0xFFFFB300)),
    _D('/manager-dashboard',  'Manager',         'Branch management — staff, orders, revenue',          Icons.manage_accounts_rounded,      Color(0xFF4FC3F7), Color(0xFF0288D1)),
    _D('/delivery-dashboard', 'Delivery',        'Driver view — live map, pickups, earnings',            Icons.delivery_dining_rounded,      Color(0xFF81C784), Color(0xFF2E7D32)),
    _D('/employee-dashboard', 'Employee',        'Staff view — laundry tasks, queue, schedule',          Icons.badge_rounded,                Color(0xFFCE93D8), Color(0xFF7B1FA2)),
    _D('/dashboard',          'User / Customer', 'Customer app — book orders, track, profile',           Icons.person_rounded,               Color(0xFFFF8A65), Color(0xFFE64A19)),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  List<_D> get _available =>
      _all.where((d) => widget.accessibleRoutes.contains(d.route)).toList();

  Future<void> _pick(_D d) async {
    if (_loading) return;
    setState(() => _loading = true);
    await widget.onPicked(d.route);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: _navy,
      body: Stack(children: [
        Positioned.fill(child: Container(
          decoration: const BoxDecoration(gradient: RadialGradient(
            center: Alignment(0, -0.4), radius: 1.2,
            colors: [Color(0xFF0E2147), _navy],
          )),
        )),
        if (_loading)
          const Positioned.fill(child: Center(
            child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
          ))
        else
          SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_gold, _goldS]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shield_rounded, color: _navy, size: 14),
                    SizedBox(width: 7),
                    Text('SUPER ADMIN ACCESS', style: TextStyle(color: _navy, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (widget.userPhoto != null)
                    CircleAvatar(radius: 26, backgroundImage: NetworkImage(widget.userPhoto!), backgroundColor: _navyB)
                  else
                    Container(
                      width: 52, height: 52,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_gold, _goldS])),
                      child: const Icon(Icons.person, color: _navy, size: 28),
                    ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.userName.isNotEmpty ? widget.userName : 'Admin',
                        style: const TextStyle(color: _textHi, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(widget.userEmail, style: const TextStyle(color: _textMd, fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 20),
                const Text('Choose a Dashboard', style: TextStyle(color: _textHi, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                const Text('Tap any dashboard to enter', style: TextStyle(color: _textMd, fontSize: 13)),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              height: 1,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [
                Colors.transparent, _gold.withValues(alpha: 0.4), Colors.transparent,
              ])),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: wide ? _grid() : _list(),
              ),
            ),
          ])),
      ]),
    );
  }

  Widget _grid() => GridView.builder(
    padding: const EdgeInsets.only(bottom: 24),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.7),
    itemCount: _available.length,
    itemBuilder: (_, i) => _card(_available[i], i),
  );

  Widget _list() => ListView.separated(
    padding: const EdgeInsets.only(bottom: 24),
    itemCount: _available.length,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, i) => _card(_available[i], i),
  );

  Widget _card(_D d, int i) {
    final delay = i * 0.10;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = ((_ctrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final c = Curves.easeOutCubic.transform(t);
        return Opacity(opacity: c, child: Transform.translate(offset: Offset(0, 26 * (1 - c)), child: child));
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = i),
        onExit:  (_) => setState(() => _hovered = null),
        child: GestureDetector(
          onTap: () => _pick(d),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: _hovered == i ? _navyC : _navyM,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hovered == i ? d.g1.withValues(alpha: 0.6) : _navyB,
                width: _hovered == i ? 1.5 : 1,
              ),
              boxShadow: _hovered == i ? [BoxShadow(color: d.g1.withValues(alpha: 0.22), blurRadius: 20, offset: const Offset(0, 6))] : [],
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [d.g1, d.g2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: d.g1.withValues(alpha: 0.38), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Icon(d.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.label, style: const TextStyle(color: _textHi, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(d.sub, style: const TextStyle(color: _textMd, fontSize: 11, height: 1.3)),
              ])),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: _textMd.withValues(alpha: 0.45), size: 14),
            ]),
          ),
        ),
      ),
    );
  }
}

class _D {
  final String route, label, sub;
  final IconData icon;
  final Color g1, g2;
  const _D(this.route, this.label, this.sub, this.icon, this.g1, this.g2);
}
