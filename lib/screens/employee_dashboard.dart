import 'auth_options_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import 'app_theme.dart';
import '../services/panel_theme_service.dart';

// ═══════════════════════════════════════════════════════════════════
// EMPLOYEE / LAUNDRY STAFF DASHBOARD
// Gold + Dark Navy  |  Real Firestore backend
// Features: Order status updates, stats, earnings, notifications
// ═══════════════════════════════════════════════════════════════════

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});
  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late TabController _tabCtrl;

  static const _nextStatus = {
    'confirmed': 'pickup',
    'pickup': 'processing',
    'processing': 'ready',
    'ready': 'out_for_delivery',
    'out_for_delivery': 'delivered',
  };
  static const _nextLabel = {
    'confirmed': 'Start Pickup',
    'pickup': 'Mark Collected',
    'processing': 'Mark Ready',
    'ready': 'Send for Delivery',
    'out_for_delivery': 'Mark Delivered ✓',
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String orderId, String cur) async {
    final next = _nextStatus[cur];
    if (next == null) return;
    final uid = _auth.currentUser?.uid;

    try {
      final batch = _db.batch();
      final orderRef = _db.collection('orders').doc(orderId);
      final update = <String, dynamic>{
        'status': next,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': next,
            'timestamp': Timestamp.now(),
            'updatedBy': uid,
            'note': _nextLabel[cur],
          }
        ]),
        if (next == 'delivered')
          'deliveredAt': FieldValue.serverTimestamp(),
      };
      batch.update(orderRef, update);

      // Customer notification
      final orderDoc = await orderRef.get();
      final customerId =
          orderDoc.data()?['userId'] ?? orderDoc.data()?['customerId'];
      if (customerId != null) {
        batch.set(_db.collection('notifications').doc(), {
          'title': _notifTitle(next),
          'message': _notifBody(next, orderId),
          'userId': customerId,
          'orderId': orderId,
          'type': 'order_update',
          'targetGroup': 'users',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      // Employee stats — update in /staff collection (employees are not in /users)
      if (next == 'delivered' && uid != null) {
        batch.update(_db.collection('staff').doc(uid), {
          'completedOrders': FieldValue.increment(1),
          'activeOrders': FieldValue.increment(-1),
        });
      }
      await batch.commit();

      // Fire local notification on employee's device
      NotificationService().showDeliveryNotification(
        title: 'Status Updated',
        body: 'Order #${orderId.substring(0, 6).toUpperCase()} → ${next.toUpperCase()}',
        orderId: orderId,
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Updated to ${next.replaceAll('_', ' ')}'),
          ]),
          backgroundColor: DynTheme.emerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: DynTheme.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lt = DynTheme.of(context);
    final user = _auth.currentUser;
    final uid = user?.uid;
    final name = user?.displayName ?? 'Staff';

    final content = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: lt.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(uid, name),
              _buildStatsRow(uid),
              const SizedBox(height: 10),
              _buildTabBar(),
              const SizedBox(height: 6),
              Expanded(
                child: uid == null
                    ? Center(
                        child: Text('Not logged in',
                            style: TextStyle(color: lt.textMid)))
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _orderList(uid, active: true),
                          _orderList(uid, active: false),
                          _staffScheduleTab(uid),
                          _staffProfileTab(uid),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    return PanelThemeScope(panelKey: 'employee', child: content);
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(String? uid, String name) {
    final lt = DynTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        gradient: DynTheme.headerGradient,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                Navigator.canPop(context) ? Navigator.pop(context) : null,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [DynTheme.gold, DynTheme.goldSoft]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: DynTheme.gold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: DynTheme.navy),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey, ${name.split(' ').first} 👋',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                Text('Laundry Staff',
                    style:
                        TextStyle(fontSize: 12, color: lt.textMid)),
              ],
            ),
          ),

          // Online toggle
          if (uid != null)
            StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('staff').doc(uid).snapshots(),
              builder: (ctx, snap) {
                final lt = DynTheme.of(context);
                final isActive =
                    (snap.data?.data() as Map<String, dynamic>?)?[
                            'isActive'] ??
                        true;
                return GestureDetector(
                  onTap: () => _db
                      .collection('staff')
                      .doc(uid)
                      .update({'isActive': !isActive}),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? DynTheme.emerald.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isActive
                              ? DynTheme.emerald.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? DynTheme.emerald
                                : lt.textDim,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isActive ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? DynTheme.emerald
                                : lt.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(width: 8),
          // Dark mode toggle — Employee panel only
          Builder(builder: (ctx) {
            PanelThemeService? pt;
            try { pt = PanelThemeScope.of(ctx); } catch (_) {}
            if (pt == null) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => pt!.toggle(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Icon(
                    pt.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: Colors.white, size: 18),
              ),
            );
          }),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthOptionsPage()),
                      (r) => false,
                    );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Row ────────────────────────────────────────────────
  Widget _buildStatsRow(String? uid) {
    if (uid == null) return const SizedBox(height: 8);
    // Read stats directly from the staff doc (maintained by order status updates)
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('staff').doc(uid).snapshots(),
      builder: (ctx, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final active = d['activeOrders'] as int? ?? 0;
        final done   = d['completedOrders'] as int? ?? 0;
        return Container(
          decoration: BoxDecoration(
            gradient: DynTheme.headerGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Row(children: [
            _statCard('$active', 'Active', DynTheme.gold,
                Icons.pending_actions_rounded),
            const SizedBox(width: 10),
            _statCard('$done', 'Delivered', DynTheme.emerald,
                Icons.check_circle_rounded),
            const SizedBox(width: 10),
            _statCard('${active + done}', 'Total', DynTheme.blueSoft,
                Icons.receipt_long_rounded),
          ]),
        );
      },
    );
  }

  Widget _statCard(
      String val, String label, Color color, IconData icon) {
    final lt = DynTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: lt.textMid,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────
  Widget _buildTabBar() {
    final lt = DynTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: lt.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lt.cardBdr),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8),
          ],
        ),
        child: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(
            gradient:
                const LinearGradient(colors: [DynTheme.gold, DynTheme.goldSoft]),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                  color: DynTheme.gold.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          labelColor: DynTheme.navy,
          unselectedLabelColor: lt.textMid,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.pending_actions_rounded, size: 15),
                SizedBox(width: 6),
                Text('Active'),
              ]),
            ),
            Tab(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline_rounded, size: 15),
                SizedBox(width: 6),
                Text('Done'),
              ]),
            ),
            Tab(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.calendar_today_rounded, size: 15),
                SizedBox(width: 6),
                Text('Schedule'),
              ]),
            ),
            Tab(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.person_outline_rounded, size: 15),
                SizedBox(width: 6),
                Text('Profile'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Orders List ──────────────────────────────────────────────
  // Staff (laundry workers) see all orders in the processing queue —
  // not just orders assigned to them by UID. This is the laundry task queue.
  Widget _orderList(String uid, {required bool active}) {
    final stream = active
        ? _db
            .collection('orders')
            .where('status', whereIn: [
              'assigned',
              'accepted',
              'pickup',
              'picked',
              'reached',
              'processing',
              'ready',
              'pending',
            ])
            .orderBy('createdAt', descending: false) // oldest first = FIFO queue
            .limit(30)
            .snapshots()
        : _db
            .collection('orders')
            .where('status', whereIn: ['delivered', 'completed'])
            .orderBy('createdAt', descending: true)
            .limit(30)
            .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: DynTheme.gold, strokeWidth: 2));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return LEmptyState(
            title: active ? 'No active orders' : 'No completed orders',
            sub: active
                ? 'New assignments will appear here'
                : 'Completed deliveries show here',
            icon: active
                ? Icons.inbox_outlined
                : Icons.check_circle_outline_rounded,
            color: active ? DynTheme.gold : DynTheme.emerald,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            final doc = snap.data!.docs[i];
            final d = doc.data() as Map<String, dynamic>;
            return _EmpOrderCard(
              orderId: doc.id,
              data: d,
              onUpdate: () =>
                  _updateStatus(doc.id, d['status'] ?? 'confirmed'),
              nextLabel: _nextLabel[d['status'] ?? 'confirmed'],
            );
          },
        );
      },
    );
  }

  String _notifTitle(String s) {
    switch (s) {
      case 'pickup':
        return '🚗 Pickup Scheduled';
      case 'processing':
        return '🧺 Being Cleaned';
      case 'ready':
        return '✅ Ready for Delivery';
      case 'out_for_delivery':
        return '🛵 Out for Delivery!';
      case 'delivered':
        return '🎉 Delivered!';
      default:
        return 'Order Update';
    }
  }

  String _notifBody(String s, String id) {
    final shortId =
        id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase();
    switch (s) {
      case 'pickup':
        return 'Our agent is heading for pickup #$shortId';
      case 'processing':
        return 'Your clothes are being cleaned professionally';
      case 'ready':
        return 'Order #$shortId is ready. Delivery coming soon!';
      case 'out_for_delivery':
        return 'Order #$shortId is on the way!';
      case 'delivered':
        return 'Order #$shortId delivered. Thank you! 🙏';
      default:
        return 'Your order #$shortId has been updated';
    }
  }

  String _fmtTs(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ── Schedule Tab ──────────────────────────────────────────────
  Widget _staffScheduleTab(String uid) {
    final lt = DynTheme.of(context);
    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final shifts = ['Morning (6am–2pm)', 'Evening (2pm–10pm)', 'Night (10pm–6am)'];
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('staff').doc(uid).snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final shift = data['shift'] as String? ?? 'Morning (6am–2pm)';
        final workDays = List<String>.from(data['workDays'] as List? ?? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
        final todayName = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][now.weekday - 1];
        final isWorkingToday = workDays.contains(todayName);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Today badge
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [DynTheme.navy, const Color(0xFF0D2145)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DynTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.today_rounded, color: DynTheme.gold, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Today — $todayName, ${now.day}/${now.month}/${now.year}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(isWorkingToday ? 'You are scheduled today' : 'Day off today',
                      style: TextStyle(
                        color: isWorkingToday ? DynTheme.gold : const Color(0xFF94A3B8),
                        fontSize: 16, fontWeight: FontWeight.w800,
                      )),
                  if (isWorkingToday) ...[
                    const SizedBox(height: 2),
                    Text('Shift: $shift', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isWorkingToday ? DynTheme.gold : const Color(0xFF94A3B8)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isWorkingToday ? 'WORKING' : 'OFF',
                      style: TextStyle(
                        color: isWorkingToday ? DynTheme.gold : const Color(0xFF94A3B8),
                        fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1,
                      )),
                ),
              ]),
            ),

            // Weekly calendar
            Text('This Week', style: TextStyle(color: lt.textMid, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: days.map((d) {
              final isWork = workDays.contains(d);
              final isToday = d == todayName;
              return Expanded(child: Container(
                margin: const EdgeInsets.only(right: 5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isToday
                      ? DynTheme.gold.withValues(alpha: 0.15)
                      : isWork
                          ? DynTheme.blue.withValues(alpha: 0.08)
                          : lt.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isToday ? DynTheme.gold : isWork ? DynTheme.blue.withValues(alpha: 0.3) : lt.cardBdr,
                  ),
                ),
                child: Column(children: [
                  Text(d, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: isToday ? DynTheme.gold : isWork ? DynTheme.blue : lt.textDim,
                  )),
                  const SizedBox(height: 5),
                  Icon(
                    isWork ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                    size: 14,
                    color: isToday ? DynTheme.gold : isWork ? DynTheme.blue : lt.textDim,
                  ),
                ]),
              ));
            }).toList()),

            const SizedBox(height: 20),

            // Shift info
            Text('Shift Details', style: TextStyle(color: lt.textMid, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...shifts.map((s) {
              final selected = s == shift;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? DynTheme.blue.withValues(alpha: 0.08) : lt.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? DynTheme.blue.withValues(alpha: 0.4) : lt.cardBdr),
                ),
                child: Row(children: [
                  Icon(Icons.schedule_rounded, size: 16, color: selected ? DynTheme.blue : lt.textDim),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: selected ? DynTheme.blue : lt.textMid,
                  ))),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: DynTheme.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('YOUR SHIFT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: DynTheme.blue)),
                    ),
                ]),
              );
            }),

            const SizedBox(height: 20),

            // Tasks assigned
            Text('Assigned Tasks', style: TextStyle(color: lt.textMid, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: _db.collection('staff_tasks')
                  .where('assignedTo', isEqualTo: uid)
                  .where('status', isEqualTo: 'pending')
                  .limit(10).snapshots(),
              builder: (ctx2, snap2) {
                if (!snap2.hasData || snap2.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: lt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: lt.cardBdr)),
                    child: Row(children: [
                      Icon(Icons.task_alt_rounded, color: DynTheme.emerald, size: 18),
                      const SizedBox(width: 10),
                      Text('No pending tasks assigned', style: TextStyle(color: lt.textMid, fontSize: 13)),
                    ]),
                  );
                }
                return Column(children: snap2.data!.docs.map((task) {
                  final t = task.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: lt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: lt.cardBdr)),
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: DynTheme.amber, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t['task'] ?? 'Task', style: TextStyle(color: lt.textHi, fontSize: 13, fontWeight: FontWeight.w600)),
                        if (t['note'] != null)
                          Text(t['note'], style: TextStyle(color: lt.textDim, fontSize: 11)),
                      ])),
                      TextButton(
                        onPressed: () async {
                          await _db.collection('staff_tasks').doc(task.id).update({'status': 'done'});
                        },
                        child: const Text('Done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  );
                }).toList());
              },
            ),
          ]),
        );
      },
    );
  }

  // ── Profile Tab ───────────────────────────────────────────────
  Widget _staffProfileTab(String uid) {
    final lt = DynTheme.of(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('staff').doc(uid).snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] as String? ?? 'Staff Member';
        final email = data['email'] as String? ?? '';
        final phone = data['phone'] as String? ?? '';
        final role = data['role'] as String? ?? 'staff';
        final joinedTs = data['createdAt'] as Timestamp?;
        final totalDone = data['totalCompleted'] ?? 0;
        final todayDone = data['todayCompleted'] ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Profile card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [DynTheme.navy, Color(0xFF0D2145)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: DynTheme.gold.withValues(alpha: 0.2),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: DynTheme.gold)),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DynTheme.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: DynTheme.gold.withValues(alpha: 0.4)),
                    ),
                    child: Text(role.toUpperCase(), style: const TextStyle(color: DynTheme.gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  if (joinedTs != null) ...[
                    const SizedBox(height: 4),
                    Text('Joined ${joinedTs.toDate().day}/${joinedTs.toDate().month}/${joinedTs.toDate().year}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ])),
              ]),
            ),
            const SizedBox(height: 16),

            // Performance stats
            Row(children: [
              Expanded(child: _perfCard('Today', '$todayDone', 'orders done', DynTheme.emerald)),
              const SizedBox(width: 10),
              Expanded(child: _perfCard('Total', '$totalDone', 'all time', DynTheme.blue)),
            ]),
            const SizedBox(height: 16),

            // Contact info
            Text('Contact Info', style: TextStyle(color: lt.textMid, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _infoRow(lt, Icons.email_outlined, 'Email', email.isNotEmpty ? email : 'Not set'),
            const SizedBox(height: 8),
            _infoRow(lt, Icons.phone_outlined, 'Phone', phone.isNotEmpty ? phone : 'Not set'),
            const SizedBox(height: 8),
            _infoRow(lt, Icons.badge_outlined, 'Employee ID', uid.substring(0, 8).toUpperCase()),

            const SizedBox(height: 20),

            // Notes section
            Text('Work Notes', style: TextStyle(color: lt.textMid, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: _db.collection('staff').doc(uid).collection('notes')
                  .orderBy('createdAt', descending: true).limit(5).snapshots(),
              builder: (ctx2, notesSnap) {
                final notes = notesSnap.data?.docs ?? [];
                if (notes.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: lt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: lt.cardBdr)),
                    child: Text('No notes yet. Notes from your manager will appear here.',
                        style: TextStyle(color: lt.textDim, fontSize: 12)),
                  );
                }
                return Column(children: notes.map((n) {
                  final nd = n.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: lt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: lt.cardBdr)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nd['note'] ?? '', style: TextStyle(color: lt.textHi, fontSize: 13)),
                      const SizedBox(height: 4),
                      if (nd['createdAt'] != null)
                        Text(_fmtTs(nd['createdAt'] as Timestamp),
                            style: TextStyle(color: lt.textDim, fontSize: 10)),
                    ]),
                  );
                }).toList());
              },
            ),
          ]),
        );
      },
    );
  }

  Widget _perfCard(String period, String val, String sub, Color color) {
    final lt = DynTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(period, style: TextStyle(color: lt.textDim, fontSize: 11)),
        Text(val, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900)),
        Text(sub, style: TextStyle(color: lt.textMid, fontSize: 11)),
      ]),
    );
  }

  Widget _infoRow(dynamic lt, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: lt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: lt.cardBdr)),
      child: Row(children: [
        Icon(icon, size: 16, color: lt.textDim),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: lt.textDim, fontSize: 10, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(color: lt.textHi, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }

}

// ── Employee Order Card ───────────────────────────────────────────
class _EmpOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final VoidCallback onUpdate;
  final String? nextLabel;

  const _EmpOrderCard({
    required this.orderId,
    required this.data,
    required this.onUpdate,
    this.nextLabel,
  });

  @override
  State<_EmpOrderCard> createState() => _EmpOrderCardState();
}

class _EmpOrderCardState extends State<_EmpOrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lt = DynTheme.of(context);
    final status = widget.data['status'] ?? 'confirmed';
    final color = lStatusColor(status);
    final isTerminal =
        status == 'delivered' || status == 'cancelled';
    final ts = (widget.data['createdAt'] as Timestamp?)?.toDate();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: lt.cardBox(
          borderColor: !isTerminal ? color.withValues(alpha: 0.3) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ──────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(18),
                  bottom:
                      _expanded ? Radius.zero : const Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(lStatusIcon(status),
                        color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data['customerName'] ?? 'Customer',
                          style: lt.heading(14),
                        ),
                        Text(
                          '#${widget.orderId.substring(0, 8).toUpperCase()}',
                          style: lt.label(11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LBadge(
                        label: status.replaceAll('_', ' '),
                        color: color,
                        fontSize: 9,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '₹${((widget.data['total'] ?? widget.data['totalAmount'] ?? 0) as num).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: lt.textHi,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: lt.textDim,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded Details ─────────────────────────────
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row(Icons.location_on_outlined,
                      widget.data['pickupAddress'] ??
                          widget.data['address'] ??
                          'N/A'),
                  const SizedBox(height: 6),
                  _row(Icons.phone_outlined,
                      widget.data['customerPhone'] ?? 'N/A'),
                  const SizedBox(height: 6),
                  _row(
                    Icons.currency_rupee_rounded,
                    '₹${((widget.data['total'] ?? widget.data['totalAmount'] ?? 0) as num).toStringAsFixed(0)}  •  ${widget.data['paymentMethod'] ?? 'Online'}',
                  ),
                  if (ts != null) ...[
                    const SizedBox(height: 6),
                    _row(
                      Icons.calendar_today_outlined,
                      '${ts.day}/${ts.month}/${ts.year}  ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
                    ),
                  ],
                  // Services
                  if (widget.data['services'] != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: lt.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: lt.cardBdr),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Services',
                              style: lt.label(11)),
                          const SizedBox(height: 6),
                          ...(widget.data['services'] as List)
                              .map((s) {
                            final lt = DynTheme.of(context);
                            final sName = s['serviceName'] ??
                                s['name'] ??
                                '';
                            final items = (s['items'] as List? ?? []);
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                const Icon(
                                    Icons.local_laundry_service_outlined,
                                    size: 12,
                                    color: DynTheme.gold),
                                const SizedBox(width: 6),
                                Text('$sName — ${items.length} items',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: lt.textHi)),
                              ]),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Action Button ────────────────────────────────
          if (!isTerminal && widget.nextLabel != null) ...[
            const LDivider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: widget.onUpdate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.75)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_rounded,
                          color: Colors.white, size: 17),
                      const SizedBox(width: 8),
                      Text(
                        widget.nextLabel!,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (isTerminal) ...[
            const LDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: DynTheme.emerald, size: 16),
                const SizedBox(width: 8),
                const Text('Completed',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DynTheme.emerald)),
                if (widget.data['deliveredAt'] != null) ...[
                  const Spacer(),
                  Text(
                    _fmtTs(widget.data['deliveredAt'] as Timestamp),
                    style: TextStyle(
                        fontSize: 11, color: lt.textDim),
                  ),
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    final lt = DynTheme.of(context);
    return Row(children: [
        Icon(icon, size: 13, color: lt.textDim),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, color: lt.textMid),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ]);
  }

  String _fmtTs(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}
