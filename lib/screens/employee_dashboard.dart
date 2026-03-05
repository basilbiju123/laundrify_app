import 'auth_options_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _tabCtrl = TabController(length: 2, vsync: this);
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

      // Employee stats
      if (next == 'delivered' && uid != null) {
        batch.update(_db.collection('users').doc(uid), {
          'completedOrders': FieldValue.increment(1),
          'activeOrders': FieldValue.increment(-1),
        });
      }
      await batch.commit();

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
              stream: _db.collection('users').doc(uid).snapshots(),
              builder: (ctx, snap) {
                final lt = DynTheme.of(context);
                final isActive =
                    (snap.data?.data() as Map<String, dynamic>?)?[
                            'isActive'] ??
                        true;
                return GestureDetector(
                  onTap: () => _db
                      .collection('users')
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
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('orders')
          .where('assignedTo', isEqualTo: uid)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        final active = docs
            .where((d) => !['delivered', 'cancelled']
                .contains((d.data() as Map)['status']))
            .length;
        final done = docs
            .where((d) =>
                (d.data() as Map)['status'] == 'delivered')
            .length;
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
            _statCard('${docs.length}', 'Total', DynTheme.blueSoft,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_actions_rounded, size: 15),
                  SizedBox(width: 6),
                  Text('Active Orders'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 15),
                  SizedBox(width: 6),
                  Text('Completed'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Orders List ──────────────────────────────────────────────
  Widget _orderList(String uid, {required bool active}) {
    final stream = active
        ? _db
            .collection('orders')
            .where('assignedTo', isEqualTo: uid)
            .where('status', whereIn: [
              'assigned',
              'accepted',
              'pickup',
              'picked',
              'reached',
              'processing',
              'ready',
              'out_for_delivery',
              'pending',
            ])
            .snapshots()
        : _db
            .collection('orders')
            .where('assignedTo', isEqualTo: uid)
            .where('status', isEqualTo: 'delivered')
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
