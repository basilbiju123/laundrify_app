import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'admin_theme.dart';

// ═══════════════════════════════════════════════════════════
// ADMIN ANALYTICS — Full App Data: Users, Orders, Revenue,
// Employees, Payments — All real Firestore data
// ═══════════════════════════════════════════════════════════
class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});
  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;

  // ── Monthly data
  List<Map<String, dynamic>> _monthlyData = [];

  // ── Revenue
  double _totalRevenue = 0, _monthRevenue = 0, _todayRevenue = 0;

  // ── Orders
  int _totalOrders = 0, _pendingOrders = 0, _completedOrders = 0,
      _cancelledOrders = 0, _todayOrders = 0, _activeOrders = 0;

  // ── Users
  int _totalUsers = 0, _newUsersToday = 0, _newUsersWeek = 0;

  // ── Employees
  int _totalDelivery = 0, _onlineAgents = 0, _totalStaff = 0, _totalManagers = 0;

  // ── Services
  Map<String, double> _revenueByService = {};
  Map<String, int> _countByService = {};

  // ── Payment methods
  Map<String, int> _paymentMethods = {};

  // ── Recent orders
  List<Map<String, dynamic>> _recentOrders = [];

  // ── Top customers
  List<Map<String, dynamic>> _topCustomers = [];

  bool _loading = true;
  String _chartType = 'bar';
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _loadAll();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadOrders(),
      _loadUsers(),
      _loadEmployees(),
      _loadMonthly(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadOrders() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final allSnap = await _db.collection('orders').get();
      
      double totalRev = 0, monthRev = 0, todayRev = 0;
      int total = 0, pending = 0, completed = 0, cancelled = 0, todayOrd = 0, active = 0;
      final Map<String, double> byService = {};
      final Map<String, int> countByService = {};
      final Map<String, int> payMap = {};
      final List<Map<String, dynamic>> recent = [];
      final Map<String, Map<String, dynamic>> custMap = {};

      for (final doc in allSnap.docs) {
        final d = doc.data();
        total++;
        final amt = ((d['totalAmount'] ?? d['total'] ?? 0) as num).toDouble();
        final st = (d['status'] ?? '').toString().toLowerCase();
        final pm = (d['paymentMethod'] ?? 'unknown').toString();
        final svc = (d['serviceType'] ?? d['services'] != null ? 'Multiple' : 'Laundry').toString();
        
        // Revenue counts
        if (['delivered', 'completed'].contains(st)) {
          totalRev += amt;
          completed++;
        }
        if (st == 'pending') pending++;
        if (st == 'cancelled') cancelled++;
        if (!['pending', 'cancelled', 'delivered', 'completed'].contains(st)) active++;

        // Today
        final createdAt = d['createdAt'];
        DateTime? dt;
        if (createdAt is Timestamp) dt = createdAt.toDate();
        if (dt != null) {
          if (dt.isAfter(todayStart)) { todayOrd++; todayRev += amt; }
          final monthStart = DateTime(now.year, now.month, 1);
          if (dt.isAfter(monthStart)) monthRev += amt;
        }

        // By service
        byService[svc] = (byService[svc] ?? 0) + amt;
        countByService[svc] = (countByService[svc] ?? 0) + 1;

        // Payment methods
        payMap[pm] = (payMap[pm] ?? 0) + 1;

        // Top customers
        final uid = d['userId'] ?? d['customerId'] ?? '';
        if (uid.isNotEmpty) {
          final existing = custMap[uid];
          if (existing == null) {
            custMap[uid] = {
              'uid': uid,
              'name': d['customerName'] ?? 'Customer',
              'orders': 1,
              'spent': amt,
            };
          } else {
            existing['orders'] = (existing['orders'] as int) + 1;
            existing['spent'] = (existing['spent'] as double) + amt;
          }
        }

        // Recent 10 orders
        if (recent.length < 10) {
          recent.add({
            ...d,
            'id': doc.id,
            'createdAt': dt,
          });
        }
      }

      // Sort top customers by spent
      final topCust = custMap.values.toList()
        ..sort((a, b) => (b['spent'] as double).compareTo(a['spent'] as double));

      if (mounted) {
        setState(() {
          _totalRevenue = totalRev;
          _monthRevenue = monthRev;
          _todayRevenue = todayRev;
          _totalOrders = total;
          _pendingOrders = pending;
          _completedOrders = completed;
          _cancelledOrders = cancelled;
          _todayOrders = todayOrd;
          _activeOrders = active;
          _revenueByService = byService;
          _countByService = countByService;
          _paymentMethods = payMap;
          _recentOrders = recent;
          _topCustomers = topCust.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('orders error: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final now = DateTime.now();
      final todayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      final weekStart = Timestamp.fromDate(now.subtract(const Duration(days: 7)));

      final res = await Future.wait([
        _db.collection('users').where('role', isEqualTo: 'user').get(),
        _db.collection('users').where('role', isEqualTo: 'user')
            .where('createdAt', isGreaterThanOrEqualTo: todayStart).get(),
        _db.collection('users').where('role', isEqualTo: 'user')
            .where('createdAt', isGreaterThanOrEqualTo: weekStart).get(),
      ]);

      if (mounted) {
        setState(() {
          _totalUsers = res[0].docs.length;
          _newUsersToday = res[1].docs.length;
          _newUsersWeek = res[2].docs.length;
        });
      }
    } catch (e) {
      debugPrint('users error: $e');
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await Future.wait([
        _db.collection('users').where('role', isEqualTo: 'delivery').get(),
        _db.collection('users').where('role', isEqualTo: 'delivery').where('isOnline', isEqualTo: true).get(),
        _db.collection('users').where('role', isEqualTo: 'staff').get(),
        _db.collection('users').where('role', isEqualTo: 'manager').get(),
      ]);
      if (mounted) {
        setState(() {
          _totalDelivery = res[0].docs.length;
          _onlineAgents = res[1].docs.length;
          _totalStaff = res[2].docs.length;
          _totalManagers = res[3].docs.length;
        });
      }
    } catch (e) {
      debugPrint('employees error: $e');
    }
  }

  Future<void> _loadMonthly() async {
    try {
      final now = DateTime.now();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final monthly = <Map<String, dynamic>>[];

      for (int i = 5; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i, 1);
        final next = DateTime(m.year, m.month + 1, 1);
        try {
          final snap = await _db.collection('orders')
              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(m))
              .where('createdAt', isLessThan: Timestamp.fromDate(next)).get();
          double rev = 0;
          for (final d in snap.docs) {
            if (['delivered','completed'].contains(d.data()['status'])) {
              rev += ((d.data()['totalAmount'] ?? d.data()['total'] ?? 0) as num).toDouble();
            }
          }
          monthly.add({'month': months[m.month - 1], 'revenue': rev, 'orders': snap.docs.length});
        } catch (_) {
          monthly.add({'month': months[m.month - 1], 'revenue': 0.0, 'orders': 0});
        }
      }

      if (mounted) setState(() => _monthlyData = monthly);
    } catch (e) {
      debugPrint('monthly error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: AdminTheme.gold, strokeWidth: 2.5),
        const SizedBox(height: 16),
        Text('Loading analytics...', style: AdminTheme.label(13)),
      ]));
    }

    return RefreshIndicator(
      color: AdminTheme.gold,
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          AdminPageHeader(title: 'Analytics', subtitle: 'Complete app data overview'),
          const SizedBox(height: 4),
          _lastUpdated(),
          const SizedBox(height: 20),

          // ── REVENUE KPIs ─────────────────────────────────────
          _sectionLabel('💰 Revenue Overview'),
          const SizedBox(height: 10),
          _revenueKpis(),
          const SizedBox(height: 20),

          // ── ORDER STATUS ──────────────────────────────────────
          _sectionLabel('📦 Order Breakdown'),
          const SizedBox(height: 10),
          _orderKpis(),
          const SizedBox(height: 20),

          // ── USERS & EMPLOYEES ─────────────────────────────────
          _sectionLabel('👥 Users & Team'),
          const SizedBox(height: 10),
          _usersEmployeesRow(),
          const SizedBox(height: 20),

          // ── 6-MONTH CHART ─────────────────────────────────────
          _sectionLabel('📈 6-Month Revenue Chart'),
          const SizedBox(height: 10),
          _revenueChart(),
          const SizedBox(height: 20),

          // ── ORDER FUNNEL ──────────────────────────────────────
          _sectionLabel('🔄 Order Funnel'),
          const SizedBox(height: 10),
          _orderFunnel(),
          const SizedBox(height: 20),

          // ── SERVICE BREAKDOWN ─────────────────────────────────
          _sectionLabel('🧺 Revenue by Service'),
          const SizedBox(height: 10),
          _serviceRevenue(),
          const SizedBox(height: 20),

          // ── PAYMENT METHODS ───────────────────────────────────
          _sectionLabel('💳 Payment Methods'),
          const SizedBox(height: 10),
          _paymentMethodsCard(),
          const SizedBox(height: 20),

          // ── TOP CUSTOMERS ─────────────────────────────────────
          _sectionLabel('⭐ Top Customers'),
          const SizedBox(height: 10),
          _topCustomersCard(),
          const SizedBox(height: 20),

          // ── RECENT ORDERS ─────────────────────────────────────
          _sectionLabel('🕒 Recent Orders'),
          const SizedBox(height: 10),
          _recentOrdersList(),
          const SizedBox(height: 20),

          // ── MONTHLY VOLUMES ───────────────────────────────────
          _sectionLabel('📊 Monthly Order Volume'),
          const SizedBox(height: 10),
          _monthlyVolumeChart(),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _lastUpdated() {
    return Row(children: [
      Icon(Icons.update_rounded, size: 12, color: AdminTheme.textSecondary),
      const SizedBox(width: 4),
      Text('Tap ↻ to refresh  ·  Pull down to reload', style: AdminTheme.label(11)),
    ]);
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: const TextStyle(
      fontSize: 15, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary));
  }

  // ── Revenue KPI row ──────────────────────────────────────────────
  Widget _revenueKpis() {
    return Column(children: [
      Row(children: [
        Expanded(child: AdminStatCard(title: 'Total Revenue', value: '₹${_fmtNum(_totalRevenue)}', icon: Icons.trending_up_rounded, color: AdminTheme.emerald, trend: null)),
        const SizedBox(width: 12),
        Expanded(child: AdminStatCard(title: 'This Month', value: '₹${_fmtNum(_monthRevenue)}', icon: Icons.calendar_today_rounded, color: AdminTheme.gold, trend: null)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: AdminStatCard(title: "Today's Revenue", value: '₹${_fmtNum(_todayRevenue)}', icon: Icons.today_rounded, color: AdminTheme.accent, trend: null)),
        const SizedBox(width: 12),
        Expanded(child: AdminStatCard(title: 'Avg Order Value', value: _totalOrders > 0 ? '₹${_fmtNum(_totalRevenue / _totalOrders)}' : '₹0', icon: Icons.analytics_rounded, color: AdminTheme.violet, trend: null)),
      ]),
    ]);
  }

  // ── Order KPI row ────────────────────────────────────────────────
  Widget _orderKpis() {
    return Column(children: [
      Row(children: [
        Expanded(child: _miniCard('Total Orders', '$_totalOrders', Icons.shopping_bag_rounded, AdminTheme.gold)),
        const SizedBox(width: 10),
        Expanded(child: _miniCard("Today's Orders", '$_todayOrders', Icons.today_rounded, AdminTheme.accent)),
        const SizedBox(width: 10),
        Expanded(child: _miniCard('Active Now', '$_activeOrders', Icons.local_shipping_rounded, AdminTheme.emerald)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _miniCard('Pending', '$_pendingOrders', Icons.pending_actions_rounded, const Color(0xFFF59E0B))),
        const SizedBox(width: 10),
        Expanded(child: _miniCard('Completed', '$_completedOrders', Icons.check_circle_rounded, AdminTheme.emerald)),
        const SizedBox(width: 10),
        Expanded(child: _miniCard('Cancelled', '$_cancelledOrders', Icons.cancel_rounded, AdminTheme.rose)),
      ]),
    ]);
  }

  Widget _miniCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AdminTheme.cardDecoration(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(title, textAlign: TextAlign.center, style: AdminTheme.label(10)),
      ]),
    );
  }

  // ── Users & Employees ────────────────────────────────────────────
  Widget _usersEmployeesRow() {
    return Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AdminTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Users', style: AdminTheme.heading(13)),
          const SizedBox(height: 12),
          _employeeRow('Total Users', _totalUsers, AdminTheme.accent, Icons.people_rounded),
          _employeeRow('New Today', _newUsersToday, AdminTheme.emerald, Icons.person_add_rounded),
          _employeeRow('This Week', _newUsersWeek, AdminTheme.gold, Icons.date_range_rounded),
        ]),
      )),
      const SizedBox(width: 12),
      Expanded(child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AdminTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Team', style: AdminTheme.heading(13)),
          const SizedBox(height: 12),
          _employeeRow('Delivery', _totalDelivery, AdminTheme.gold, Icons.delivery_dining_rounded),
          _employeeRow('Online Now', _onlineAgents, AdminTheme.emerald, Icons.circle),
          _employeeRow('Staff', _totalStaff, AdminTheme.accent, Icons.badge_rounded),
          _employeeRow('Managers', _totalManagers, AdminTheme.violet, Icons.manage_accounts_rounded),
        ]),
      )),
    ]);
  }

  Widget _employeeRow(String label, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: AdminTheme.label(12))),
        Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }

  // ── Revenue chart ────────────────────────────────────────────────
  Widget _revenueChart() {
    final maxRev = _monthlyData.isEmpty ? 1.0
        : _monthlyData.map((e) => e['revenue'] as double).reduce(math.max).clamp(1.0, double.infinity);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration(glow: true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Monthly Revenue', style: AdminTheme.heading(14)),
            Text('Last 6 months performance', style: AdminTheme.label(11)),
          ])),
          Row(children: [
            _chartToggle('bar', Icons.bar_chart_rounded),
            const SizedBox(width: 6),
            _chartToggle('line', Icons.show_chart_rounded),
          ]),
        ]),
        const SizedBox(height: 24),
        SizedBox(height: 180, child: _chartType == 'bar' ? _barChart(maxRev) : _lineChart(maxRev)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _monthlyData.map((e) => Text(e['month'], style: AdminTheme.label(11))).toList()),
      ]),
    );
  }

  Widget _barChart(double maxRev) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _monthlyData.asMap().entries.map((entry) {
        final e = entry.value;
        final rev = (e['revenue'] as double);
        final h = (rev / maxRev) * 160;
        final isLast = entry.key == _monthlyData.length - 1;
        final color = isLast ? AdminTheme.emerald : AdminTheme.emerald.withValues(alpha: 0.45);
        return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('₹${_fmtNum(rev)}', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 3),
          Container(
            width: 34, height: h.clamp(4.0, 160.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.4)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
        ]);
      }).toList(),
    );
  }

  Widget _lineChart(double maxRev) {
    return CustomPaint(
      painter: _LineChartPainter(data: _monthlyData.map((e) => e['revenue'] as double).toList(), maxVal: maxRev),
      size: const Size(double.infinity, 180),
    );
  }

  // ── Order funnel ─────────────────────────────────────────────────
  Widget _orderFunnel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration(),
      child: Column(children: [
        _funnelRow('📋 Orders Placed', _totalOrders, _totalOrders, AdminTheme.gold),
        _funnelRow('🔄 Active/Processing', _activeOrders, _totalOrders, AdminTheme.accent),
        _funnelRow('✅ Delivered', _completedOrders, _totalOrders, AdminTheme.emerald),
        _funnelRow('❌ Cancelled', _cancelledOrders, _totalOrders, AdminTheme.rose),
      ]),
    );
  }

  Widget _funnelRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: AdminTheme.label(12))),
          Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 6),
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.7))),
        ]),
        const SizedBox(height: 5),
        Stack(children: [
          Container(height: 8, decoration: BoxDecoration(color: AdminTheme.cardBorder, borderRadius: BorderRadius.circular(4))),
          AnimatedFractionallySizedBox(
            widthFactor: pct, duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic,
            child: Container(height: 8, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.5)]),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)],
            )),
          ),
        ]),
      ]),
    );
  }

  // ── Service revenue bars ──────────────────────────────────────────
  Widget _serviceRevenue() {
    if (_revenueByService.isEmpty) {
      return Container(padding: const EdgeInsets.all(20), decoration: AdminTheme.cardDecoration(),
        child: Center(child: Text('No completed orders yet', style: AdminTheme.label(13))));
    }
    final maxSvc = _revenueByService.values.reduce(math.max).clamp(1.0, double.infinity);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _revenueByService.entries.toList().asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final color = AdminTheme.chartPalette[i % AdminTheme.chartPalette.length];
          final pct = (e.value / maxSvc).clamp(0.0, 1.0);
          final cnt = _countByService[e.key] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key.toUpperCase(), style: AdminTheme.label(12))),
                Text('$cnt orders', style: AdminTheme.label(11)),
                const SizedBox(width: 8),
                Text('₹${_fmtNum(e.value)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              ]),
              const SizedBox(height: 6),
              Stack(children: [
                Container(height: 9, decoration: BoxDecoration(color: AdminTheme.cardBorder, borderRadius: BorderRadius.circular(5))),
                AnimatedFractionallySizedBox(widthFactor: pct, duration: const Duration(milliseconds: 900),
                  child: Container(height: 9, decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.5)]),
                    borderRadius: BorderRadius.circular(5),
                  ))),
              ]),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Payment methods ───────────────────────────────────────────────
  Widget _paymentMethodsCard() {
    if (_paymentMethods.isEmpty) {
      return Container(padding: const EdgeInsets.all(20), decoration: AdminTheme.cardDecoration(),
        child: Center(child: Text('No payment data yet', style: AdminTheme.label(13))));
    }
    final total = _paymentMethods.values.fold(0, (s, v) => s + v);
    final colors = [AdminTheme.gold, AdminTheme.accent, AdminTheme.emerald, AdminTheme.violet, AdminTheme.rose];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        children: _paymentMethods.entries.toList().asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final pct = total > 0 ? e.value / total : 0.0;
          final color = colors[i % colors.length];
          final label = e.key == 'online' ? 'Online (UPI/Card)' :
                        e.key == 'cod' ? 'Cash on Delivery' : e.key.toUpperCase();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(label, style: AdminTheme.label(12))),
                  Text('${e.value} orders · ${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ]),
                const SizedBox(height: 4),
                Stack(children: [
                  Container(height: 6, decoration: BoxDecoration(color: AdminTheme.cardBorder, borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))),
                ]),
              ])),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Top customers ─────────────────────────────────────────────────
  Widget _topCustomersCard() {
    if (_topCustomers.isEmpty) {
      return Container(padding: const EdgeInsets.all(20), decoration: AdminTheme.cardDecoration(),
        child: Center(child: Text('No customer data yet', style: AdminTheme.label(13))));
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        children: _topCustomers.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          final medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Text(medals[i], style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AdminTheme.accent.withValues(alpha: 0.4), AdminTheme.accent.withValues(alpha: 0.2)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text((c['name'] as String).isNotEmpty ? (c['name'] as String)[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AdminTheme.textPrimary))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
                Text('${c['orders']} orders', style: AdminTheme.label(11)),
              ])),
              Text('₹${_fmtNum(c['spent'] as double)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AdminTheme.emerald)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Recent orders list ────────────────────────────────────────────
  Widget _recentOrdersList() {
    if (_recentOrders.isEmpty) {
      return Container(padding: const EdgeInsets.all(20), decoration: AdminTheme.cardDecoration(),
        child: Center(child: Text('No orders yet', style: AdminTheme.label(13))));
    }
    return Container(
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        children: _recentOrders.asMap().entries.map((entry) {
          final i = entry.key;
          final o = entry.value;
          final st = (o['status'] ?? 'pending').toString();
          final amt = ((o['totalAmount'] ?? o['total'] ?? 0) as num).toDouble();
          final name = (o['customerName'] ?? 'Customer').toString();
          final statusColor = _statusColor(st);
          return Column(children: [
            if (i > 0) Divider(color: AdminTheme.cardBorder, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
                  Text('#${(o['id'] as String).substring(0, 8).toUpperCase()}', style: AdminTheme.label(10)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${_fmtNum(amt)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(st.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
                  ),
                ]),
              ]),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  // ── Monthly volume bars ───────────────────────────────────────────
  Widget _monthlyVolumeChart() {
    if (_monthlyData.isEmpty) return const SizedBox.shrink();
    final maxCnt = _monthlyData.map((e) => e['orders'] as int).reduce(math.max).clamp(1, 999999);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _monthlyData.map((e) {
              final cnt = (e['orders'] as int).toDouble();
              final h = (cnt / maxCnt) * 90;
              return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${e['orders']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AdminTheme.textSecondary)),
                const SizedBox(height: 3),
                Container(
                  width: 26, height: h.clamp(4.0, 90.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [AdminTheme.violet, Color(0xFF5B21B6)]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(e['month'], style: AdminTheme.label(10)),
              ]);
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _chartToggle(String type, IconData icon) {
    final active = _chartType == type;
    return GestureDetector(
      onTap: () => setState(() => _chartType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: active ? AdminTheme.gold.withValues(alpha: 0.2) : AdminTheme.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AdminTheme.gold : AdminTheme.cardBorder)),
        child: Icon(icon, color: active ? AdminTheme.gold : AdminTheme.textSecondary, size: 15),
      ),
    );
  }

  Color _statusColor(String st) {
    switch (st.toLowerCase()) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'assigned': case 'pickup': return AdminTheme.accent;
      case 'processing': return AdminTheme.violet;
      case 'out_for_delivery': case 'delivery': return AdminTheme.gold;
      case 'delivered': case 'completed': return AdminTheme.emerald;
      case 'cancelled': return AdminTheme.rose;
      default: return AdminTheme.textSecondary;
    }
  }

  String _fmtNum(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final double maxVal;
  _LineChartPainter({required this.data, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final w = size.width, h = size.height;
    final xStep = w / (data.length - 1);

    final linePaint = Paint()
      ..color = AdminTheme.emerald ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = AdminTheme.emerald ..style = PaintingStyle.fill;
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = h - (data[i] / maxVal.clamp(1, double.infinity)) * h * 0.9;
      if (i == 0) { path.moveTo(x, y); fillPath.moveTo(x, h); fillPath.lineTo(x, y); }
      else { path.lineTo(x, y); fillPath.lineTo(x, y); }
    }
    fillPath.lineTo((data.length - 1) * xStep, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [AdminTheme.emerald.withValues(alpha: 0.3), AdminTheme.emerald.withValues(alpha: 0)])
        .createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = h - (data[i] / maxVal.clamp(1, double.infinity)) * h * 0.9;
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = AdminTheme.surface);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => true;
}
