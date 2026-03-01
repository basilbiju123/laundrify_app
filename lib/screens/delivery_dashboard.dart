import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

// ═══════════════════════════════════════════════════════════
// DELIVERY DESIGN TOKENS — Gold + Dark Navy (matches app theme)
// ═══════════════════════════════════════════════════════════
class DD {
  static const Color bg = Color(0xFFF0F4FF);
  static const Color surface = Color(0xFFF8FAFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF1B4FD8);
  static const Color pLight = Color(0xFFEEF2FF); // blue tint dark
  static const Color success = Color(0xFF10B981);
  static const Color sLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color wLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFEF4444);
  static const Color dLight = Color(0xFFFEF2F2);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleL = Color(0xFFF5F3FF);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanL = Color(0xFFECFEFF);
  static const Color gold = Color(0xFFF5C518);
  static const Color goldL = Color(0xFFFEFCE8);
  static const Color textD = Color(0xFF0A1628);
  static const Color textM = Color(0xFF475569);
  static const Color textG = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE8EDF5);

  static BoxDecoration cardDeco(
          {Color? borderColor, bool glow = false, Color? color}) =>
      BoxDecoration(
        color: color ?? const Color(0xFF111F35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: borderColor ?? border, width: borderColor != null ? 1.5 : 1),
        boxShadow: glow
            ? [
                BoxShadow(
                    color: gold.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ]
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      );

  static TextStyle h(double s, {Color? c, FontWeight? w}) => TextStyle(
        fontSize: s,
        fontWeight: w ?? FontWeight.w800,
        color: c ?? const Color(0xFFF1F5F9),
        letterSpacing: -0.3,
      );
  static TextStyle t(double s, {Color? c}) => TextStyle(
        fontSize: s,
        fontWeight: FontWeight.w600,
        color: c ?? const Color(0xFF94A3B8),
      );
  static TextStyle cap(double s) => const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569));
}

// ─── Shared helpers ───────────────────────────────────────
Color _sColor(String s) {
  switch (s) {
    case 'assigned':
      return DD.warning;
    case 'accepted':
      return DD.primary;
    case 'reached':
      return DD.purple;
    case 'picked':
      return DD.cyan;
    case 'out_for_delivery':
      return DD.warning;
    case 'delivered':
      return DD.success;
    case 'completed':
      return DD.success;
    case 'rejected':
      return DD.danger;
    default:
      return DD.textG;
  }
}

IconData _sIcon(String s) {
  switch (s) {
    case 'assigned':
      return Icons.assignment_rounded;
    case 'accepted':
      return Icons.thumb_up_rounded;
    case 'reached':
      return Icons.location_on_rounded;
    case 'picked':
      return Icons.local_laundry_service_rounded;
    case 'out_for_delivery':
      return Icons.delivery_dining_rounded;
    case 'delivered':
      return Icons.done_all_rounded;
    case 'completed':
      return Icons.verified_rounded;
    case 'rejected':
      return Icons.cancel_rounded;
    default:
      return Icons.circle_outlined;
  }
}

String _sLabel(String s) {
  switch (s) {
    case 'assigned':
      return 'Assigned';
    case 'accepted':
      return 'Accepted';
    case 'reached':
      return 'Reached';
    case 'picked':
      return 'Picked Up';
    case 'out_for_delivery':
      return 'Out for Delivery';
    case 'delivered':
      return 'Delivered';
    case 'completed':
      return 'Completed';
    case 'rejected':
      return 'Rejected';
    default:
      return s;
  }
}

String _nextStatus(String s) {
  switch (s) {
    case 'assigned':
      return 'accepted';
    case 'accepted':
      return 'reached';
    case 'reached':
      return 'picked';
    case 'picked':
      return 'out_for_delivery';
    case 'out_for_delivery':
      return 'delivered';
    case 'delivered':
      return 'completed';
    default:
      return s;
  }
}

String _nextLabel(String s) {
  switch (s) {
    case 'assigned':
      return 'Accept';
    case 'accepted':
      return 'Mark Reached';
    case 'reached':
      return 'Mark Picked';
    case 'picked':
      return 'Out for Delivery';
    case 'out_for_delivery':
      return 'Mark Delivered';
    case 'delivered':
      return 'Complete';
    default:
      return 'Update';
  }
}

final _flowSteps = [
  'assigned',
  'accepted',
  'reached',
  'picked',
  'out_for_delivery',
  'delivered',
  'completed'
];

Widget _chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );

Widget _emptyState(String title, String sub, IconData icon, Color color) =>
    Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 36)),
          const SizedBox(height: 16),
          Text(title, style: DD.h(16)),
          const SizedBox(height: 6),
          Text(sub, style: DD.cap(13), textAlign: TextAlign.center),
        ]),
      ),
    );

// ═══════════════════════════════════════════════════════════
// MAIN DELIVERY DASHBOARD — Bottom Nav
// ═══════════════════════════════════════════════════════════
class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});
  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DD.bg,
      body: IndexedStack(
        index: _idx,
        children: const [
          _HomeTab(),
          _OrdersTab(),
          _EarningsTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        current: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Orders'),
      (
        Icons.account_balance_wallet_rounded,
        Icons.account_balance_wallet_outlined,
        'Earnings'
      ),
      (Icons.person_rounded, Icons.person_outlined, 'Profile'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A2E),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = current == i;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: active
                          ? const LinearGradient(
                              colors: [Color(0xFFF5C518), Color(0xFFFDE68A)])
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(active ? item.$1 : item.$2,
                          color: active
                              ? const Color(0xFF080F1E)
                              : const Color(0xFF475569),
                          size: 22),
                      const SizedBox(height: 4),
                      Text(item.$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? const Color(0xFF080F1E)
                                : const Color(0xFF475569),
                          )),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HOME TAB
// ═══════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  bool _online = false, _toggling = false;
  String _driverName = '';

  @override
  void initState() {
    super.initState();
    _initDriver();
  }

  Future<void> _initDriver() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        await _db.collection('users').doc(uid).set({
          'name': _auth.currentUser?.displayName ?? 'Driver',
          'phone': _auth.currentUser?.phoneNumber ?? '',
          'email': _auth.currentUser?.email ?? '',
          'isOnline': false,
          'rating': 5.0,
          'totalDeliveries': 0,
          'vehicleNo': '',
          'earnings': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        if (mounted) {
          setState(() {
            _online = doc.data()?['isOnline'] ?? false;
            _driverName = doc.data()?['name'] ??
                _auth.currentUser?.displayName ??
                'Driver';
          });
        }
      }
    } catch (e) {
      debugPrint('Driver init error: $e');
    }
  }

  Future<void> _toggleOnline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _toggling) return;
    setState(() => _toggling = true);
    try {
      final newStatus = !_online;
      await _db.collection('users').doc(uid).update(
          {'isOnline': newStatus, 'lastSeen': FieldValue.serverTimestamp()});
      if (mounted) setState(() => _online = newStatus);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    final name = _driverName.isNotEmpty
        ? _driverName
        : (_auth.currentUser?.displayName ?? 'Driver');
    final h = DateTime.now().hour;
    final greeting = h < 12
        ? 'Good morning'
        : h < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: DD.bg,
      body: RefreshIndicator(
        color: DD.primary,
        onRefresh: _initDriver,
        child: CustomScrollView(
          slivers: [
            // ─── HEADER ───────────────────────────────────
            SliverToBoxAdapter(
                child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Color(0xFF080F1E),
                  Color(0xFF0D1F3C),
                  Color(0xFF0A1628)
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Row(children: [
                      // Gold avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFF5C518), Color(0xFFFDE68A)]),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFF5C518)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: Center(
                            child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'D',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF080F1E)),
                        )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(greeting,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF94A3B8))),
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF1F5F9))),
                          ])),
                      // Online Toggle
                      GestureDetector(
                        onTap: _toggleOnline,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: _online
                                ? const Color(0xFF10B981)
                                    .withValues(alpha: 0.15)
                                : const Color(0xFF1C2F4A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _online
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.4)
                                    : const Color(0xFF1C2F4A)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _toggling
                                ? const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF10B981)))
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: _online
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF475569),
                                        shape: BoxShape.circle)),
                            const SizedBox(width: 7),
                            Text(_online ? 'Online' : 'Offline',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _online
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF94A3B8))),
                          ]),
                        ),
                      ),
                    ]),
                  )),
            )),

            // ─── STATS CARD (lifted) ───────────────────────
            SliverToBoxAdapter(
                child: Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: uid == null
                    ? const SizedBox()
                    : StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('orders')
                            .where('driverId', isEqualTo: uid)
                            .snapshots(),
                        builder: (ctx, snap) {
                          if (!snap.hasData) return const SizedBox(height: 80);
                          final docs = snap.data!.docs;
                          final today = DateTime.now();
                          int assigned = 0, completed = 0;
                          double earnings = 0;
                          for (final d in docs) {
                            final data = d.data() as Map<String, dynamic>;
                            if (data['status'] == 'assigned') assigned++;
                            final ts = data['completedAt'] as Timestamp?;
                            if (ts != null && data['status'] == 'completed') {
                              final dt = ts.toDate();
                              if (dt.year == today.year &&
                                  dt.month == today.month &&
                                  dt.day == today.day) {
                                completed++;
                                earnings +=
                                    (data['deliveryFee'] ?? 50.0).toDouble();
                              }
                            }
                          }
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: DD.cardDeco(),
                            child: Row(children: [
                              _miniStat('Assigned', assigned.toString(),
                                  Icons.assignment_rounded, DD.warning),
                              Container(width: 1, height: 44, color: DD.border),
                              _miniStat('Completed', completed.toString(),
                                  Icons.check_circle_rounded, DD.success),
                              Container(width: 1, height: 44, color: DD.border),
                              _miniStat('Earned', '₹${earnings.toInt()}',
                                  Icons.currency_rupee_rounded, DD.primary),
                            ]),
                          );
                        },
                      ),
              ),
            )),

            // ─── NEW ASSIGNMENTS ─────────────────────────
            SliverToBoxAdapter(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('New Assignments', style: DD.h(16)),
                    TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AssignedOrdersPage())),
                      child: const Text('See All',
                          style: TextStyle(
                              color: DD.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  ]),
            )),

            uid == null
                ? const SliverToBoxAdapter(child: SizedBox())
                : StreamBuilder<QuerySnapshot>(
                    stream: _db
                        .collection('orders')
                        .where('driverId', isEqualTo: uid)
                        .where('status', isEqualTo: 'assigned')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) {
                        return const SliverToBoxAdapter(
                            child: SizedBox(
                                height: 80,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: DD.primary))));
                      }
                      if (snap.data!.docs.isEmpty) {
                        return SliverToBoxAdapter(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _emptyState(
                              'No new assignments',
                              'New orders will appear here',
                              Icons.assignment_outlined,
                              DD.warning),
                        ));
                      }
                      return SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                        final doc = snap.data!.docs[i];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _OrderCard(
                              orderId: doc.id,
                              data: doc.data() as Map<String, dynamic>),
                        );
                      }, childCount: snap.data!.docs.length));
                    },
                  ),

            // ─── ACTIVE ORDERS ────────────────────────────
            SliverToBoxAdapter(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Text('Active Orders', style: DD.h(16)),
            )),

            uid == null
                ? const SliverToBoxAdapter(child: SizedBox())
                : StreamBuilder<QuerySnapshot>(
                    stream: _db
                        .collection('orders')
                        .where('driverId', isEqualTo: uid)
                        .where('status', whereIn: [
                      'accepted',
                      'reached',
                      'picked',
                      'out_for_delivery'
                    ]).snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) {
                        return const SliverToBoxAdapter(child: SizedBox());
                      }
                      if (snap.data!.docs.isEmpty) {
                        return SliverToBoxAdapter(
                            child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          child: _emptyState(
                              'No active orders',
                              'Active orders appear here',
                              Icons.local_shipping_outlined,
                              DD.primary),
                        ));
                      }
                      return SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                        final doc = snap.data!.docs[i];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _OrderCard(
                              orderId: doc.id,
                              data: doc.data() as Map<String, dynamic>),
                        );
                      }, childCount: snap.data!.docs.length));
                    },
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) =>
      Expanded(
          child: Column(children: [
        Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 6),
        Text(value, style: DD.h(17)),
        Text(label, style: DD.cap(11)),
      ]));
}

// ═══════════════════════════════════════════════════════════
// ORDER CARD — used everywhere
// ═══════════════════════════════════════════════════════════
class _OrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  const _OrderCard({required this.orderId, required this.data});
  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  final _db = FirebaseFirestore.instance;
  bool _loading = false;

  Future<void> _update(String newStatus) async {
    setState(() => _loading = true);
    try {
      final upd = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (newStatus == 'completed' || newStatus == 'delivered') {
        upd['completedAt'] = FieldValue.serverTimestamp();
      }
      await _db.collection('orders').doc(widget.orderId).update(upd);
      // Also notify via notifications collection
      await _db.collection('notifications').add({
        'title': 'Order ${_sLabel(newStatus)}',
        'message':
            'Order #${widget.orderId.substring(0, 6).toUpperCase()} status updated to ${_sLabel(newStatus)}',
        'targetGroup': 'users',
        'orderId': widget.orderId,
        'userId': widget.data['userId'] ?? widget.data['customerId'] ?? '',
        'type': 'order_update',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      if (mounted) _snack('Status: ${_sLabel(newStatus)}', false);
    } catch (e) {
      if (mounted) _snack('Error: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      await _db.collection('orders').doc(widget.orderId).update({
        'status': 'pending',
        'driverId': null,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _snack('Order rejected', false);
    } catch (e) {
      if (mounted) _snack('Error: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _call() async {
    final phone = widget.data['customerPhone'] ?? '';
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _maps() async {
    final d = widget.data;
    final status = d['status'] ?? '';
    final addr = (status == 'picked' || status == 'out_for_delivery')
        ? (d['deliveryAddress'] ?? d['pickupAddress'] ?? '')
        : (d['pickupAddress'] ?? '');
    if (addr.isEmpty) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication);
    }
  }

  void _snack(String msg, bool err) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: err ? DD.danger : DD.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status = d['status'] ?? 'assigned';
    final type = d['type'] ?? 'pickup';
    final sColor = _sColor(status);
    final isPickup = type == 'pickup';
    final canProgress =
        !['delivered', 'completed', 'rejected'].contains(status);

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  OrderDetailPage(orderId: widget.orderId, initialData: d))),
      child: Container(
        decoration: DD.cardDeco(borderColor: sColor.withValues(alpha: 0.25)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: sColor.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(_sIcon(status), color: sColor, size: 14)),
              const SizedBox(width: 8),
              Text('#${widget.orderId.substring(0, 8).toUpperCase()}',
                  style: DD.t(13, c: DD.textD)),
              const Spacer(),
              _chip(_sLabel(status), sColor),
              const SizedBox(width: 6),
              _chip(isPickup ? 'Pickup' : 'Delivery',
                  isPickup ? DD.primary : DD.purple),
            ]),
          ),

          // BODY
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.person_rounded, size: 15, color: DD.textG),
                const SizedBox(width: 6),
                Text(d['customerName'] ?? 'Customer', style: DD.t(13)),
              ]),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                    isPickup
                        ? Icons.my_location_rounded
                        : Icons.location_on_rounded,
                    size: 15,
                    color: DD.textG),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(
                  isPickup
                      ? (d['pickupAddress'] ?? 'N/A')
                      : (d['deliveryAddress'] ?? 'N/A'),
                  style: DD.cap(12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
              if (d['scheduledTime'] != null) ...[
                const SizedBox(height: 5),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: DD.textG),
                  const SizedBox(width: 6),
                  Text(d['scheduledTime'] ?? '', style: DD.cap(11)),
                ]),
              ],
              const SizedBox(height: 12),

              // ACTIONS
              if (status == 'assigned') ...[
                Row(children: [
                  Expanded(
                      child: _btn('Reject', DD.danger, DD.dLight,
                          _loading ? null : _reject)),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 2,
                      child: _btn('Accept Order', DD.success, DD.sLight,
                          _loading ? null : () => _update('accepted'))),
                ]),
              ] else if (canProgress) ...[
                Row(children: [
                  Expanded(
                      child: _outlineBtn(Icons.call_rounded, 'Call', _call)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _outlineBtn(
                          Icons.navigation_rounded, 'Navigate', _maps)),
                  const SizedBox(width: 6),
                  Expanded(
                      flex: 2,
                      child: _btn(
                          _nextLabel(status),
                          DD.primary,
                          DD.pLight,
                          _loading
                              ? null
                              : () => _update(_nextStatus(status)))),
                ]),
              ],

              if (_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                      color: sColor,
                      backgroundColor: sColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _btn(String label, Color color, Color bg, VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color))),
        ),
      );

  Widget _outlineBtn(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: DD.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DD.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 13, color: DD.primary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DD.primary)),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// ORDERS TAB
// ═══════════════════════════════════════════════════════════
class _OrdersTab extends StatefulWidget {
  const _OrdersTab();
  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late TabController _tabCtrl;

  final _tabs = ['Active', 'Assigned', 'Delivery', 'Completed'];
  final _statusGroups = [
    ['accepted', 'reached', 'picked', 'out_for_delivery'],
    ['assigned'],
    ['out_for_delivery'],
    ['delivered', 'completed'],
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    return Scaffold(
      backgroundColor: DD.bg,
      appBar: AppBar(
        backgroundColor: DD.white,
        elevation: 0,
        title: Text('My Orders', style: DD.h(19)),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: DD.primary,
          unselectedLabelColor: DD.textG,
          indicatorColor: DD.primary,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: List.generate(_tabs.length, (i) {
          if (uid == null) return const Center(child: Text('Not logged in'));
          return StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('orders')
                .where('driverId', isEqualTo: uid)
                .where('status', whereIn: _statusGroups[i])
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: DD.primary));
              }
              if (snap.data!.docs.isEmpty) {
                return _emptyState('No ${_tabs[i].toLowerCase()} orders',
                    'Orders appear here', Icons.inbox_rounded, DD.primary);
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snap.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, j) {
                  final doc = snap.data!.docs[j];
                  return _OrderCard(
                      orderId: doc.id,
                      data: doc.data() as Map<String, dynamic>);
                },
              );
            },
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// EARNINGS TAB
// ═══════════════════════════════════════════════════════════
class _EarningsTab extends StatelessWidget {
  const _EarningsTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: DD.bg,
      appBar: AppBar(
        backgroundColor: DD.white,
        elevation: 0,
        title: Text('My Earnings', style: DD.h(19)),
      ),
      body: uid == null
          ? _emptyState(
              'Not logged in', '', Icons.person_outline_rounded, DD.primary)
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('driverId', isEqualTo: uid)
                  .where('status', whereIn: ['delivered', 'completed'])
                  .orderBy('completedAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: DD.primary));
                }
                final docs = snap.data!.docs;
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final weekStart = now.subtract(Duration(days: now.weekday - 1));

                double total = 0, today = 0, week = 0;
                int todayCount = 0;

                for (final doc in docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  final fee = (d['deliveryFee'] ?? 50.0).toDouble();
                  final ts = (d['completedAt'] as Timestamp?)?.toDate();
                  total += fee;
                  if (ts != null) {
                    if (ts.isAfter(todayStart)) {
                      today += fee;
                      todayCount++;
                    }
                    if (ts.isAfter(weekStart)) week += fee;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    // Big card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [
                              Color(0xFFF5C518),
                              Color(0xFFFDE68A),
                              Color(0xFFF5C518)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: DD.gold.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: Column(children: [
                        const Text('Total Earnings',
                            style: TextStyle(
                                color: Color(0xFF7A6210),
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('₹${total.toInt()}',
                            style: const TextStyle(
                                color: Color(0xFF080F1E),
                                fontSize: 44,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('${docs.length} completed deliveries',
                            style: const TextStyle(
                                color: Color(0xFF4A3C08), fontSize: 13)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      _earningCard('Today', '₹${today.toInt()}',
                          '$todayCount orders', DD.success, DD.sLight),
                      const SizedBox(width: 12),
                      _earningCard('This Week', '₹${week.toInt()}',
                          'Weekly total', DD.warning, DD.wLight),
                    ]),
                    const SizedBox(height: 20),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Recent History', style: DD.h(16))),
                    const SizedBox(height: 12),
                    if (docs.isEmpty)
                      _emptyState(
                          'No earnings yet',
                          'Complete deliveries to earn',
                          Icons.account_balance_wallet_outlined,
                          DD.primary)
                    else
                      ...docs.take(30).map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final ts = (d['completedAt'] as Timestamp?)?.toDate();
                        final fee = (d['deliveryFee'] ?? 50.0).toDouble();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: DD.cardDeco(),
                          child: Row(children: [
                            Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                    color: DD.sLight, shape: BoxShape.circle),
                                child: const Icon(Icons.check_circle_rounded,
                                    color: DD.success, size: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      '#${doc.id.substring(0, 8).toUpperCase()}',
                                      style: DD.t(13)),
                                  Text(d['customerName'] ?? 'Customer',
                                      style: DD.cap(12)),
                                  if (ts != null)
                                    Text('${ts.day}/${ts.month}/${ts.year}',
                                        style: DD.cap(11)),
                                ])),
                            Text('₹${fee.toInt()}',
                                style: DD.h(15, c: DD.success)),
                          ]),
                        );
                      }),
                  ]),
                );
              },
            ),
    );
  }

  Widget _earningCard(
          String label, String value, String sub, Color color, Color bg) =>
      Expanded(
          child: Container(
        padding: const EdgeInsets.all(16),
        decoration:
            DD.cardDeco(borderColor: color.withValues(alpha: 0.2), color: bg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: DD.cap(12)),
          const SizedBox(height: 4),
          Text(value, style: DD.h(20, c: color)),
          Text(sub, style: DD.cap(11)),
        ]),
      ));
}

// ═══════════════════════════════════════════════════════════
// PROFILE TAB
// ═══════════════════════════════════════════════════════════
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _driver;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (mounted) {
        setState(() {
          _driver = doc.data();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final name = _driver?['name'] ?? user?.displayName ?? 'Driver';
    final phone = _driver?['phone'] ?? user?.phoneNumber ?? 'Not set';
    final vehicle = _driver?['vehicleNo'] ?? 'Not set';
    final rating = (_driver?['rating'] ?? 5.0).toDouble();
    final deliveries = _driver?['totalDeliveries'] ?? 0;

    return Scaffold(
      backgroundColor: DD.bg,
      appBar: AppBar(
          backgroundColor: DD.white,
          elevation: 0,
          title: Text('My Profile', style: DD.h(19))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DD.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Profile card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: DD.cardDeco(),
                  child: Column(children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFF5C518), Color(0xFFFDE68A)]),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFF5C518)
                                  .withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Center(
                          child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'D',
                              style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF080F1E)))),
                    ),
                    const SizedBox(height: 16),
                    Text(name, style: DD.h(20)),
                    const SizedBox(height: 4),
                    Text(phone, style: DD.cap(14)),
                    const SizedBox(height: 14),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFBBF24), size: 18),
                      const SizedBox(width: 4),
                      Text('${rating.toStringAsFixed(1)} rating',
                          style: DD.t(13)),
                      const SizedBox(width: 16),
                      const Icon(Icons.local_shipping_rounded,
                          color: DD.primary, size: 18),
                      const SizedBox(width: 4),
                      Text('$deliveries trips', style: DD.t(13)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // Info
                Container(
                  decoration: DD.cardDeco(),
                  child: Column(children: [
                    _infoRow(Icons.directions_car_rounded, 'Vehicle Number',
                        vehicle),
                    _divider(),
                    _infoRow(
                        Icons.email_rounded, 'Email', user?.email ?? 'N/A'),
                    _divider(),
                    _infoRow(Icons.badge_rounded, 'Driver ID',
                        (user?.uid ?? '').substring(0, 8).toUpperCase()),
                  ]),
                ),
                const SizedBox(height: 16),

                // Actions
                Container(
                  decoration: DD.cardDeco(),
                  child: Column(children: [
                    _actionRow(
                        Icons.history_rounded,
                        'Delivery History',
                        DD.primary,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DeliveryHistoryPage()))),
                    _divider(),
                    _actionRow(Icons.help_outline_rounded, 'Help & Support',
                        DD.primary, () {}),
                    _divider(),
                    _actionRow(
                        Icons.logout_rounded, 'Logout', DD.danger, _logout),
                  ]),
                ),
              ]),
            ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56, color: DD.border);

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: DD.pLight, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: DD.primary, size: 17)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: DD.cap(11)),
                Text(value, style: DD.t(14)),
              ])),
        ]),
      );

  Widget _actionRow(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 17)),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: DD.t(14, c: color))),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: DD.textG),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// ORDER DETAIL PAGE — Full timeline + status update
// ═══════════════════════════════════════════════════════════
class OrderDetailPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> initialData;
  const OrderDetailPage(
      {super.key, required this.orderId, required this.initialData});
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _db = FirebaseFirestore.instance;
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await _db.collection('orders').doc(widget.orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (['delivered', 'completed'].contains(newStatus))
          'completedAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('notifications').add({
        'title': 'Order ${_sLabel(newStatus)}',
        'message':
            'Your order #${widget.orderId.substring(0, 6).toUpperCase()} is now ${_sLabel(newStatus)}',
        'userId': widget.initialData['userId'] ?? widget.initialData['customerId'] ?? '',
        'orderId': widget.orderId,
        'type': 'order_update',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: DD.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _call(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _maps(String address) async {
    if (address.isEmpty) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('orders').doc(widget.orderId).snapshots(),
      builder: (ctx, snap) {
        final d =
            (snap.data?.data() as Map<String, dynamic>?) ?? widget.initialData;
        final status = d['status'] ?? 'assigned';
        final sColor = _sColor(status);
        final curIdx = _flowSteps.indexOf(status);
        final hasNext = curIdx >= 0 && curIdx < _flowSteps.length - 1;

        return Scaffold(
          backgroundColor: DD.bg,
          appBar: AppBar(
            backgroundColor: DD.white,
            elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: DD.textD),
                onPressed: () => Navigator.pop(context)),
            title: Text(
                'Order #${widget.orderId.substring(0, 8).toUpperCase()}',
                style: DD.h(16)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // STATUS BANNER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: DD.cardDeco(
                    borderColor: sColor.withValues(alpha: 0.3),
                    color: sColor.withValues(alpha: 0.05)),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: sColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle),
                      child: Icon(_sIcon(status), color: sColor, size: 24)),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Status', style: DD.cap(12)),
                        Text(_sLabel(status), style: DD.h(16, c: sColor)),
                      ]),
                ]),
              ),
              const SizedBox(height: 16),

              // TIMELINE
              Container(
                padding: const EdgeInsets.all(16),
                decoration: DD.cardDeco(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Timeline', style: DD.t(14)),
                      const SizedBox(height: 14),
                      ...List.generate(_flowSteps.length, (i) {
                        final s = _flowSteps[i];
                        final done = curIdx >= i;
                        final active = curIdx == i;
                        final c = done ? _sColor(s) : DD.border;
                        return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                      color: done ? c : DD.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: c, width: 2)),
                                  child: done
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 12)
                                      : null,
                                ),
                                if (i < _flowSteps.length - 1)
                                  Container(
                                      width: 2,
                                      height: 26,
                                      color: done
                                          ? c.withValues(alpha: 0.35)
                                          : DD.border),
                              ]),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(_sLabel(s),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: active
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: active
                                            ? c
                                            : (done ? DD.textM : DD.textG))),
                              ),
                            ]);
                      }),
                    ]),
              ),
              const SizedBox(height: 16),

              // CUSTOMER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: DD.cardDeco(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer Details', style: DD.t(14)),
                      const SizedBox(height: 12),
                      _detailRow(Icons.person_rounded, 'Name',
                          d['customerName'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      GestureDetector(
                          onTap: () => _call(d['customerPhone'] ?? ''),
                          child: _detailRow(Icons.call_rounded, 'Phone',
                              d['customerPhone'] ?? 'N/A',
                              color: DD.primary)),
                      const SizedBox(height: 8),
                      GestureDetector(
                          onTap: () => _maps(d['pickupAddress'] ?? ''),
                          child: _detailRow(Icons.my_location_rounded,
                              'Pickup Address', d['pickupAddress'] ?? 'N/A',
                              color: DD.primary)),
                      const SizedBox(height: 8),
                      GestureDetector(
                          onTap: () => _maps(d['deliveryAddress'] ?? ''),
                          child: _detailRow(Icons.location_on_rounded,
                              'Delivery Address', d['deliveryAddress'] ?? 'N/A',
                              color: DD.primary)),
                    ]),
              ),
              const SizedBox(height: 16),

              // ORDER DETAILS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: DD.cardDeco(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Info', style: DD.t(14)),
                      const SizedBox(height: 12),
                      _detailRow(
                          Icons.category_rounded,
                          'Service Type',
                          (d['serviceType'] ?? d['type'] ?? 'N/A')
                              .toUpperCase()),
                      const SizedBox(height: 8),
                      _detailRow(Icons.inventory_2_rounded, 'Order Type',
                          (d['type'] ?? 'N/A').toUpperCase()),
                      const SizedBox(height: 8),
                      _detailRow(Icons.currency_rupee_rounded, 'Order Amount',
                          '₹${d['totalAmount'] ?? 0}'),
                      const SizedBox(height: 8),
                      _detailRow(Icons.delivery_dining_rounded, 'Delivery Fee',
                          '₹${d['deliveryFee'] ?? 50}'),
                    ]),
              ),

              if (hasNext && !['delivered', 'completed'].contains(status)) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () => _updateStatus(_nextStatus(status)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Mark as ${_sLabel(_nextStatus(status))}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ]),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
          {Color? color}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color ?? DD.textG),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: DD.cap(11)),
                Text(value, style: DD.t(13, c: color ?? DD.textD)),
              ])),
        ],
      );
}

// ═══════════════════════════════════════════════════════════
// ASSIGNED ORDERS PAGE
// ═══════════════════════════════════════════════════════════
class AssignedOrdersPage extends StatelessWidget {
  const AssignedOrdersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: DD.bg,
      appBar: AppBar(
        backgroundColor: DD.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: DD.textD),
            onPressed: () => Navigator.pop(context)),
        title: Text('Assigned Orders', style: DD.h(19)),
      ),
      body: uid == null
          ? _emptyState(
              'Not logged in', '', Icons.person_outline_rounded, DD.primary)
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('driverId', isEqualTo: uid)
                  .where('status', isEqualTo: 'assigned')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: DD.primary));
                }
                if (snap.data!.docs.isEmpty) {
                  return _emptyState(
                      'No assigned orders',
                      'New assignments appear here',
                      Icons.assignment_outlined,
                      DD.warning);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: snap.data!.docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final doc = snap.data!.docs[i];
                    return _OrderCard(
                        orderId: doc.id,
                        data: doc.data() as Map<String, dynamic>);
                  },
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// DELIVERY HISTORY PAGE
// ═══════════════════════════════════════════════════════════
class DeliveryHistoryPage extends StatelessWidget {
  const DeliveryHistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: DD.bg,
      appBar: AppBar(
        backgroundColor: DD.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: DD.textD),
            onPressed: () => Navigator.pop(context)),
        title: Text('Delivery History', style: DD.h(19)),
      ),
      body: uid == null
          ? _emptyState(
              'Not logged in', '', Icons.person_outline_rounded, DD.primary)
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('driverId', isEqualTo: uid)
                  .where('status', whereIn: ['delivered', 'completed'])
                  .orderBy('completedAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: DD.primary));
                }
                if (snap.data!.docs.isEmpty) {
                  return _emptyState(
                      'No history yet',
                      'Completed deliveries appear here',
                      Icons.history_rounded,
                      DD.primary);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: snap.data!.docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final doc = snap.data!.docs[i];
                    final d = doc.data() as Map<String, dynamic>;
                    final ts = (d['completedAt'] as Timestamp?)?.toDate();
                    final fee = (d['deliveryFee'] ?? 50.0).toDouble();
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: DD.cardDeco(),
                      child: Row(children: [
                        Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                                color: DD.sLight,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.check_circle_rounded,
                                color: DD.success, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('#${doc.id.substring(0, 8).toUpperCase()}',
                                  style: DD.t(13)),
                              Text(d['customerName'] ?? 'Customer',
                                  style: DD.cap(12)),
                              if (ts != null)
                                Text(
                                    '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                                    style: DD.cap(11)),
                            ])),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${fee.toInt()}',
                                  style: DD.h(14, c: DD.success)),
                              const SizedBox(height: 4),
                              _chip(_sLabel(d['status'] ?? 'completed'),
                                  DD.success),
                            ]),
                      ]),
                    );
                  },
                );
              },
            ),
    );
  }
}
