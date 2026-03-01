import 'auth_options_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

// ═══════════════════════════════════════════════════════════════════
// MANAGER DASHBOARD — Complete with order assignment, staff mgmt,
// revenue analytics, and real-time Firestore streams.
// ═══════════════════════════════════════════════════════════════════

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late TabController _tabCtrl;

  int _pendingOrders = 0,
      _activeOrders = 0,
      _completedToday = 0,
      _staffOnline = 0;
  bool _loading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) {
          setState(() => _selectedTab = _tabCtrl.index);
        }
      });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final results = await Future.wait([
        _db
            .collection('orders')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        _db.collection('orders').where('status', whereIn: [
          'assigned',
          'accepted',
          'pickup',
          'processing',
          'out_for_delivery',
          'reached',
          'picked'
        ]).count().get(),
        _db
            .collection('orders')
            .where('status', whereIn: ['delivered', 'completed'])
            .where('deliveredAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .count()
            .get(),
        _db
            .collection('users')
            .where('role', isEqualTo: 'delivery')
            .where('isOnline', isEqualTo: true)
            .count()
            .get(),
      ]);

      if (mounted) {
        setState(() {
          _pendingOrders = results[0].count ?? 0;
          _activeOrders = results[1].count ?? 0;
          _completedToday = results[2].count ?? 0;
          _staffOnline = results[3].count ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final name = user?.displayName ?? 'Manager';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: LTheme.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(name),
              _buildStatsRow(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _OrdersTab(
                      db: _db,
                      statuses: const ['pending'],
                      label: 'pending',
                      emptyIcon: Icons.pending_actions_outlined,
                    ),
                    _OrdersTab(
                      db: _db,
                      statuses: const [
                        'assigned', 'accepted', 'pickup',
                        'processing', 'out_for_delivery',
                        'reached', 'picked'
                      ],
                      label: 'active',
                      emptyIcon: Icons.local_laundry_service_outlined,
                    ),
                    _OrdersTab(
                      db: _db,
                      statuses: const ['delivered', 'completed'],
                      label: 'completed',
                      emptyIcon: Icons.check_circle_outline_rounded,
                    ),
                    _StaffTab(db: _db),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LTheme.headerGradient,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [LTheme.gold, LTheme.goldSoft]),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                    color: LTheme.gold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'M',
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: LTheme.navy),
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
                const Text(
                  'Branch Manager',
                  style: TextStyle(fontSize: 12, color: LTheme.textMid),
                ),
              ],
            ),
          ),
          const LGoldBadge(
              label: 'MANAGER', icon: Icons.manage_accounts_rounded),
          const SizedBox(width: 8),
          _iconBtn(Icons.refresh_rounded, _load),
          const SizedBox(width: 6),
          _iconBtn(
            Icons.logout_rounded,
            () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthOptionsPage()),
                      (r) => false,
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );

  // ── Stats Row ────────────────────────────────────────────────
  Widget _buildStatsRow() {
    if (_loading) {
      return Container(
        color: LTheme.navy,
        height: 78,
        child: const Center(
          child: CircularProgressIndicator(color: LTheme.gold, strokeWidth: 2),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LTheme.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Row(
        children: [
          _statChip('Pending', '$_pendingOrders', LTheme.amber,
              Icons.pending_actions_rounded),
          _statChip('Active', '$_activeOrders', LTheme.blueSoft,
              Icons.local_shipping_rounded),
          _statChip('Done Today', '$_completedToday', LTheme.emerald,
              Icons.check_circle_rounded),
          _statChip('Online', '$_staffOnline', LTheme.gold,
              Icons.person_rounded),
        ],
      ),
    );
  }

  Widget _statChip(
      String label, String val, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 5),
            Text(val,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    color: LTheme.textMid,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: LTheme.bg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: LTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LTheme.cardBdr),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(5),
        child: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
                colors: [LTheme.gold, LTheme.goldSoft]),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                  color: LTheme.gold.withValues(alpha: 0.4), blurRadius: 8),
            ],
          ),
          labelColor: LTheme.navy,
          unselectedLabelColor: LTheme.textMid,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          unselectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: [
            _tab('Pending', Icons.pending_actions_rounded,
                LTheme.amber, 0),
            _tab('Active', Icons.local_shipping_rounded,
                LTheme.blueSoft, 1),
            _tab('Completed', Icons.check_circle_rounded,
                LTheme.emerald, 2),
            _tab('Staff', Icons.badge_outlined, LTheme.violet, 3),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, IconData icon, Color color, int idx) {
    final active = _selectedTab == idx;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14, color: active ? LTheme.navy : color),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}

// ── Orders Tab ────────────────────────────────────────────────────
class _OrdersTab extends StatelessWidget {
  final FirebaseFirestore db;
  final List<String> statuses;
  final String label;
  final IconData emptyIcon;

  const _OrdersTab({
    required this.db,
    required this.statuses,
    required this.label,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('orders')
          .where('status', whereIn: statuses)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: LTheme.gold, strokeWidth: 2),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return LEmptyState(
            title: 'No $label orders',
            sub: label == 'pending'
                ? 'New customer orders appear here'
                : label == 'active'
                    ? 'Orders in progress show here'
                    : 'Completed orders appear here',
            icon: emptyIcon,
            color: LTheme.gold,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            final doc = snap.data!.docs[i];
            return _MgrOrderCard(
              orderId: doc.id,
              data: doc.data() as Map<String, dynamic>,
              db: db,
              canAssign: label == 'pending',
            );
          },
        );
      },
    );
  }
}

// ── Staff Tab ─────────────────────────────────────────────────────
class _StaffTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _StaffTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('users')
          .where('role', whereIn: ['delivery', 'staff', 'employee'])
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: LTheme.gold, strokeWidth: 2),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const LEmptyState(
            title: 'No staff found',
            sub: 'Add employees from the admin panel',
            icon: Icons.badge_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            final d = snap.data!.docs[i].data() as Map<String, dynamic>;
            final role = d['role'] ?? 'staff';
            final online = d['isOnline'] ?? d['isActive'] ?? false;
            final color =
                role == 'delivery' ? LTheme.gold : LTheme.violet;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: LTheme.cardBox(),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Text(
                          (d['name'] as String? ?? 'E')[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: color),
                        ),
                      ),
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: LOnlineDot(online: online),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['name'] ?? 'Employee',
                            style: LTheme.heading(14)),
                        const SizedBox(height: 3),
                        Text(
                          d['phone'] ?? d['email'] ?? '',
                          style: LTheme.label(12),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          _pill(
                            '${d['completedOrders'] ?? 0} done',
                            LTheme.emerald,
                            Icons.check_circle_outline_rounded,
                          ),
                          const SizedBox(width: 6),
                          _pill(
                            online ? 'Online' : 'Offline',
                            online ? LTheme.emerald : LTheme.textDim,
                            online
                                ? Icons.circle
                                : Icons.circle_outlined,
                          ),
                        ]),
                      ],
                    ),
                  ),
                  LBadge(label: role, color: color, fontSize: 9),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _pill(String label, Color color, IconData icon) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      );
}

// ── Manager Order Card ────────────────────────────────────────────
class _MgrOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  final bool canAssign;
  const _MgrOrderCard({
    required this.orderId,
    required this.data,
    required this.db,
    this.canAssign = false,
  });

  @override
  State<_MgrOrderCard> createState() => _MgrOrderCardState();
}

class _MgrOrderCardState extends State<_MgrOrderCard> {
  bool _expanded = false;

  String get _status => widget.data['status'] ?? 'pending';
  Color get _color => lStatusColor(_status);

  Future<void> _assignDelivery() async {
    // Load delivery agents
    final snap = await widget.db
        .collection('users')
        .where('role', isEqualTo: 'delivery')
        .get();
    if (!mounted) return;

    final agents = snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList();

    if (agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No delivery agents available'),
        backgroundColor: LTheme.rose,
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignSheet(
        agents: agents,
        onAssign: (agent) async {
          try {
            await widget.db
                .collection('orders')
                .doc(widget.orderId)
                .update({
              'status': 'assigned',
              'assignedTo': agent['id'],
              'driverName': agent['name'] ?? 'Driver',
              'driverPhone': agent['phone'] ?? '',
              'assignedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '✓ Assigned to ${agent['name'] ?? 'Driver'}'),
                backgroundColor: LTheme.emerald,
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
                backgroundColor: LTheme.rose,
              ));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts =
        (widget.data['createdAt'] as Timestamp?)?.toDate();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: LTheme.cardBox(
          borderColor: _color.withValues(alpha: 0.22),
          glow: _status == 'pending'),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(18),
                  bottom: _expanded
                      ? Radius.zero
                      : const Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(lStatusIcon(_status),
                        color: _color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data['customerName'] ?? 'Customer',
                          style: LTheme.heading(14),
                        ),
                        Text(
                          '#${widget.orderId.substring(0, 8).toUpperCase()}  •  ${widget.data['serviceType'] ?? 'Laundry'}',
                          style: LTheme.label(11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LBadge(
                        label: _status.replaceAll('_', ' '),
                        color: _color,
                        fontSize: 9,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${((widget.data['total'] ?? widget.data['totalAmount'] ?? 0) as num).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: LTheme.textHi),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: LTheme.textDim,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (_expanded) ...[
            const LDivider(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _detailRow(Icons.phone_outlined,
                      widget.data['customerPhone'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _detailRow(Icons.location_on_outlined,
                      widget.data['pickupAddress'] ?? widget.data['address'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _detailRow(
                    Icons.schedule_rounded,
                    ts != null
                        ? '${ts.day}/${ts.month}/${ts.year}  ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                        : 'N/A',
                  ),
                  if (widget.data['driverName'] != null) ...[
                    const SizedBox(height: 8),
                    _detailRow(
                      Icons.delivery_dining_rounded,
                      'Assigned to ${widget.data['driverName']}',
                      valueColor: LTheme.gold,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.canAssign) ...[
              const LDivider(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: _assignDelivery,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [LTheme.gold, LTheme.goldSoft]),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: LTheme.gold.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delivery_dining_rounded,
                            color: LTheme.navy, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Assign Delivery Agent',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: LTheme.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: LTheme.textDim),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? LTheme.textMid,
              fontWeight: valueColor != null
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Assign Sheet ─────────────────────────────────────────────────
class _AssignSheet extends StatelessWidget {
  final List<Map<String, dynamic>> agents;
  final Function(Map<String, dynamic>) onAssign;
  const _AssignSheet({required this.agents, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: const BoxDecoration(
        color: LTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: LTheme.cardBdr,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delivery_dining_rounded,
                    color: LTheme.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Assign Agent', style: LTheme.heading(17)),
                Text('Select a delivery agent',
                    style: LTheme.label(13)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          const LDivider(),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: agents.length,
              itemBuilder: (_, i) {
                final a = agents[i];
                final online = a['isOnline'] ?? a['isActive'] ?? false;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onAssign(a);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: LTheme.cardBox(
                        borderColor: online
                            ? LTheme.emerald.withValues(alpha: 0.3)
                            : null),
                    child: Row(children: [
                      Stack(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              LTheme.gold.withValues(alpha: 0.1),
                          child: Text(
                            (a['name'] as String? ?? 'D')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: LTheme.gold),
                          ),
                        ),
                        Positioned(
                            bottom: 1,
                            right: 1,
                            child: LOnlineDot(online: online)),
                      ]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['name'] ?? 'Driver',
                                style: LTheme.heading(14)),
                            Text(a['phone'] ?? '',
                                style: LTheme.label(12)),
                          ],
                        ),
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              online ? 'Available' : 'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: online
                                    ? LTheme.emerald
                                    : LTheme.textDim,
                              ),
                            ),
                            Text(
                              '${a['completedOrders'] ?? 0} orders',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: LTheme.textDim),
                            ),
                          ]),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
