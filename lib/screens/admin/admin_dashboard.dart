import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'admin_theme.dart';
import 'admin_orders_page.dart';
import 'admin_users_page.dart';
import 'admin_employees_page.dart';
import 'admin_payments_page.dart';
import 'admin_notifications_page.dart';
import 'admin_settings_page.dart';
import 'admin_analytics_page.dart';
import 'admin_coupons_page.dart';
import '../auth_options_page.dart';
import '../../services/panel_theme_service.dart';

// ═══════════════════════════════════════════════════════════════════
// ADMIN DASHBOARD — Full Firebase backend  |  Firebase Console-level data
// Light white UI matching user dashboard aesthetic
// ═══════════════════════════════════════════════════════════════════

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  // ── Stats ──────────────────────────────────────────────────────
  int totalUsers = 0, totalOrders = 0, activeOrders = 0, totalEmployees = 0;
  int pendingOrders = 0, completedOrders = 0, cancelledOrders = 0;
  int newUsersToday = 0, newOrdersToday = 0;
  double totalRevenue = 0,
      monthRevenue = 0,
      todayRevenue = 0,
      avgOrderValue = 0;
  bool _loading = true;

  List<Map<String, dynamic>> weeklyOrders = [];
  List<Map<String, dynamic>> monthlyRevenue = [];
  Map<String, int> orderStatus = {};
  Map<String, int> serviceTypes = {};

  late AnimationController _pulseCtrl;
  Timer? _refreshTimer;
  late AnimationController _entryCtrl;
  // ignore: unused_field
  late Animation<double> _entryFade;
  // ignore: unused_field
  late Animation<Offset> _entrySlide;

  static const _navItems = <_NavItem>[
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.receipt_long_rounded, 'Orders'),
    _NavItem(Icons.people_rounded, 'Users'),
    _NavItem(Icons.badge_rounded, 'Employees'),
    _NavItem(Icons.payment_rounded, 'Payments'),
    _NavItem(Icons.local_offer_rounded, 'Coupons'),
    _NavItem(Icons.analytics_rounded, 'Analytics'),
    _NavItem(Icons.notifications_rounded, 'Alerts'),
    _NavItem(Icons.settings_rounded, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadAll(isRefresh: true));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll({bool isRefresh = false}) async {
    if (!isRefresh && mounted) setState(() => _loading = true);
    await Future.wait([_loadStats(), _loadCharts()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadStats() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      // Query users + all 3 role collections + orders
      final results = await Future.wait([
        _db.collection('users').get(),
        _db.collection('orders').get(),
        _db.collection('delivery_agents').count().get(),
        _db.collection('managers').count().get(),
        _db.collection('staff').count().get(),
      ]);

      final usersSnap = results[0] as QuerySnapshot;
      final ordersSnap = results[1] as QuerySnapshot;
      final deliveryCount = (results[2] as AggregateQuerySnapshot).count ?? 0;
      final managerCount  = (results[3] as AggregateQuerySnapshot).count ?? 0;
      final staffCount    = (results[4] as AggregateQuerySnapshot).count ?? 0;

      int uCount = 0, newUsersToday_ = 0;
      for (var d in usersSnap.docs) {
        final m = d.data() as Map;
        final role = (m['role'] ?? 'user') as String;
        if (role == 'user') {
          uCount++;
          final ts = (m['createdAt'] as Timestamp?)?.toDate();
          if (ts != null && ts.isAfter(todayStart)) newUsersToday_++;
        }
      }
      final empCount = deliveryCount + managerCount + staffCount;

      int oTotal = 0, oActive = 0, oPending = 0, oComplete = 0, oCancel = 0, oToday = 0;
      double oRev = 0, oMonthRev = 0, oDayRev = 0;
      for (var d in ordersSnap.docs) {
        final m = d.data() as Map;
        final s = (m['status'] ?? 'pending') as String;
        final ts = (m['createdAt'] as Timestamp?)?.toDate();
        final amt = ((m['total'] ?? m['totalAmount'] ?? 0) as num).toDouble();
        oTotal++;
        if (['pending','assigned','pickup','processing','out_for_delivery','accepted','reached','picked','ready'].contains(s)) oActive++;
        if (s == 'pending') oPending++;
        if (['completed','delivered'].contains(s)) { oComplete++; oRev += amt; }
        if (s == 'cancelled') oCancel++;
        if (ts != null && ts.isAfter(todayStart)) {
          oToday++;
          if (['completed','delivered'].contains(s)) oDayRev += amt;
        }
        if (ts != null && ts.isAfter(monthStart) && ['completed','delivered'].contains(s)) oMonthRev += amt;
      }

      if (mounted) {
        setState(() {
          totalUsers = uCount;
          totalOrders = oTotal;
          activeOrders = oActive;
          totalEmployees = empCount;
          pendingOrders = oPending;
          completedOrders = oComplete;
          cancelledOrders = oCancel;
          newUsersToday = newUsersToday_;
          newOrdersToday = oToday;
          totalRevenue = oRev;
          monthRevenue = oMonthRev;
          todayRevenue = oDayRev;
          avgOrderValue = oComplete > 0 ? oRev / oComplete : 0;
        });
      }
    } catch (e) {
      debugPrint('Stats error: $e');
      // Cancel refresh timer if permission denied — rules need to be applied
      if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
        _refreshTimer?.cancel();
        debugPrint('Admin dashboard: Firestore rules not applied. Apply firestore.rules in Firebase Console.');
      }
      if (mounted) setState(() => _loading = false);
    }
  }

    Future<void> _loadCharts() async {
    try {
      final now = DateTime.now();
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      // Fetch all orders at once — no compound indexes needed
      final allOrders = await _db.collection('orders').get();

      // Weekly orders (last 7 days)
      final List<Map<String, dynamic>> wk = List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        return {'day': days[day.weekday - 1], 'count': 0.0, 'revenue': 0.0, 'date': DateTime(day.year, day.month, day.day)};
      });

      // Status + service maps + monthly
      final Map<String, int> sMap = {}, svMap = {};
      final Map<int, double> monRevMap = {}; // month index → revenue
      final Map<int, int> monOrdMap = {};

      for (var d in allOrders.docs) {
        final m = d.data();
        final s = (m['status'] ?? 'pending') as String;
        final svc = (m['serviceType'] ?? 'laundry') as String;
        final ts = (m['createdAt'] as Timestamp?)?.toDate();
        final amt = ((m['total'] ?? m['totalAmount'] ?? 0) as num).toDouble();

        sMap[s] = (sMap[s] ?? 0) + 1;
        svMap[svc] = (svMap[svc] ?? 0) + 1;

        if (ts != null) {
          // Weekly
          for (var w in wk) {
            final wDate = w['date'] as DateTime;
            if (ts.year == wDate.year && ts.month == wDate.month && ts.day == wDate.day) {
              w['count'] = (w['count'] as double) + 1;
              if (['completed','delivered'].contains(s)) {
                w['revenue'] = (w['revenue'] as double) + amt;
              }
            }
          }
          // Monthly (last 6 months)
          for (int i = 5; i >= 0; i--) {
            final mDate = DateTime(now.year, now.month - i, 1);
            if (ts.year == mDate.year && ts.month == mDate.month) {
              final key = 5 - i;
              monOrdMap[key] = (monOrdMap[key] ?? 0) + 1;
              if (['completed','delivered'].contains(s)) {
                monRevMap[key] = (monRevMap[key] ?? 0) + amt;
              }
            }
          }
        }
      }

      // Build monthly list
      final List<Map<String, dynamic>> monList = [];
      for (int i = 5; i >= 0; i--) {
        final mDate = DateTime(now.year, now.month - i, 1);
        final key = 5 - i;
        monList.add({
          'month': months[mDate.month - 1],
          'revenue': monRevMap[key] ?? 0.0,
          'orders': monOrdMap[key] ?? 0,
        });
      }

      if (mounted) {
        setState(() {
          weeklyOrders = wk;
          orderStatus = sMap;
          serviceTypes = svMap;
          monthlyRevenue = monList;
        });
      }
    } catch (e) {
      debugPrint('Charts error: $e');
      if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
        _refreshTimer?.cancel();
      }
    }
  }

    @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final isWide = MediaQuery.of(context).size.width > 760;
    // PanelThemeScope MUST wrap the scaffold so DynAdmin.of(context) inside
    // children reads the correct (possibly dark) brightness from the panel theme.
    return PanelThemeScope(
      panelKey: 'admin',
      child: Builder(
        builder: (ctx) {
          final at = DynAdmin.of(ctx);
          return Scaffold(
            backgroundColor: at.bg,
            drawer: isWide
                ? null
                : Drawer(
                    backgroundColor: at.surface,
                    child: _sidebar(ctx),
                  ),
            body: Row(children: [
              if (isWide) _sidebar(ctx),
              Expanded(
                  child: Column(children: [
                _topBar(isWide),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                          key: ValueKey(_selectedIndex), child: _page()),
                    ),
                  ),
                ),
              ])),
            ]),
          );
        },
      ),
    );
  }

  Widget _page() {
    switch (_selectedIndex) {
      case 0: return _home();
      case 1: return const AdminOrdersPage();
      case 2: return const AdminUsersPage();
      case 3: return const AdminEmployeesPage();
      case 4: return const AdminPaymentsPage();
      case 5: return const AdminCouponsPage();
      case 6: return const AdminAnalyticsPage();
      case 7: return const AdminNotificationsPage();
      case 8: return const AdminSettingsPage();
      default: return _home();
    }
  }

  // ── Sidebar ───────────────────────────────────────────────────
  Widget _sidebar(BuildContext themedCtx) {
    final at = DynAdmin.of(themedCtx);
    final user = _auth.currentUser;
    return Container(
      width: 215,
      decoration: BoxDecoration(
        color: at.surface,
        border: Border(right: BorderSide(color: at.cardBorder)),
      ),
      child: SafeArea(
          child: Column(children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Laundrify',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: at.textPrimary)),
                  Text('Admin Portal',
                      style: TextStyle(
                          fontSize: 10, color: at.textSecondary)),
                ]),
          ]),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: _navItems.length,
            itemBuilder: (_, i) {
              final item = _navItems[i];
              final active = _selectedIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = i);
                  _entryCtrl.forward(from: 0);
                  // Close drawer on mobile
                  final scaffold = Scaffold.maybeOf(themedCtx);
                  if (scaffold != null && scaffold.isDrawerOpen) {
                    Navigator.of(themedCtx).pop();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? AdminTheme.gold.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: active
                            ? AdminTheme.gold.withValues(alpha: 0.35)
                            : Colors.transparent),
                  ),
                  child: Row(children: [
                    Icon(item.icon,
                        color:
                            active ? AdminTheme.gold : at.textSecondary,
                        size: 17),
                    const SizedBox(width: 10),
                    Text(item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AdminTheme.gold
                              : at.textSecondary,
                        )),
                    if (active) ...[
                      const Spacer(),
                      Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AdminTheme.gold, shape: BoxShape.circle))
                    ],
                  ]),
                ),
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
              color: at.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: at.cardBorder)),
          child: Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AdminTheme.gold.withValues(alpha: 0.2),
              backgroundImage: null,
              child: user?.photoURL != null
                  ? ClipOval(child: Image.network(user!.photoURL!, width: 34, height: 34, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text((user.displayName ?? 'A')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AdminTheme.gold))))
                  : user?.photoURL == null
                  ? const Icon(Icons.person_rounded,
                      color: AdminTheme.gold, size: 16)
                  : null,
            ),
            const SizedBox(width: 9),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(user?.displayName ?? 'Admin',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: at.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('Administrator',
                      style: TextStyle(
                          fontSize: 9, color: at.textSecondary)),
                ])),
            GestureDetector(
              onTap: () {
                final uid = _auth.currentUser?.uid ?? '';
                Navigator.of(themedCtx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthOptionsPage()),
                  (r) => false,
                );
                _auth.signOut().then((_) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('last_dashboard_$uid');
                });
              },
              child: const Icon(Icons.logout_rounded,
                  color: AdminTheme.rose, size: 16),
            ),
          ]),
        ),
        const SizedBox(height: 4),
      ])),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────
  Widget _topBar(bool isWide) {
    final at = DynAdmin.of(context);
    final user = _auth.currentUser;
    final name = user?.displayName ?? 'Admin';
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF080F1E), Color(0xFF0D2145), Color(0xFF0A1628)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Row(children: [
            // Menu (mobile) or Avatar
            if (!isWide)
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  child: Container(
                    width: 42, height: 42,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            // Gold avatar with initial
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AdminTheme.gold, Color(0xFFFDE68A)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AdminTheme.gold.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF080F1E))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greeting, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
            const SizedBox(width: 8),
            // Refresh
            GestureDetector(
              onTap: _loadAll,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Builder(builder: (ctx) {
              PanelThemeService? pt;
              try {
                pt = PanelThemeScope.of(ctx);
              } catch (_) {}
              if (pt == null) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => pt!.toggle(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Icon(
                    at.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            // Sign out
            GestureDetector(
              onTap: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
                  content: const Text('Sign out of Admin Panel?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ));
                if (ok == true && mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthOptionsPage()),
                    (r) => false,
                  );
                  _auth.signOut();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DASHBOARD HOME
  // ═══════════════════════════════════════════════════════════════════
  Widget _home() {
    final at = DynAdmin.of(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AdminTheme.gold, strokeWidth: 2.5));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _welcome(),
        const SizedBox(height: 18),
        Text('Key Metrics', style: at.heading(15)),
        const SizedBox(height: 10),
        _kpiGrid(),
        const SizedBox(height: 18),
        _todayRow(),
        const SizedBox(height: 18),
        LayoutBuilder(
            builder: (_, c) => c.maxWidth > 650
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: _weeklyChart()),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: _statusChart()),
                  ])
                : Column(children: [
                    _weeklyChart(),
                    const SizedBox(height: 14),
                    _statusChart()
                  ])),
        const SizedBox(height: 18),
        _revenueChart(),
        const SizedBox(height: 18),
        LayoutBuilder(
            builder: (_, c) => c.maxWidth > 650
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: _liveOrders()),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: _serviceCard()),
                  ])
                : Column(children: [
                    _liveOrders(),
                    const SizedBox(height: 14),
                    _serviceCard()
                  ])),
        const SizedBox(height: 18),
        _recentUsers(),
        const SizedBox(height: 18),
        _appUsage(),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _welcome() {
    final user = _auth.currentUser;
    final name = user?.displayName ?? 'Admin';
    final h = DateTime.now().hour;
    final g = h < 12
        ? 'Good Morning'
        : h < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF080F1E), Color(0xFF0D1F3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF080F1E).withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 7))
        ],
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$g, ${name.split(' ').first}! 👑',
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 3),
          const Text('Here\'s your real-time business overview',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 14),
          Row(children: [
            _miniKpi('Revenue', '₹${_fmtNum(totalRevenue)}', AdminTheme.gold),
            const SizedBox(width: 20),
            _miniKpi('Today', '₹${_fmtNum(todayRevenue)}', AdminTheme.emerald),
            const SizedBox(width: 20),
            _miniKpi('Active', '$activeOrders orders', AdminTheme.accentGlow),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AdminTheme.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminTheme.gold.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: AdminTheme.gold, size: 34),
        ),
      ]),
    );
  }

  Widget _miniKpi(String l, String v, Color c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v,
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c)),
        Text(l,
            style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600)),
      ]);

  Widget _kpiGrid() {
    final items = [
      _KpiD('Total Users', '$totalUsers', Icons.people_rounded,
          AdminTheme.accent, '+$newUsersToday today'),
      _KpiD('Total Orders', '$totalOrders', Icons.shopping_bag_rounded,
          AdminTheme.violet, '+$newOrdersToday today'),
      _KpiD('Active Orders', '$activeOrders', Icons.local_shipping_rounded,
          AdminTheme.amber, 'Right now'),
      _KpiD('Employees', '$totalEmployees', Icons.badge_rounded,
          AdminTheme.emerald, 'On platform'),
      _KpiD('Completed', '$completedOrders', Icons.check_circle_outline,
          AdminTheme.emerald, 'All time'),
      _KpiD('Pending', '$pendingOrders', Icons.schedule_rounded,
          AdminTheme.amber, 'Awaiting'),
      _KpiD('Month Revenue', '₹${_fmtNum(monthRevenue)}',
          Icons.trending_up_rounded, AdminTheme.gold, 'This month'),
      _KpiD('Avg Order', '₹${avgOrderValue.toStringAsFixed(0)}',
          Icons.currency_rupee_rounded, AdminTheme.cyan, 'Per order'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: 2 cols on narrow, 4 on wide
        final cols = constraints.maxWidth < 400 ? 2 : 4;
        // Calculate safe aspect ratio based on available card width
        final cardW = (constraints.maxWidth - (cols - 1) * 10) / cols;
        // Each card needs ~90px height for icon row + value + label + padding
        final ratio = (cardW / 90).clamp(0.9, 1.6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: ratio),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final at = DynAdmin.of(context);
            final it = items[i];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: at.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: it.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7)),
                        child: Icon(it.icon, color: it.color, size: 13)),
                    const Spacer(),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: AdminTheme.emerald.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(it.sub,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 6.5,
                                fontWeight: FontWeight.w800,
                                color: AdminTheme.emerald)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(it.value,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: it.color,
                            letterSpacing: -0.5)),
                  ),
                  const SizedBox(height: 2),
                  Text(it.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: at.label(9)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _todayRow() {
    final at = DynAdmin.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: at.cardDecoration(goldGlow: true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AdminTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.today_rounded,
                  color: AdminTheme.gold, size: 16)),
          const SizedBox(width: 9),
          Text("Today's Overview", style: at.heading(14)),
          const Spacer(),
          Text(_fmtDate(DateTime.now()), style: at.label(11)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _todayTile('New Users', '$newUsersToday', AdminTheme.accent),
          const SizedBox(width: 8),
          _todayTile('New Orders', '$newOrdersToday', AdminTheme.violet),
          const SizedBox(width: 8),
          _todayTile('Revenue', '₹${_fmtNum(todayRevenue)}', AdminTheme.gold),
          const SizedBox(width: 8),
          _todayTile('Active', '$activeOrders', AdminTheme.amber),
        ]),
      ]),
    );
  }

  Widget _todayTile(String l, String v, Color c) {
    final at = DynAdmin.of(context);
    return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: c.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: c.withValues(alpha: 0.2))),
          child: Column(children: [
            Text(v,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: c)),
            const SizedBox(height: 3),
            Text(l,
                style:
                    at.label(9).copyWith(color: at.textMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
  }

  Widget _weeklyChart() {
    final at = DynAdmin.of(context);
    final max = weeklyOrders.isEmpty
        ? 1.0
        : weeklyOrders
            .map((e) => e['count'] as double)
            .reduce(math.max)
            .clamp(1.0, double.infinity);
    final todayLabel = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ][DateTime.now().weekday - 1];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: at.cardDecoration(glow: true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Orders This Week', style: at.heading(13)),
          const Spacer(),
          Text(
              '${weeklyOrders.fold(0.0, (a, e) => a + (e['count'] as double)).toInt()} total',
              style: at.label(11)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 120,
          child: weeklyOrders.isEmpty
              ? Center(child: Text('No data', style: at.label(13)))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: weeklyOrders.map((d) {
                    final cnt = d['count'] as double;
                    final h = (cnt / max) * 90;
                    final today = d['day'] == todayLabel;
                    return Flexible(child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${cnt.toInt()}',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: today
                                      ? AdminTheme.gold
                                      : at.textMuted)),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 700),
                            width: 24,
                            height: h.clamp(4, 90),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: today
                                    ? [AdminTheme.gold, AdminTheme.goldSoft]
                                    : [
                                        AdminTheme.accent,
                                        AdminTheme.accentGlow
                                      ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                              boxShadow: today
                                  ? [
                                      BoxShadow(
                                          color: AdminTheme.gold
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2))
                                    ]
                                  : [],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(d['day'],
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: today
                                      ? AdminTheme.gold
                                      : at.textSecondary)),
                        ])); // close Flexible
                  }).toList()),
        ),
      ]),
    );
  }

  Widget _statusChart() {
    final at = DynAdmin.of(context);
    final total = orderStatus.values.fold(0, (a, b) => a + b);
    final colors = {
      'pending': AdminTheme.amber,
      'processing': AdminTheme.accent,
      'completed': AdminTheme.emerald,
      'delivered': AdminTheme.emerald,
      'cancelled': AdminTheme.rose,
      'out_for_delivery': AdminTheme.amber,
      'pickup': AdminTheme.violet,
      'assigned': AdminTheme.gold,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: at.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Order Status', style: at.heading(13)),
        const SizedBox(height: 3),
        Text('$total total orders', style: at.label(10)),
        const SizedBox(height: 12),
        if (total == 0)
          Center(child: Text('No orders yet', style: at.label(13)))
        else
          ...orderStatus.entries.take(7).map((e) {
            final at = DynAdmin.of(context);
            final pct = e.value / total;
            final c = colors[e.key] ?? at.textSecondary;
            return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                e.key.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: at.textSecondary))),
                        Text('${e.value}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: c)),
                        const SizedBox(width: 5),
                        Text('${(pct * 100).toInt()}%',
                            style: at.label(8)),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 4,
                              backgroundColor: c.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(c))),
                    ]));
          }),
      ]),
    );
  }

  Widget _revenueChart() {
    final at = DynAdmin.of(context);
    final max = monthlyRevenue.isEmpty
        ? 1.0
        : monthlyRevenue
            .map((e) => e['revenue'] as double)
            .reduce(math.max)
            .clamp(1.0, double.infinity);
    final totalRev =
        monthlyRevenue.fold(0.0, (s, e) => s + (e['revenue'] as double));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: at.cardDecoration(glow: true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('6-Month Revenue', style: at.heading(13)),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AdminTheme.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('₹${_fmtNum(totalRev)} total',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AdminTheme.emerald))),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 130,
          child: monthlyRevenue.isEmpty
              ? Center(
                  child: Text('No revenue data', style: at.label(13)))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: monthlyRevenue.asMap().entries.map((entry) {
                    final at = DynAdmin.of(context);
                    final e = entry.value;
                    final rev = e['revenue'] as double;
                    final h = (rev / max) * 100;
                    final last = entry.key == monthlyRevenue.length - 1;
                    return Flexible(child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('₹${_fmtNum(rev)}',
                              style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                  color: last
                                      ? AdminTheme.emerald
                                      : at.textMuted)),
                          const SizedBox(height: 3),
                          Container(
                            width: 32,
                            height: h.clamp(4, 100),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: last
                                      ? [
                                          AdminTheme.emerald,
                                          const Color(0xFF059669)
                                        ]
                                      : [
                                          AdminTheme.emerald
                                              .withValues(alpha: 0.4),
                                          AdminTheme.emerald
                                              .withValues(alpha: 0.12)
                                        ]),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5)),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(e['month'], style: at.label(9)),
                          Text('${e['orders']}',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: at.textMuted,
                                  fontWeight: FontWeight.w600)),
                        ])); // close Flexible
                  }).toList()),
        ),
      ]),
    );
  }

  Widget _liveOrders() {
    final at = DynAdmin.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: at.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Live Orders', style: at.heading(13)),
          const Spacer(),
          AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) =>
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AdminTheme.emerald
                              .withValues(alpha: 0.5 + _pulseCtrl.value * 0.5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: AdminTheme.emerald
                                    .withValues(alpha: _pulseCtrl.value * 0.5),
                                blurRadius: 5)
                          ],
                        )),
                    const SizedBox(width: 4),
                    const Text('Real-time',
                        style: TextStyle(
                            fontSize: 9,
                            color: AdminTheme.emerald,
                            fontWeight: FontWeight.w700)),
                  ])),
        ]),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('orders')
              .where('status', whereIn: [
                'pending',
                'pickup',
                'processing',
                'assigned',
                'out_for_delivery',
                'reached',
                'picked',
                'accepted'
              ])
              .orderBy('createdAt', descending: true)
              .limit(6)
              .snapshots(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AdminTheme.gold, strokeWidth: 2)));
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              final at = DynAdmin.of(context);
              return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: Column(children: [
                    Icon(Icons.inbox_rounded,
                        color: at.textMuted, size: 32),
                    const SizedBox(height: 6),
                    Text('No active orders', style: at.label(12)),
                  ])));
            }
            return Column(
                children: snap.data!.docs.map((doc) {
              final at = DynAdmin.of(context);
              final d = doc.data() as Map<String, dynamic>;
              final status = d['status'] ?? 'pending';
              final c = statusColor(status);
              final ts = (d['createdAt'] as Timestamp?)?.toDate();
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: c.withValues(alpha: 0.2))),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(statusIcon(status), color: c, size: 14)),
                  const SizedBox(width: 9),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(d['customerName'] ?? 'Customer',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: at.textPrimary)),
                        Text(
                            '#${doc.id.substring(0, 7).toUpperCase()}  ₹${(d['total'] ?? d['totalAmount'] ?? 0).toStringAsFixed(0)}',
                            style: at.label(9)),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    AdminBadge(
                        label: status.replaceAll('_', ' '),
                        color: c,
                        fontSize: 8.5),
                    if (ts != null) ...[
                      const SizedBox(height: 2),
                      Text('${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                          style: at.label(8)
                              .copyWith(color: at.textMuted))
                    ],
                  ]),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  Widget _serviceCard() {
    final at = DynAdmin.of(context);
    final sColors = {
      'laundry': AdminTheme.accent,
      'dryclean': AdminTheme.violet,
      'carpet': AdminTheme.amber,
      'shoe': AdminTheme.emerald,
      'bag': AdminTheme.cyan,
      'curtain': AdminTheme.rose
    };
    final sIcons = {
      'laundry': Icons.local_laundry_service_rounded,
      'dryclean': Icons.dry_cleaning_rounded,
      'carpet': Icons.grid_4x4_rounded,
      'shoe': Icons.do_not_step_rounded,
      'bag': Icons.shopping_bag_rounded,
      'curtain': Icons.curtains_rounded,
    };
    final total = serviceTypes.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: at.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Services', style: at.heading(13)),
        const SizedBox(height: 3),
        Text('$total orders across ${serviceTypes.length} types',
            style: at.label(10)),
        const SizedBox(height: 12),
        if (serviceTypes.isEmpty)
          Center(child: Text('No data', style: at.label(13)))
        else
          ...serviceTypes.entries.map((e) {
            final c = sColors[e.key] ?? at.textSecondary;
            final icon = sIcons[e.key] ?? Icons.category_rounded;
            final pct = total > 0 ? e.value / total : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.withValues(alpha: 0.18))),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7)),
                    child: Icon(icon, color: c, size: 13)),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(e.key.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: at.textPrimary)),
                      const SizedBox(height: 3),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 3,
                              backgroundColor: c.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(c))),
                    ])),
                const SizedBox(width: 7),
                Text('${e.value}',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900, color: c)),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _recentUsers() {
    final at = DynAdmin.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: at.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Recent Signups', style: at.heading(13)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 2),
            child: const Text('View all →',
                style: TextStyle(
                    fontSize: 11,
                    color: AdminTheme.gold,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          // No composite index needed: simple role filter, sort client-side
          stream: _db
              .collection('users')
              .where('role', isEqualTo: 'user')
              .limit(20)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AdminTheme.gold, strokeWidth: 2));
            }
            final docs = [...snap.data!.docs]..sort((a, b) {
              final ta = ((a.data() as Map)['createdAt'] as Timestamp?);
              final tb = ((b.data() as Map)['createdAt'] as Timestamp?);
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            });
            final topDocs = docs.take(5).toList();
            if (topDocs.isEmpty) {
              final at = DynAdmin.of(context);
              return Center(
                  child: Text('No users yet', style: at.label(13)));
            }
            return Column(
                children: topDocs.map((doc) {
              final at = DynAdmin.of(context);
              final d = doc.data() as Map<String, dynamic>;
              final name = d['name'] ?? 'User';
              final ts = (d['createdAt'] as Timestamp?)?.toDate();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                visualDensity: const VisualDensity(vertical: -3),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AdminTheme.accent.withValues(alpha: 0.15),
                  backgroundImage: d['photoURL'] != null
                      ? NetworkImage(d['photoURL'])
                      : null,
                  child: d['photoURL'] == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AdminTheme.accent))
                      : null,
                ),
                title: Text(name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: at.textPrimary)),
                subtitle: Text(d['email'] ?? '', style: at.label(10)),
                trailing: ts != null
                    ? Text('${ts.day}/${ts.month}',
                        style: at.label(10)
                            .copyWith(color: at.textMuted))
                    : null,
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  Widget _appUsage() {
    final at = DynAdmin.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: at.cardDecoration(goldGlow: true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AdminTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.insights_rounded,
                  color: AdminTheme.gold, size: 15)),
          const SizedBox(width: 8),
          Text('App Usage Summary', style: at.heading(14)),
        ]),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('orders').snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AdminTheme.gold, strokeWidth: 2));
            }
            final docs = snap.data!.docs;
            final total = docs.length;
            final comp = docs
                .where((d) => ['completed', 'delivered']
                    .contains((d.data() as Map)['status']))
                .length;
            final cancel = docs
                .where((d) => (d.data() as Map)['status'] == 'cancelled')
                .length;
            final conv = total > 0 ? comp / total * 100 : 0.0;
            final canc = total > 0 ? cancel / total * 100 : 0.0;
            return Row(children: [
              _usageTile('Completion', '${conv.toStringAsFixed(1)}%',
                  AdminTheme.emerald, Icons.check_circle_outline),
              const SizedBox(width: 8),
              _usageTile('Cancellation', '${canc.toStringAsFixed(1)}%',
                  AdminTheme.rose, Icons.cancel_outlined),
              const SizedBox(width: 8),
              _usageTile('Total Orders', '$total', AdminTheme.violet,
                  Icons.shopping_bag_rounded),
              const SizedBox(width: 8),
              _usageTile('Avg Revenue', '₹${avgOrderValue.toStringAsFixed(0)}',
                  AdminTheme.gold, Icons.trending_up_rounded),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _usageTile(String l, String v, Color c, IconData icon) {
    final at = DynAdmin.of(context);
    return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: c.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: c.withValues(alpha: 0.2))),
          child: Column(children: [
            Icon(icon, color: c, size: 18),
            const SizedBox(height: 5),
            Text(v,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: c)),
            const SizedBox(height: 2),
            Text(l,
                style:
                    at.label(8).copyWith(color: at.textMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
  }

  String _fmtNum(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${w[d.weekday - 1]}, ${m[d.month - 1]} ${d.day}';
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _KpiD {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _KpiD(this.label, this.value, this.icon, this.color, this.sub);
}
