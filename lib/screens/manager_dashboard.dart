import 'auth_options_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import '../services/panel_theme_service.dart';

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
        _db
            .collection('orders')
            .where('status', whereIn: [
              'assigned',
              'accepted',
              'pickup',
              'processing',
              'out_for_delivery',
              'reached',
              'picked'
            ])
            .count()
            .get(),
        _db
            .collection('orders')
            .where('status', whereIn: ['delivered', 'completed'])
            .where('deliveredAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .count()
            .get(),
        _db
            .collection('delivery_agents')
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
    return PanelThemeScope(
      panelKey: 'manager',
      child: Builder(
        builder: (ctx) {
          final lt = DynTheme.of(ctx);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              backgroundColor: lt.bg,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(ctx, name),
                    _buildStatsRow(ctx),
                    _buildTabBar(ctx),
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
                              'assigned',
                              'accepted',
                              'pickup',
                              'processing',
                              'out_for_delivery',
                              'reached',
                              'picked'
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
        },
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(BuildContext themedContext, String name) {
    final lt = DynTheme.of(themedContext);
    return Container(
      decoration: BoxDecoration(
        gradient: DynTheme.headerGradient,
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
                  const LinearGradient(colors: [DynTheme.gold, DynTheme.goldSoft]),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                    color: DynTheme.gold.withValues(alpha: 0.35),
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
                Text(
                  'Branch Manager',
                  style: TextStyle(fontSize: 12, color: lt.textMid),
                ),
              ],
            ),
          ),
          const LGoldBadge(
              label: 'MANAGER', icon: Icons.manage_accounts_rounded),
          const SizedBox(width: 8),
          _iconBtn(Icons.refresh_rounded, _load),
          const SizedBox(width: 6),
          // Dark mode toggle — affects only Manager panel
          Builder(builder: (ctx) {
            PanelThemeService? pt;
            try { pt = PanelThemeScope.of(ctx); } catch (_) {}
            if (pt == null) return const SizedBox.shrink();
            return _iconBtn(
              pt.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              () => pt!.toggle(),
            );
          }),
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
  Widget _buildStatsRow(BuildContext themedContext) {
    if (_loading) {
      return Container(
        color: DynTheme.navy,
        height: 78,
        child: const Center(
          child: CircularProgressIndicator(color: DynTheme.gold, strokeWidth: 2),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: DynTheme.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Row(
        children: [
          _statChip(themedContext, 'Pending', '$_pendingOrders', DynTheme.amber,
              Icons.pending_actions_rounded),
          _statChip(themedContext, 'Active', '$_activeOrders', DynTheme.blueSoft,
              Icons.local_shipping_rounded),
          _statChip(themedContext, 'Done Today', '$_completedToday', DynTheme.emerald,
              Icons.check_circle_rounded),
          _statChip(
              themedContext,
              'Online', '$_staffOnline', DynTheme.gold, Icons.person_rounded),
        ],
      ),
    );
  }

  Widget _statChip(BuildContext themedContext, String label, String val, Color color, IconData icon) {
    final lt = DynTheme.of(themedContext);
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
                    fontSize: 17, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: lt.textMid,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────
  Widget _buildTabBar(BuildContext themedContext) {
    final lt = DynTheme.of(themedContext);
    return Container(
      color: lt.bg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: lt.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lt.cardBdr),
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
            gradient:
                const LinearGradient(colors: [DynTheme.gold, DynTheme.goldSoft]),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                  color: DynTheme.gold.withValues(alpha: 0.4), blurRadius: 8),
            ],
          ),
          labelColor: DynTheme.navy,
          unselectedLabelColor: lt.textMid,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          unselectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: [
            _tab('Pending', Icons.pending_actions_rounded, DynTheme.amber, 0),
            _tab('Active', Icons.local_shipping_rounded, DynTheme.blueSoft, 1),
            _tab('Completed', Icons.check_circle_rounded, DynTheme.emerald, 2),
            _tab('Staff', Icons.badge_outlined, DynTheme.violet, 3),
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
          Icon(icon, size: 14, color: active ? DynTheme.navy : color),
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
            child:
                CircularProgressIndicator(color: DynTheme.gold, strokeWidth: 2),
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
            color: DynTheme.gold,
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
    // Stream all 3 employee collections and merge them
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _CombinedEmployeeStream(db).stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(color: DynTheme.gold, strokeWidth: 2),
          );
        }
        final allEmployees = snap.data ?? [];
        if (allEmployees.isEmpty) {
          return const LEmptyState(
            title: 'No staff found',
            sub: 'Add employees from the admin panel',
            icon: Icons.badge_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: allEmployees.length,
          itemBuilder: (_, i) {
            final lt = DynTheme.of(context);
            final d = allEmployees[i];
            final role = d['role'] ?? 'staff';
            final online = d['isOnline'] ?? d['isActive'] ?? false;
            final color = role == 'delivery' ? DynTheme.gold : DynTheme.violet;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: lt.cardBox(),
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
                            style: lt.heading(14)),
                        const SizedBox(height: 3),
                        Text(
                          d['phone'] ?? d['email'] ?? '',
                          style: lt.label(12),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          _pill(
                            '${d['completedOrders'] ?? 0} done',
                            DynTheme.emerald,
                            Icons.check_circle_outline_rounded,
                          ),
                          const SizedBox(width: 6),
                          _pill(
                            online ? 'Online' : 'Offline',
                            online ? DynTheme.emerald : lt.textDim,
                            online ? Icons.circle : Icons.circle_outlined,
                          ),
                        ]),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showAssignTaskSheet(
                              context, allEmployees[i]['id'] as String? ?? '', d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.25)),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.assignment_rounded,
                                  color: color, size: 12),
                              const SizedBox(width: 4),
                              Text('Assign Job',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            ]),
                          ),
                        ),
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

  void _showAssignTaskSheet(
      BuildContext context, String staffId, Map<String, dynamic> staffData) {
    final lt = DynTheme.of(context);
    final taskCtrl = TextEditingController();
    bool isLoading = false;
    final name = staffData['name'] ?? 'Staff';
    final color = (staffData['role'] ?? 'staff') == 'delivery'
        ? DynTheme.gold
        : DynTheme.violet;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: lt.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: lt.cardBdr,
                        borderRadius: BorderRadius.circular(2))),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child:
                        Icon(Icons.assignment_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assign Task', style: lt.heading(17)),
                        Text('To: $name', style: lt.label(13)),
                      ]),
                ]),
                const SizedBox(height: 20),
                TextField(
                  controller: taskCtrl,
                  maxLines: 3,
                  style: TextStyle(color: lt.textHi, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'Describe the task (e.g. Process order #ABC123, wash 5 shirts...)',
                    hintStyle:
                        TextStyle(color: lt.textDim, fontSize: 13),
                    filled: true,
                    fillColor: lt.bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: lt.cardBdr)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: lt.cardBdr)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: DynTheme.gold, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: DynTheme.navy,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (taskCtrl.text.trim().isEmpty) return;
                            setLocal(() => isLoading = true);
                            try {
                              await db.collection('staff_tasks').add({
                                'assignedTo': staffId,
                                'staffName': name,
                                'task': taskCtrl.text.trim(),
                                'status': 'assigned',
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              await db.collection('staff').doc(staffId).update({
                                'activeOrders': FieldValue.increment(1),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                              // Notify the staff member
                              final taskBody = 'Manager assigned you a new task: "${taskCtrl.text.trim()}"';
                              await db.collection('notifications').add({
                                'userId': staffId,
                                'title': '📋 New Task Assigned',
                                'message': taskBody,
                                'body': taskBody,
                                'type': 'task_assigned',
                                'isRead': false,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              if (ctx2.mounted) Navigator.pop(ctx2);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('✓ Task assigned to $name'),
                                  backgroundColor: DynTheme.emerald,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.all(16),
                                ));
                              }
                            } catch (e) {
                              setLocal(() => isLoading = false);
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: DynTheme.navy))
                        : const Text('ASSIGN TASK',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
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
        .collection('delivery_agents')
        .where('isActive', isEqualTo: true)
        .get();
    if (!mounted) return;

    final agents = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

    if (agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No delivery agents available'),
        backgroundColor: DynTheme.rose,
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
            await widget.db.collection('orders').doc(widget.orderId).update({
              'status': 'assigned',
              'assignedTo': agent['id'],
              'driverId': agent['id'],        // delivery_dashboard queries by driverId
              'driverName': agent['name'] ?? 'Driver',
              'driverPhone': agent['phone'] ?? '',
              'assignedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'statusHistory': FieldValue.arrayUnion([{
                'status': 'assigned',
                'note': 'Assigned by manager to ${agent['name'] ?? 'Driver'}',
                'timestamp': DateTime.now().toIso8601String(),
              }]),
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('✓ Assigned to ${agent['name'] ?? 'Driver'}'),
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
              ));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lt = DynTheme.of(context);
    final ts = (widget.data['createdAt'] as Timestamp?)?.toDate();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: lt.cardBox(
          borderColor: _color.withValues(alpha: 0.22),
          glow: _status == 'pending'),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(18),
                  bottom: _expanded ? Radius.zero : const Radius.circular(18),
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
                    child: Icon(lStatusIcon(_status), color: _color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data['customerName'] ?? 'Customer',
                          style: lt.heading(14),
                        ),
                        Text(
                          '#${widget.orderId.substring(0, 8).toUpperCase()}  •  ${widget.data['serviceType'] ?? 'Laundry'}',
                          style: lt.label(11),
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
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: lt.textHi),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
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
                  _detailRow(
                      Icons.location_on_outlined,
                      widget.data['pickupAddress'] ??
                          widget.data['address'] ??
                          'N/A'),
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
                      valueColor: DynTheme.gold,
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
                          colors: [DynTheme.gold, DynTheme.goldSoft]),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: DynTheme.gold.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delivery_dining_rounded,
                            color: DynTheme.navy, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Assign Delivery Agent',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: DynTheme.navy,
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

  Widget _detailRow(IconData icon, String text, {Color? valueColor}) {
    final lt = DynTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 13, color: lt.textDim),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? lt.textMid,
              fontWeight:
                  valueColor != null ? FontWeight.w700 : FontWeight.w500,
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
    final lt = DynTheme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: lt.card,
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
              color: lt.cardBdr,
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
                  color: DynTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delivery_dining_rounded,
                    color: DynTheme.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Assign Agent', style: lt.heading(17)),
                Text('Select a delivery agent', style: lt.label(13)),
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
                    decoration: lt.cardBox(
                        borderColor: online
                            ? DynTheme.emerald.withValues(alpha: 0.3)
                            : null),
                    child: Row(children: [
                      Stack(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: DynTheme.gold.withValues(alpha: 0.1),
                          child: Text(
                            (a['name'] as String? ?? 'D')[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: DynTheme.gold),
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
                                style: lt.heading(14)),
                            Text(a['phone'] ?? '', style: lt.label(12)),
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
                                color: online ? DynTheme.emerald : lt.textDim,
                              ),
                            ),
                            Text(
                              '${a['completedOrders'] ?? 0} orders',
                              style: TextStyle(
                                  fontSize: 10, color: lt.textDim),
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

// ── Helper: combines delivery_agents + managers + staff into a single stream ─
class _CombinedEmployeeStream {
  final FirebaseFirestore _db;
  _CombinedEmployeeStream(this._db);

  Stream<List<Map<String, dynamic>>> get stream {
    final s1 = _db.collection('delivery_agents').snapshots();
    final s2 = _db.collection('managers').snapshots();
    final s3 = _db.collection('staff').snapshots();
    return _Merge3Stream(s1, s2, s3);
  }
}

class _Merge3Stream extends Stream<List<Map<String, dynamic>>> {
  final Stream<QuerySnapshot> s1, s2, s3;
  _Merge3Stream(this.s1, this.s2, this.s3);

  @override
  StreamSubscription<List<Map<String, dynamic>>> listen(
    void Function(List<Map<String, dynamic>>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    QuerySnapshot? last1, last2, last3;

    void emit(StreamController<List<Map<String, dynamic>>>? ctrl) {
      if (last1 == null || last2 == null || last3 == null) return;
      final list = <Map<String, dynamic>>[];
      for (final snap in [last1!, last2!, last3!]) {
        for (final doc in snap.docs) {
          list.add({'id': doc.id, ...(doc.data() as Map<String, dynamic>)});
        }
      }
      list.sort((a, b) =>
          (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
      ctrl?.add(list);
    }

    final ctrl = StreamController<List<Map<String, dynamic>>>();
    s1.listen((q) { last1 = q; emit(ctrl); });
    s2.listen((q) { last2 = q; emit(ctrl); });
    s3.listen((q) { last3 = q; emit(ctrl); });

    return ctrl.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
