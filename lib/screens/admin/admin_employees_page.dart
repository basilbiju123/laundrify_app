import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/employee_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_theme.dart';
import '../../services/role_based_auth_service.dart';

class AdminEmployeesPage extends StatefulWidget {
  const AdminEmployeesPage({super.key});
  @override
  State<AdminEmployeesPage> createState() => _AdminEmployeesPageState();
}

class _AdminEmployeesPageState extends State<AdminEmployeesPage> {
  final _db = FirebaseFirestore.instance;
  String _filterRole = 'all';

  // ─── Maps each role to its dedicated Firestore collection ───────────────
  static const Map<String, String> _roleCollections = {
    'delivery': 'delivery_agents',
    'manager': 'managers',
    'staff': 'staff',
  };

  // ─── Stream: query role-specific collection(s) for the chosen filter ─────
  // Employees are ALWAYS in delivery_agents/managers/staff — NEVER in /users.
  // When filter == 'all', the build() method uses _AllEmployeesWidget.
  Stream<QuerySnapshot> get _employeeStream {
    final col = _roleCollections[_filterRole] ?? 'delivery_agents';
    return _db.collection(col).orderBy('createdAt', descending: true).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee Management', style: at.heading(20)),
              const SizedBox(height: 4),
              Text('Manage delivery agents, managers & staff',
                  style:
                      TextStyle(fontSize: 13, color: at.textSecondary)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GestureDetector(
                    onTap: () => _showAssignRoleByEmailSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: AdminTheme.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AdminTheme.gold.withValues(alpha: 0.3))),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.email_rounded,
                            color: AdminTheme.gold, size: 16),
                        SizedBox(width: 6),
                        Text('Assign by Email',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AdminTheme.gold)),
                      ]),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAddEmployeeSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: AdminTheme.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AdminTheme.emerald.withValues(alpha: 0.3))),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_rounded,
                            color: AdminTheme.emerald, size: 18),
                        SizedBox(width: 6),
                        Text('Add New Employee',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AdminTheme.emerald)),
                      ]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Collection indicator chip ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: _CollectionBadge(filterRole: _filterRole),
        ),

        // ROLE FILTER CHIPS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'delivery', 'manager', 'staff'].map((r) {
                final active = _filterRole == r;
                final c = r == 'delivery'
                    ? AdminTheme.gold
                    : r == 'manager'
                        ? AdminTheme.violet
                        : r == 'staff'
                            ? AdminTheme.amber
                            : at.textSecondary;
                return GestureDetector(
                  onTap: () => setState(() => _filterRole = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          active ? c.withValues(alpha: 0.2) : at.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: active ? c : at.cardBorder,
                          width: active ? 1.5 : 1),
                    ),
                    child: Text(r.toUpperCase(),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: active ? c : at.textSecondary)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: _filterRole == 'all'
              ? _AllEmployeesView(
                  onAddEmployee: () => _showAddEmployeeSheet(context),
                  onEmployeeDetails: _showEmployeeDetails,
                  onChangeRole: _showChangeRoleSheet,
                )
              : StreamBuilder<QuerySnapshot>(
            stream: _employeeStream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AdminTheme.gold, strokeWidth: 2));
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.badge_outlined,
                      color: at.textMuted, size: 56),
                  const SizedBox(height: 16),
                  Text('No employees found', style: at.heading(16)),
                  const SizedBox(height: 8),
                  GestureDetector(
                      onTap: () => _showAddEmployeeSheet(ctx),
                      child: const Text('Add first employee →',
                          style: TextStyle(
                              color: AdminTheme.gold,
                              fontWeight: FontWeight.w700))),
                ]));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                physics: const BouncingScrollPhysics(),
                itemCount: snap.data!.docs.length,
                itemBuilder: (_, i) {
                  final doc = snap.data!.docs[i];
                  final d = doc.data() as Map<String, dynamic>;
                  return _buildEmployeeCard(context, doc.id, d);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Employee card builder (used by single-role StreamBuilder and AllEmployeesView) ───
  Widget _buildEmployeeCard(BuildContext context, String docId, Map<String, dynamic> d) {
    final at = DynAdmin.of(context);
    final role = d['role'] ?? 'staff';
    final roleColor = role == 'delivery'
        ? AdminTheme.gold
        : role == 'manager'
            ? AdminTheme.violet
            : AdminTheme.amber;
    final activeOrders = d['activeOrders'] ?? 0;
    final completedOrders = d['completedOrders'] ?? 0;
    return GestureDetector(
      onTap: () => _showEmployeeDetails(context, docId, d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: at.cardDecoration(),
        child: Column(children: [
          Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: roleColor.withValues(alpha: 0.2),
                backgroundImage: d['photoURL'] != null ? NetworkImage(d['photoURL'] as String) : null,
                child: d['photoURL'] == null
                    ? Text((d['name'] as String? ?? 'E')[0].toUpperCase(),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: roleColor))
                    : null,
              ),
              Positioned(bottom: 0, right: 0,
                child: Container(width: 14, height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (d['isActive'] ?? true) ? AdminTheme.emerald : AdminTheme.rose,
                    border: Border.all(color: at.surface, width: 2),
                  ))),
            ]),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(d['name'] ?? 'Employee',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: at.textPrimary))),
                AdminBadge(label: role, color: roleColor, fontSize: 10),
              ]),
              const SizedBox(height: 4),
              Text(d['email'] ?? '', style: at.label(12)),
              const SizedBox(height: 4),
              Text(d['phone'] ?? '', style: at.label(11).copyWith(color: at.textMuted)),
            ])),
          ]),
          const SizedBox(height: 14),
          Container(height: 1, color: at.cardBorder),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statCol('Active', activeOrders.toString(), AdminTheme.amber),
            _divider(context),
            _statCol('Completed', completedOrders.toString(), AdminTheme.emerald),
            _divider(context),
            _statCol('Rating', '${(d['rating'] ?? 4.5).toStringAsFixed(1)}⭐', AdminTheme.gold),
          ]),
          const SizedBox(height: 12),
          Container(height: 1, color: at.cardBorder),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => _showChangeRoleSheet(context, docId, d['name'] ?? '', role),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: AdminTheme.violet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminTheme.violet.withValues(alpha: 0.2)),
                ),
                child: const Text('Change Role', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.violet)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: at.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('Remove ${d['name'] ?? 'employee'}?', style: at.heading(16)),
                    content: Text('This will remove them from employee records.', style: TextStyle(color: at.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remove', style: TextStyle(color: AdminTheme.rose))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await RoleBasedAuthService().removeRole(docId);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: AdminTheme.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminTheme.rose.withValues(alpha: 0.2)),
                ),
                child: const Text('Remove Role', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.rose)),
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  // ─── Employee details bottom sheet ──────────────────────────────────────
  void _showEmployeeDetails(BuildContext context, String uid, Map<String, dynamic> d) {
    final at = DynAdmin.of(context);
    final role = d['role'] ?? 'staff';
    final roleColor = role == 'delivery'
        ? AdminTheme.gold
        : role == 'manager'
            ? AdminTheme.violet
            : AdminTheme.amber;
    final name = d['name'] ?? 'Employee';
    final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final collection = _roleCollections[role] ?? 'users';

    showModalBottomSheet(
      context: context,
      backgroundColor: at.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: at.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: roleColor.withValues(alpha: 0.2),
                backgroundImage: d['photoURL'] != null ? NetworkImage(d['photoURL'] as String) : null,
                child: d['photoURL'] == null
                    ? Text(initials,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: roleColor))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: at.heading(20)),
                const SizedBox(height: 4),
                AdminBadge(label: role, color: roleColor),
              ])),
              // Show which collection this doc lives in
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminTheme.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminTheme.cyan.withValues(alpha: 0.3)),
                ),
                child: Text(
                  collection,
                  style: const TextStyle(fontSize: 10, color: AdminTheme.cyan, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Text('Contact Information', style: at.heading(14)),
            const SizedBox(height: 12),
            _detailRow(Icons.email_outlined, 'Email', d['email'] ?? '—'),
            _detailRow(Icons.phone_outlined, 'Phone', d['phone'] ?? '—'),
            _detailRow(Icons.location_on_outlined, 'Address', d['address'] ?? '—'),
            _detailRow(Icons.badge_outlined, 'Employee ID', d['employeeId'] ?? uid.substring(0, 8).toUpperCase()),
            const SizedBox(height: 20),
            Text('Performance', style: at.heading(14)),
            const SizedBox(height: 12),
            Row(children: [
              _perfTile('Active Orders', '${d['activeOrders'] ?? 0}', AdminTheme.amber),
              const SizedBox(width: 10),
              _perfTile('Completed', '${d['completedOrders'] ?? 0}', AdminTheme.emerald),
              const SizedBox(width: 10),
              _perfTile('Rating', '${(d['rating'] ?? 4.5).toStringAsFixed(1)} ⭐', AdminTheme.gold),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showChangeRoleSheet(context, uid, name, role);
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Change Role'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminTheme.violet,
                    side: BorderSide(color: AdminTheme.violet.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    final at = DynAdmin.of(context);
    return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: at.textMuted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: at.textSecondary),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: at.textMuted, fontWeight: FontWeight.w600)),
        Text(value, style: at.label(13).copyWith(color: at.textPrimary)),
      ])),
    ]),
  );
  }

  Widget _perfTile(String label, String value, Color color) {
    final at = DynAdmin.of(context);
    return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: at.textMuted, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ]),
    ),
  );
  }

  // ─── Change Role sheet ───────────────────────────────────────────────────
  void _showChangeRoleSheet(
      BuildContext ctx, String uid, String name, String currentRole) {
    final at = DynAdmin.of(ctx);
    String selectedRole = currentRole;
    bool isLoading = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: at.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: at.textMuted,
                          borderRadius: BorderRadius.circular(2))),
                  Text('Change Role — $name', style: at.heading(18)),
                  const SizedBox(height: 6),
                  Text('Current role: ${currentRole.toUpperCase()}',
                      style: at.label(13)),
                  const SizedBox(height: 8),
                  // Collection info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminTheme.cyan.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminTheme.cyan.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: AdminTheme.cyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Changing role will update this employee\'s access level',
                          style: const TextStyle(fontSize: 11, color: AdminTheme.cyan),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: ['manager', 'delivery', 'staff'].map((r) {
                      final active = selectedRole == r;
                      final c = r == 'delivery'
                          ? AdminTheme.gold
                          : r == 'manager'
                              ? AdminTheme.violet
                              : AdminTheme.amber;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setLocal(() => selectedRole = r),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin:
                                EdgeInsets.only(right: r != 'staff' ? 10 : 0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            decoration: BoxDecoration(
                              color: active
                                  ? c.withValues(alpha: 0.2)
                                  : at.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: active ? c : at.cardBorder,
                                  width: active ? 1.5 : 1),
                            ),
                            child: Column(children: [
                              Text(r.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: active ? c : at.textSecondary)),
                
                            ]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.violet,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setLocal(() => isLoading = true);
                              // assignRole handles collection migration + sends notification
                              await RoleBasedAuthService()
                                  .assignRole(uid, selectedRole);
                              if (ctx2.mounted) {
                                Navigator.pop(ctx2);
                                ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(
                                  content: Row(children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Role updated to ${selectedRole.toUpperCase()} — employee notified'),
                                  ]),
                                  backgroundColor: AdminTheme.violet,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.all(16),
                                ));
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('UPDATE ROLE',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    final at = DynAdmin.of(context);
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: at.label(11)),
    ]);
  }

  Widget _divider(BuildContext ctx) {
    final at = DynAdmin.of(ctx);
    return Container(width: 1, height: 30, color: at.cardBorder);
  }

  // ─── Assign Role by Email sheet ──────────────────────────────────────────
  void _showAssignRoleByEmailSheet(BuildContext ctx) {
    final at = DynAdmin.of(ctx);
    final emailCtrl = TextEditingController();
    String selectedRole = 'manager';
    bool isLoading = false;
    String? feedback;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: at.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: at.textMuted,
                          borderRadius: BorderRadius.circular(2))),
                  Text('Assign Role by Email', style: at.heading(20)),
                  const SizedBox(height: 6),
                  Text('Assign a role to an existing registered user',
                      style: at.label(13)),
                  const SizedBox(height: 24),
                  _buildField(ctx,
                      emailCtrl, 'User Email Address', Icons.email_outlined,
                      keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  Text('Role to Assign', style: at.label(13)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['manager', 'delivery', 'staff'].map((r) {
                      final active = selectedRole == r;
                      final c = r == 'delivery'
                          ? AdminTheme.gold
                          : r == 'manager'
                              ? AdminTheme.violet
                              : AdminTheme.amber;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setLocal(() => selectedRole = r),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin:
                                EdgeInsets.only(right: r != 'staff' ? 10 : 0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: active
                                  ? c.withValues(alpha: 0.2)
                                  : at.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: active ? c : at.cardBorder,
                                  width: active ? 1.5 : 1),
                            ),
                            child: Column(children: [
                              Text(r.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: active ? c : at.textSecondary)),
                
                            ]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (feedback != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: feedback!.startsWith('✓')
                            ? AdminTheme.emerald.withValues(alpha: 0.1)
                            : AdminTheme.rose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(feedback!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: feedback!.startsWith('✓')
                                ? AdminTheme.emerald
                                : AdminTheme.rose,
                          )),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.violet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (emailCtrl.text.trim().isEmpty) return;
                              setLocal(() {
                                isLoading = true;
                                feedback = null;
                              });
                              final roleService = RoleBasedAuthService();
                              final result = await roleService.addRoleByEmail(
                                  emailCtrl.text.trim(), selectedRole);
                              if (result['success'] == true) {
                                final assignedName = result['name'] as String? ?? '';
                                final assignedPhone = result['phone'] as String? ?? '';
                                final assignedEmpId = result['employeeId'] as String? ?? 'EMP-NEW';
                                if (ctx2.mounted) {
                                  await EmployeeNotificationService().notifyNewEmployee(
                                    context: ctx2,
                                    name: assignedName.isNotEmpty ? assignedName : emailCtrl.text.trim(),
                                    email: emailCtrl.text.trim().toLowerCase(),
                                    phone: assignedPhone,
                                    role: selectedRole,
                                    employeeId: assignedEmpId,
                                  );
                                }
                              }
                              setLocal(() {
                                isLoading = false;
                                if (result['success'] == true) {
                                  feedback = '✓ Role assigned successfully';
                                  emailCtrl.clear();
                                } else {
                                  feedback = '✗ ${result['error'] ?? 'Failed to assign role'}';
                                }
                              });
                            },
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('ASSIGN ROLE',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Add New Employee sheet ───────────────────────────────────────────────
  void _showAddEmployeeSheet(BuildContext ctx) {
    final at = DynAdmin.of(ctx);
    final db = FirebaseFirestore.instance;
    final nameCtrl        = TextEditingController();
    final emailCtrl       = TextEditingController();
    final phoneCtrl       = TextEditingController();
    final dobCtrl         = TextEditingController();
    final addressCtrl     = TextEditingController();
    final emergencyCtrl   = TextEditingController();
    final employeeIdCtrl  = TextEditingController(
        text: 'EMP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    String selectedRole   = 'delivery';
    String selectedGender = 'Male';
    String selectedShift  = 'Morning';
    bool   isLoading      = false;
    String? feedback;
    final scrollCtrl = ScrollController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) {
          return AnimatedPadding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx2).viewInsets.bottom),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx2).size.height * 0.92,
              ),
              decoration: BoxDecoration(
                  color: at.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                              width: 40, height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                  color: at.textMuted,
                                  borderRadius: BorderRadius.circular(2))),
                        ),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: AdminTheme.emerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.person_add_rounded,
                                color: AdminTheme.emerald, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Add New Employee', style: at.heading(18)),
                            Text('Fill in the employee details below',
                                style: at.label(12)),
                          ]),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: at.cardBorder, height: 1),

                  Flexible(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          _sectionLabel('Personal Information'),
                          const SizedBox(height: 12),
                          _buildField(ctx, nameCtrl, 'Full Name *',
                              Icons.person_outline_rounded),
                          const SizedBox(height: 12),
                          _buildField(ctx, emailCtrl, 'Google Account Email *',
                              Icons.email_outlined,
                              keyboard: TextInputType.emailAddress),
                          // Helper text for Google account
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Row(children: [
                              const Icon(Icons.info_outline_rounded, size: 12, color: AdminTheme.cyan),
                              const SizedBox(width: 4),
                              Text(
                                'Use their Google account email — they\'ll be routed to the correct dashboard on sign-in',
                                style: at.label(11).copyWith(color: AdminTheme.cyan),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          _buildField(ctx, phoneCtrl, 'Phone Number *',
                              Icons.phone_outlined,
                              keyboard: TextInputType.phone),
                          const SizedBox(height: 12),

                          // Gender picker
                          Text('Gender', style: at.label(13)),
                          const SizedBox(height: 8),
                          Row(
                            children: ['Male', 'Female', 'Other'].map((g) {
                              final active = selectedGender == g;
                              return GestureDetector(
                                onTap: () => setLocal(() => selectedGender = g),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AdminTheme.accent.withValues(alpha: 0.15)
                                        : at.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: active
                                            ? AdminTheme.accent
                                            : at.cardBorder,
                                        width: active ? 1.5 : 1),
                                  ),
                                  child: Text(g,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: active
                                              ? AdminTheme.accent
                                              : at.textSecondary)),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),

                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx2,
                                initialDate: DateTime(1995, 1, 1),
                                firstDate: DateTime(1950),
                                lastDate: DateTime.now()
                                    .subtract(const Duration(days: 365 * 18)),
                                builder: (c, child) => Theme(
                                  data: Theme.of(c).copyWith(
                                    colorScheme: ColorScheme.dark(
                                      primary: AdminTheme.gold,
                                      surface: at.surface,
                                      onSurface: at.textPrimary,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setLocal(() => dobCtrl.text =
                                    '${picked.day.toString().padLeft(2, '0')}/'
                                    '${picked.month.toString().padLeft(2, '0')}/'
                                    '${picked.year}');
                              }
                            },
                            child: AbsorbPointer(
                              child: _buildField(ctx, dobCtrl, 'Date of Birth',
                                  Icons.cake_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildField(ctx, addressCtrl, 'Home Address',
                              Icons.home_outlined,
                              maxLines: 2),
                          const SizedBox(height: 12),
                          _buildField(ctx, emergencyCtrl, 'Emergency Contact Number',
                              Icons.emergency_outlined,
                              keyboard: TextInputType.phone),

                          const SizedBox(height: 20),

                          _sectionLabel('Work Details'),
                          const SizedBox(height: 12),
                          _buildField(ctx, employeeIdCtrl, 'Employee ID',
                              Icons.badge_outlined),
                          const SizedBox(height: 12),

                          // Role selector — shows target collection
                          Text('Role *', style: at.label(13)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: ['delivery', 'manager', 'staff'].map((r) {
                              final active = selectedRole == r;
                              final c = r == 'delivery'
                                  ? AdminTheme.gold
                                  : r == 'manager'
                                      ? AdminTheme.violet
                                      : AdminTheme.amber;
                              return GestureDetector(
                                onTap: () => setLocal(() => selectedRole = r),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? c.withValues(alpha: 0.18)
                                        : at.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: active ? c : at.cardBorder,
                                        width: active ? 1.5 : 1),
                                  ),
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(
                                        r == 'delivery'
                                            ? Icons.delivery_dining_rounded
                                            : r == 'manager'
                                                ? Icons.manage_accounts_rounded
                                                : Icons.engineering_rounded,
                                        color: active ? c : at.textSecondary,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(r.toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: active ? c : at.textSecondary)),
                                    ]),

                                  ]),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),

                          // Shift
                          Text('Shift', style: at.label(13)),
                          const SizedBox(height: 8),
                          Row(
                            children: ['Morning', 'Evening', 'Night'].map((s) {
                              final active = selectedShift == s;
                              return GestureDetector(
                                onTap: () => setLocal(() => selectedShift = s),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AdminTheme.cyan.withValues(alpha: 0.15)
                                        : at.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: active
                                            ? AdminTheme.cyan
                                            : at.cardBorder,
                                        width: active ? 1.5 : 1),
                                  ),
                                  child: Text(s,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: active
                                              ? AdminTheme.cyan
                                              : at.textSecondary)),
                                ),
                              );
                            }).toList(),
                          ),

                          if (feedback != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: feedback!.startsWith('✓')
                                    ? AdminTheme.emerald.withValues(alpha: 0.1)
                                    : AdminTheme.rose.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: feedback!.startsWith('✓')
                                        ? AdminTheme.emerald.withValues(alpha: 0.3)
                                        : AdminTheme.rose.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                Icon(
                                  feedback!.startsWith('✓')
                                      ? Icons.check_circle_rounded
                                      : Icons.error_outline_rounded,
                                  size: 16,
                                  color: feedback!.startsWith('✓')
                                      ? AdminTheme.emerald
                                      : AdminTheme.rose,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(feedback!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: feedback!.startsWith('✓')
                                              ? AdminTheme.emerald
                                              : AdminTheme.rose)),
                                ),
                              ]),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Sticky submit button
                  Container(
                    padding: EdgeInsets.fromLTRB(
                        24, 12, 24, MediaQuery.of(ctx2).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: at.surface,
                      border: Border(top: BorderSide(color: at.cardBorder)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.emerald,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                if (nameCtrl.text.trim().isEmpty ||
                                    emailCtrl.text.trim().isEmpty ||
                                    phoneCtrl.text.trim().isEmpty) {
                                  setLocal(() => feedback =
                                      '✗ Name, email and phone are required');
                                  return;
                                }
                                setLocal(() {
                                  isLoading = true;
                                  feedback = null;
                                });
                                try {
                                  final email = emailCtrl.text.trim().toLowerCase();
                                  final empId = employeeIdCtrl.text.trim();
                                  final roleCol = _roleCollections[selectedRole]!;

                                  // Base data for users collection
                                  final data = <String, dynamic>{
                                    'name': nameCtrl.text.trim(),
                                    'email': email,
                                    'phone': phoneCtrl.text.trim(),
                                    'gender': selectedGender,
                                    'dateOfBirth': dobCtrl.text.trim(),
                                    'address': addressCtrl.text.trim(),
                                    'emergencyContact': emergencyCtrl.text.trim(),
                                    'employeeId': empId,
                                    'role': selectedRole,
                                    'shift': selectedShift.toLowerCase(),
                                    'isBlocked': false,
                                    'isActive': true,
                                    'accountStatus': 'active',
                                    'loyaltyPoints': 0,
                                    'totalOrders': 0,
                                    'totalSpent': 0.0,
                                    'activeOrders': 0,
                                    'completedOrders': 0,
                                    'rating': 5.0,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };
                                  if (selectedRole == 'delivery') {
                                    data['isOnline'] = false;
                                    data['vehicleType'] = 'bike';
                                  } else if (selectedRole == 'manager') {
                                    data['managedStaffCount'] = 0;
                                  }

                                  // ── Pre-register employee in Firestore ──
                                  // Employees sign in with Google — no password needed.
                                  // We store their email so the role lookup works
                                  // the moment they sign in with Google for the first time.
                                  final phone = phoneCtrl.text.trim();

                                  // Remove this email from other role collections first
                                  for (final entry in _roleCollections.entries) {
                                    if (entry.key == selectedRole) continue;
                                    final old = await db
                                        .collection(entry.value)
                                        .where('email', isEqualTo: email)
                                        .limit(1)
                                        .get();
                                    for (final d in old.docs) {
                                      await d.reference.delete();
                                    }
                                  }

                                  // Check if already exists (re-adding same employee)
                                  final roleRef = db.collection(roleCol);
                                  final existing = await roleRef
                                      .where('email', isEqualTo: email)
                                      .limit(1)
                                      .get();
                                  final docRef = existing.docs.isNotEmpty
                                      ? roleRef.doc(existing.docs.first.id)
                                      : roleRef.doc();
                                  await docRef.set({
                                    ...data,
                                    'uid': docRef.id,
                                    'createdByAdmin': true,
                                    'loginMethod': 'google',
                                  }, SetOptions(merge: true));

                                  // Send welcome email with Google sign-in instructions
                                  if (ctx2.mounted) {
                                    await EmployeeNotificationService().notifyNewEmployee(
                                      context: ctx2,
                                      name: nameCtrl.text.trim(),
                                      email: email,
                                      phone: phone,
                                      role: selectedRole,
                                      employeeId: empId,
                                    );
                                  }

                                  if (ctx2.mounted) Navigator.pop(ctx2);
                                  _showEmployeeAddedSnackBar(
                                    messenger: messenger,
                                    name: nameCtrl.text.trim(),
                                    role: selectedRole,
                                    collection: roleCol,
                                  );
                                } catch (e) {
                                  setLocal(() {
                                    isLoading = false;
                                    feedback =
                                        '✗ Error: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim()}';
                                  });
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('CREATE EMPLOYEE',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEmployeeAddedSnackBar({
    required ScaffoldMessengerState messenger,
    required String name,
    required String role,
    required String collection,
  }) {
    final roleLabel = role == 'delivery'
        ? 'Delivery Agent'
        : role == 'manager'
            ? 'Manager'
            : 'Staff Member';
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$name added as $roleLabel',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      ]),
      backgroundColor: AdminTheme.emerald,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _sectionLabel(String label) {
    final at = DynAdmin.of(context);
    return Row(children: [
        Container(width: 3, height: 16,
            decoration: BoxDecoration(
                color: AdminTheme.gold,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: at.textPrimary,
                letterSpacing: 0.3)),
      ]);
  }

  Widget _buildField(BuildContext ctx, TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard, int maxLines = 1}) {
    final at = DynAdmin.of(ctx);
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: TextStyle(color: at.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: at.label(13),
        prefixIcon: Icon(icon, color: at.textSecondary, size: 20),
        filled: true,
        fillColor: at.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: at.cardBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: at.cardBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AdminTheme.gold, width: 2)),
      ),
    );
  }
}

// ─── Shows employees from ALL 3 role collections merged ──────────────────────
class _AllEmployeesView extends StatelessWidget {
  final VoidCallback onAddEmployee;
  final void Function(BuildContext, String, Map<String, dynamic>) onEmployeeDetails;
  final void Function(BuildContext, String, String, String) onChangeRole;

  const _AllEmployeesView({
    required this.onAddEmployee,
    required this.onEmployeeDetails,
    required this.onChangeRole,
  });

  static const _collections = {
    'delivery': 'delivery_agents',
    'manager': 'managers',
    'staff': 'staff',
  };

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final streams = _collections.entries.map((e) => db
        .collection(e.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'_role': e.key, '_col': e.value, '_id': d.id, ...d.data()})
            .toList())).toList();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _mergeStreams(streams),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AdminTheme.gold, strokeWidth: 2));
        }
        final employees = snap.data ?? [];
        if (employees.isEmpty) {
          final at = DynAdmin.of(ctx);
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.badge_outlined, color: at.textMuted, size: 56),
            const SizedBox(height: 16),
            Text('No employees found', style: at.heading(16)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onAddEmployee,
              child: const Text('Add first employee →',
                  style: TextStyle(color: AdminTheme.gold, fontWeight: FontWeight.w700)),
            ),
          ]));
        }
        return _EmployeeListParent(
          employees: employees,
          onEmployeeDetails: onEmployeeDetails,
          onChangeRole: onChangeRole,
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _mergeStreams(
      List<Stream<List<Map<String, dynamic>>>> streams) {
    // Simple manual merge using async*
    return _CombineLatest3Stream(streams[0], streams[1], streams[2]);
  }
}

class _CombineLatest3Stream
    extends Stream<List<Map<String, dynamic>>> {
  final Stream<List<Map<String, dynamic>>> s1, s2, s3;
  _CombineLatest3Stream(this.s1, this.s2, this.s3);

  @override
  StreamSubscription<List<Map<String, dynamic>>> listen(
      void Function(List<Map<String, dynamic>>)? onData,
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    List<Map<String, dynamic>>? v1, v2, v3;
    void emit() {
      if (v1 != null && v2 != null && v3 != null) {
        onData?.call([...v1!, ...v2!, ...v3!]);
      }
    }

    final c = StreamController<List<Map<String, dynamic>>>();
    s1.listen((v) { v1 = v; emit(); });
    s2.listen((v) { v2 = v; emit(); });
    s3.listen((v) { v3 = v; emit(); });
    return c.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError ?? false);
  }
}

class _EmployeeListParent extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final void Function(BuildContext, String, Map<String, dynamic>) onEmployeeDetails;
  final void Function(BuildContext, String, String, String) onChangeRole;
  const _EmployeeListParent({required this.employees, required this.onEmployeeDetails, required this.onChangeRole});
  @override
  State<_EmployeeListParent> createState() => _EmployeeListParentState();
}

class _EmployeeListParentState extends State<_EmployeeListParent> {
  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.employees.length,
      itemBuilder: (_, i) {
        final d = widget.employees[i];
        final docId = d['_id'] as String;
        final role = (d['role'] ?? d['_role'] ?? 'staff') as String;
        final roleColor = role == 'delivery'
            ? AdminTheme.gold
            : role == 'manager'
                ? AdminTheme.violet
                : AdminTheme.amber;
        final activeOrders = d['activeOrders'] ?? 0;
        final completedOrders = d['completedOrders'] ?? 0;
        return GestureDetector(
          onTap: () => widget.onEmployeeDetails(context, docId, d),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: at.cardDecoration(),
            child: Column(children: [
              Row(children: [
                Stack(children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: roleColor.withValues(alpha: 0.2),
                    backgroundImage: d['photoURL'] != null ? NetworkImage(d['photoURL'] as String) : null,
                    child: d['photoURL'] == null
                        ? Text((d['name'] as String? ?? 'E')[0].toUpperCase(),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: roleColor))
                        : null,
                  ),
                  Positioned(bottom: 0, right: 0,
                    child: Container(width: 14, height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (d['isActive'] ?? true) ? AdminTheme.emerald : AdminTheme.rose,
                        border: Border.all(color: at.surface, width: 2),
                      ))),
                ]),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(d['name'] ?? 'Employee',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: at.textPrimary))),
                    AdminBadge(label: role, color: roleColor, fontSize: 10),
                  ]),
                  const SizedBox(height: 4),
                  Text(d['email'] ?? '', style: at.label(12)),
                ])),
              ]),
              const SizedBox(height: 14),
              Container(height: 1, color: at.cardBorder),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _sc('Active', activeOrders.toString(), AdminTheme.amber, at),
                Container(width: 1, height: 30, color: at.cardBorder),
                _sc('Done', completedOrders.toString(), AdminTheme.emerald, at),
                Container(width: 1, height: 30, color: at.cardBorder),
                _sc('Rating', '${(d['rating'] ?? 4.5).toStringAsFixed(1)}⭐', AdminTheme.gold, at),
              ]),
              const SizedBox(height: 10),
              Container(height: 1, color: at.cardBorder),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => widget.onChangeRole(context, docId, d['name'] ?? '', role),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: AdminTheme.violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.violet.withValues(alpha: 0.2)),
                  ),
                  child: const Text('Change Role', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.violet)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _sc(String label, String value, Color color, DynAdmin at) =>
      Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: at.label(11)),
      ]);
}

// ─── Small widget showing which Firestore collection is being queried ───────
class _CollectionBadge extends StatelessWidget {
  final String filterRole;
  const _CollectionBadge({required this.filterRole});

  @override
  Widget build(BuildContext context) {
    final col = filterRole == 'all'
        ? 'delivery_agents + managers + staff (all)'
        : _label(filterRole);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AdminTheme.cyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTheme.cyan.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.storage_rounded, size: 12, color: AdminTheme.cyan),
        const SizedBox(width: 6),
        Text(
          'Collection: $col',
          style: const TextStyle(fontSize: 11, color: AdminTheme.cyan, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }

  String _label(String role) {
    switch (role) {
      case 'delivery': return 'delivery_agents';
      case 'manager':  return 'managers';
      case 'staff':    return 'staff';
      default:         return 'users';
    }
  }
}

