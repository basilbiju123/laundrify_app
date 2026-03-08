import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'location_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'dashboard.dart';
import 'admin_switcher.dart';
import 'manager_dashboard.dart';
import 'delivery_dashboard.dart';
import 'employee_dashboard.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class AuthOptionsPage extends StatefulWidget {
  const AuthOptionsPage({super.key});

  @override
  State<AuthOptionsPage> createState() => _AuthOptionsPageState();
}

class _AuthOptionsPageState extends State<AuthOptionsPage>
    with TickerProviderStateMixin {
  bool isLoading = false;
  late AnimationController _animationController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  final AuthService _authService = AuthService();

  /// Returns true if running on a desktop platform (Windows, macOS, Linux)
  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  Future<void> googleSignIn() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      Map<String, dynamic> result;

      if (kIsWeb) {
        // ── Web (Chrome/browser): Firebase signInWithPopup — no clientId meta tag needed ──
        result = await _authService.signInWithGoogleWeb();
      } else if (_isDesktop) {
        // ── Desktop (Windows/macOS/Linux): Firebase signInWithProvider ──
        result = await _authService.signInWithGoogleDesktop();
      } else {
        // ── Mobile (Android / iOS): standard GoogleSignIn package ──
        result = await _authService.signInWithGoogle();
      }

      if (!mounted) return;

      if (result['success'] == true) {
        final accessibleRoles = (result['accessibleRoles'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [result['route'] as String? ?? '/dashboard'];

        if (result['hasMultipleRoles'] == true && accessibleRoles.length > 1) {
          // ── Admin / multi-role: show the beautiful dashboard picker ────
          if (!mounted) return;
          final selectedRoute = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) => _AdminDashboardPickerPage(
                accessibleRoutes: accessibleRoles,
                userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                userName: FirebaseAuth.instance.currentUser?.displayName ?? '',
                userPhoto: FirebaseAuth.instance.currentUser?.photoURL,
              ),
            ),
          );
          if (selectedRoute != null && mounted) {
            _navigateToRoute(selectedRoute);
          }
        } else {
          // ── Single role — direct routing ────────────────────────────
          final route = result['route'] as String? ?? '/dashboard';
          if (!mounted) return;
          _navigateToRoute(route);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? "Google sign-in failed"),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Google sign-in failed"),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Central navigation helper.
  /// - /dashboard (user role) → check location → LocationPage or Dashboard
  /// - any other role → go directly to that dashboard
  Future<void> _navigateToRoute(String route) async {
    if (!mounted) return;

    if (route == '/dashboard') {
      // Check if user has already saved a location
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
      if (!hasLocation) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
        );
      } else {
        _navigateToDashboard(route);
      }
      return;
    }
    _navigateToDashboard(route);
  }

  void _navigateToDashboard(String route) {
    Widget dashboardWidget;
    switch (route) {
      case '/admin-dashboard':
        dashboardWidget = const AdminSwitcherWrapper();
        break;
      case '/manager-dashboard':
        dashboardWidget = const ManagerDashboard();
        break;
      case '/delivery-dashboard':
        dashboardWidget = const DeliveryDashboard();
        break;
      case '/employee-dashboard':
        dashboardWidget = const EmployeeDashboard();
        break;
      case '/dashboard':
      default:
        dashboardWidget = const DashboardPage();
        break;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dashboardWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600; // desktop / tablet breakpoint

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: Stack(
          children: [
            // ANIMATED BACKGROUND CIRCLES
            ...List.generate(6, (index) {
              return AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  final offset = math.sin(
                          (_floatController.value * 2 * math.pi) +
                              (index * 0.8)) *
                      40;
                  return Positioned(
                    left: (index % 3) * (size.width / 3) +
                        (index.isEven ? offset : -offset),
                    top: (index ~/ 3) * (size.height / 2) + offset * 2,
                    child: Opacity(
                      opacity: 0.08,
                      child: Container(
                        width: 120 + (index * 20).toDouble(),
                        height: 120 + (index * 20).toDouble(),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

            // MAIN CONTENT — non-scrollable, fills screen
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: isWide
                      ? _buildDesktopLayout(size)
                      : _buildMobileLayout(size),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // MOBILE LAYOUT  (phones — portrait)
  // ──────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(Size size) {
    return LayoutBuilder(builder: (context, constraints) {
      final availableHeight = constraints.maxHeight;
      // Scale logo based on available height
      final logoSize = (availableHeight * 0.14).clamp(70.0, 120.0);
      final titleFontSize = (availableHeight * 0.05).clamp(28.0, 48.0);
      final vSpacing = (availableHeight * 0.04).clamp(12.0, 40.0);

      return Column(
        children: [
          SizedBox(height: vSpacing),

          // LOGO
          Container(
            padding: EdgeInsets.all(logoSize * 0.2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Container(
              height: logoSize,
              width: logoSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset("assets/images/logo.png", fit: BoxFit.cover),
              ),
            ),
          ),

          SizedBox(height: vSpacing * 0.7),

          // BRAND NAME
          Text(
            "LAUNDRIFY",
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
              shadows: const [
                Shadow(
                    color: Colors.black38,
                    offset: Offset(0, 4),
                    blurRadius: 8),
              ],
            ),
          ),

          SizedBox(height: vSpacing * 0.3),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(
              "Your laundry, our priority",
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          SizedBox(height: vSpacing),

          // CARD — expands to fill remaining space
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24),
              child: _buildCard(compact: true),
            ),
          ),

          SizedBox(height: vSpacing * 0.5),

          // FOOTER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildFooter(),
          ),

          SizedBox(height: vSpacing * 0.5),
        ],
      );
    });
  }

  // ──────────────────────────────────────────────────────────────
  // DESKTOP / WIDE LAYOUT
  // ──────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(Size size) {
    return Row(
      children: [
        // LEFT: branding panel
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF42A5F5).withValues(alpha: 0.3),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Container(
                    height: 130,
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset("assets/images/logo.png",
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "LAUNDRIFY",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    "Your laundry, our priority",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // RIGHT: auth card
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCard(compact: false),
                  const SizedBox(height: 20),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // SHARED CARD WIDGET
  // ──────────────────────────────────────────────────────────────
  Widget _buildCard({required bool compact}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 50,
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 25),
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: EdgeInsets.all(compact ? 24 : 36),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Welcome",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F2027),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Choose how you'd like to continue",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: compact ? 20 : 36),

              // LOGIN BUTTON
              _buildButton(
                label: "LOGIN",
                icon: Icons.login_rounded,
                isPrimary: true,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginPage())),
              ),

              const SizedBox(height: 14),

              // SIGNUP BUTTON
              _buildButton(
                label: "SIGN UP",
                icon: Icons.person_add_rounded,
                isPrimary: false,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignupPage())),
              ),

              SizedBox(height: compact ? 20 : 32),

              // DIVIDER
              Row(
                children: [
                  Expanded(
                      child: Divider(
                          thickness: 1, color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "OR",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                      child: Divider(
                          thickness: 1, color: Colors.grey.shade300)),
                ],
              ),

              SizedBox(height: compact ? 20 : 32),

              // GOOGLE BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    side: BorderSide(
                        color: Colors.grey.shade300, width: 2),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: isLoading ? null : googleSignIn,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF0F2027)),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset("assets/images/google.png",
                                height: 24, width: 24),
                            const SizedBox(width: 12),
                            const Text(
                              "Continue with Google",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        "By continuing, you agree to our\nTerms & Privacy Policy",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.85),
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isPrimary
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2027),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              onPressed: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 12),
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.5)),
                ],
              ),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F2027),
                side: const BorderSide(
                    color: Color(0xFF0F2027), width: 2.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 12),
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.5)),
                ],
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADMIN DASHBOARD PICKER — Full-screen selector shown to admins on sign-in
// ═══════════════════════════════════════════════════════════════════════════

class _AdminDashboardPickerPage extends StatefulWidget {
  final List<String> accessibleRoutes;
  final String userEmail;
  final String userName;
  final String? userPhoto;

  const _AdminDashboardPickerPage({
    required this.accessibleRoutes,
    required this.userEmail,
    required this.userName,
    this.userPhoto,
  });

  @override
  State<_AdminDashboardPickerPage> createState() =>
      _AdminDashboardPickerPageState();
}

class _AdminDashboardPickerPageState extends State<_AdminDashboardPickerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  int? _hoveredIndex;

  static const _navy  = Color(0xFF080F1E);
  static const _navyM = Color(0xFF0D1A2E);
  static const _navyC = Color(0xFF111F35);
  static const _navyB = Color(0xFF1C2F4A);
  static const _gold  = Color(0xFFF5C518);
  static const _goldS = Color(0xFFFDE68A);
  static const _textHi = Color(0xFFF1F5F9);
  static const _textMd = Color(0xFF94A3B8);

  static const _dashboards = [
    _DashInfo(
      route: '/admin-dashboard',
      label: 'Admin Panel',
      sub: 'Full control — users, orders, analytics, employees',
      icon: Icons.admin_panel_settings_rounded,
      gradStart: Color(0xFFF5C518),
      gradEnd: Color(0xFFFFB300),
    ),
    _DashInfo(
      route: '/manager-dashboard',
      label: 'Manager',
      sub: 'Branch management — staff, orders, revenue',
      icon: Icons.manage_accounts_rounded,
      gradStart: Color(0xFF4FC3F7),
      gradEnd: Color(0xFF0288D1),
    ),
    _DashInfo(
      route: '/delivery-dashboard',
      label: 'Delivery',
      sub: 'Driver view — live map, pickups, earnings',
      icon: Icons.delivery_dining_rounded,
      gradStart: Color(0xFF81C784),
      gradEnd: Color(0xFF2E7D32),
    ),
    _DashInfo(
      route: '/employee-dashboard',
      label: 'Employee',
      sub: 'Staff view — laundry tasks, queue, schedule',
      icon: Icons.badge_rounded,
      gradStart: Color(0xFFCE93D8),
      gradEnd: Color(0xFF7B1FA2),
    ),
    _DashInfo(
      route: '/dashboard',
      label: 'User / Customer',
      sub: 'Customer app — book orders, track, profile',
      icon: Icons.person_rounded,
      gradStart: Color(0xFFFF8A65),
      gradEnd: Color(0xFFE64A19),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  List<_DashInfo> get _available => _dashboards
      .where((d) => widget.accessibleRoutes.contains(d.route))
      .toList();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _navy,
      body: Stack(children: [
        // Background
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.2,
                colors: [Color(0xFF0E2147), _navy],
              ),
            ),
          ),
        ),

        SafeArea(child: Column(children: [
          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(children: [
              // Super-admin gold badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_gold, _goldS],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                      color: _gold.withValues(alpha: 0.45),
                      blurRadius: 18, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield_rounded, color: _navy, size: 15),
                  SizedBox(width: 7),
                  Text('SUPER ADMIN ACCESS', style: TextStyle(
                      color: _navy, fontWeight: FontWeight.w900,
                      fontSize: 11, letterSpacing: 1.5)),
                ]),
              ),

              const SizedBox(height: 22),

              // User info row
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (widget.userPhoto != null)
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(widget.userPhoto!),
                    backgroundColor: _navyB,
                  )
                else
                  Container(
                    width: 52, height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [_gold, _goldS]),
                    ),
                    child: const Icon(Icons.person, color: _navy, size: 28),
                  ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    widget.userName.isNotEmpty ? widget.userName : 'Admin',
                    style: const TextStyle(
                        color: _textHi, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(widget.userEmail,
                      style: const TextStyle(color: _textMd, fontSize: 12)),
                ]),
              ]),

              const SizedBox(height: 22),
              const Text('Choose a Dashboard', style: TextStyle(
                  color: _textHi, fontSize: 24, fontWeight: FontWeight.w900,
                  letterSpacing: -0.3)),
              const SizedBox(height: 4),
              const Text('Tap any dashboard to enter',
                  style: TextStyle(color: _textMd, fontSize: 13)),
            ]),
          ),

          // Divider
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            height: 1,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [
              Colors.transparent,
              _gold.withValues(alpha: 0.4),
              Colors.transparent,
            ])),
          ),

          // ── Cards ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: isWide ? _buildGrid() : _buildList(),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _buildGrid() {
    final items = _available;
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 14,
        mainAxisSpacing: 14, childAspectRatio: 2.7,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _card(items[i], i),
    );
  }

  Widget _buildList() {
    final items = _available;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _card(items[i], i),
    );
  }

  Widget _card(_DashInfo info, int index) {
    final delay = index * 0.10;
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (_, child) {
        final t = ((_animCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final c = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: c,
          child: Transform.translate(offset: Offset(0, 28 * (1 - c)), child: child),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = index),
        onExit:  (_) => setState(() => _hoveredIndex = null),
        child: GestureDetector(
          onTap: () => Navigator.pop(context, info.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: _hoveredIndex == index ? _navyC : _navyM,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hoveredIndex == index
                    ? info.gradStart.withValues(alpha: 0.6) : _navyB,
                width: _hoveredIndex == index ? 1.5 : 1,
              ),
              boxShadow: _hoveredIndex == index ? [BoxShadow(
                  color: info.gradStart.withValues(alpha: 0.22),
                  blurRadius: 20, offset: const Offset(0, 6))] : [],
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [info.gradStart, info.gradEnd],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: info.gradStart.withValues(alpha: 0.38),
                      blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Icon(info.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info.label, style: const TextStyle(
                    color: _textHi, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(info.sub, style: const TextStyle(
                    color: _textMd, fontSize: 11, height: 1.3)),
              ])),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: _textMd.withValues(alpha: 0.45), size: 14),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DashInfo {
  final String route, label, sub;
  final IconData icon;
  final Color gradStart, gradEnd;
  const _DashInfo({
    required this.route, required this.label, required this.sub,
    required this.icon, required this.gradStart, required this.gradEnd,
  });
}
