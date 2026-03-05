import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee Management', style: AdminTheme.heading(20)),
              const SizedBox(height: 4),
              const Text('Manage delivery agents, managers & staff',
                  style:
                      TextStyle(fontSize: 13, color: AdminTheme.textSecondary)),
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

        // ROLE FILTER CHIPS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                            : AdminTheme.textSecondary;
                return GestureDetector(
                  onTap: () => setState(() => _filterRole = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          active ? c.withValues(alpha: 0.2) : AdminTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: active ? c : AdminTheme.cardBorder,
                          width: active ? 1.5 : 1),
                    ),
                    child: Text(r.toUpperCase(),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: active ? c : AdminTheme.textSecondary)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filterRole == 'all'
                ? _db.collection('users').where('role',
                    whereIn: ['delivery', 'manager', 'staff']).snapshots()
                : _db
                    .collection('users')
                    .where('role', isEqualTo: _filterRole)
                    .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AdminTheme.gold, strokeWidth: 2));
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.badge_outlined,
                      color: AdminTheme.textMuted, size: 56),
                  const SizedBox(height: 16),
                  Text('No employees found', style: AdminTheme.heading(16)),
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
                  final role = d['role'] ?? 'staff';
                  final roleColor = role == 'delivery'
                      ? AdminTheme.gold
                      : role == 'manager'
                          ? AdminTheme.violet
                          : AdminTheme.amber;
                  final activeOrders = d['activeOrders'] ?? 0;
                  final completedOrders = d['completedOrders'] ?? 0;

                  return GestureDetector(
                    onTap: () => _showEmployeeDetails(context, doc.id, d),
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: AdminTheme.cardDecoration(),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor:
                                      roleColor.withValues(alpha: 0.2),
                                  backgroundImage: d['photoURL'] != null
                                      ? NetworkImage(d['photoURL'])
                                      : null,
                                  child: d['photoURL'] == null
                                      ? Text(
                                          (d['name'] as String? ?? 'E')[0]
                                              .toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: roleColor))
                                      : null,
                                ),
                                Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: (d['isActive'] ?? true)
                                              ? AdminTheme.emerald
                                              : AdminTheme.rose,
                                          border: Border.all(
                                              color: AdminTheme.surface,
                                              width: 2)),
                                    )),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(d['name'] ?? 'Employee',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    AdminTheme.textPrimary))),
                                    AdminBadge(
                                        label: role,
                                        color: roleColor,
                                        fontSize: 10),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(d['email'] ?? '',
                                      style: AdminTheme.label(12)),
                                  const SizedBox(height: 4),
                                  Text(d['phone'] ?? '',
                                      style: AdminTheme.label(11).copyWith(
                                          color: AdminTheme.textMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(height: 1, color: AdminTheme.cardBorder),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statCol('Active', activeOrders.toString(),
                                AdminTheme.amber),
                            _divider(),
                            _statCol('Completed', completedOrders.toString(),
                                AdminTheme.emerald),
                            _divider(),
                            _statCol(
                                'Rating',
                                '${(d['rating'] ?? 4.5).toStringAsFixed(1)}⭐',
                                AdminTheme.gold),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: AdminTheme.cardBorder),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showChangeRoleSheet(
                                    context, doc.id, d['name'] ?? '', role),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.violet
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AdminTheme.violet
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: const Text('Change Role',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AdminTheme.violet)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  // Only primary admin can remove roles
                                  final canRemove = RoleBasedAuthService().canPerformDangerousActions;
                                  if (!canRemove) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Only the primary admin can remove employee roles.'),
                                          backgroundColor: AdminTheme.rose,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AdminTheme.surface,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      title: Text(
                                          'Remove ${d['name'] ?? 'employee'}?',
                                          style: AdminTheme.heading(16)),
                                      content: const Text(
                                          'This will set their role back to regular user.',
                                          style: TextStyle(
                                              color: AdminTheme.textSecondary)),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Remove',
                                              style: TextStyle(
                                                  color: AdminTheme.rose)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await RoleBasedAuthService()
                                        .removeRole(doc.id);
                                  }
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color:
                                        AdminTheme.rose.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AdminTheme.rose
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: const Text('Remove Role',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AdminTheme.rose)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),  // closes GestureDetector
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEmployeeDetails(BuildContext context, String uid, Map<String, dynamic> d) {
    final role = d['role'] ?? 'staff';
    final roleColor = role == 'delivery'
        ? AdminTheme.gold
        : role == 'manager'
            ? AdminTheme.violet
            : AdminTheme.amber;
    final name = d['name'] ?? 'Employee';
    final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: AdminTheme.surface,
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
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: AdminTheme.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Header
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
                Text(name, style: AdminTheme.heading(20)),
                const SizedBox(height: 4),
                AdminBadge(label: role, color: roleColor),
              ])),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: (d['isActive'] ?? true) ? AdminTheme.emerald.withValues(alpha: 0.12) : AdminTheme.rose.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    (d['isActive'] ?? true) ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: (d['isActive'] ?? true) ? AdminTheme.emerald : AdminTheme.rose,
                    size: 20),
              ),
            ]),
            const SizedBox(height: 24),
            // Contact Info
            Text('Contact Information', style: AdminTheme.heading(14)),
            const SizedBox(height: 12),
            _detailRow(Icons.email_outlined, 'Email', d['email'] ?? '—'),
            _detailRow(Icons.phone_outlined, 'Phone', d['phone'] ?? '—'),
            _detailRow(Icons.location_on_outlined, 'Address', d['address'] ?? '—'),
            _detailRow(Icons.badge_outlined, 'Employee ID', uid.substring(0, 8).toUpperCase()),
            const SizedBox(height: 20),
            // Performance
            Text('Performance', style: AdminTheme.heading(14)),
            const SizedBox(height: 12),
            Row(children: [
              _perfTile('Active Orders', '${d['activeOrders'] ?? 0}', AdminTheme.amber),
              const SizedBox(width: 10),
              _perfTile('Completed', '${d['completedOrders'] ?? 0}', AdminTheme.emerald),
              const SizedBox(width: 10),
              _perfTile('Rating', '${(d['rating'] ?? 4.5).toStringAsFixed(1)} ⭐', AdminTheme.gold),
            ]),
            const SizedBox(height: 20),
            // Additional info
            if (d['joinedAt'] != null) ...[
              Text('Additional Info', style: AdminTheme.heading(14)),
              const SizedBox(height: 12),
              _detailRow(Icons.calendar_today_rounded, 'Joined', d['joinedAt'] ?? '—'),
              if (d['gender'] != null) _detailRow(Icons.person_outline, 'Gender', d['gender'] ?? '—'),
            ],
            const SizedBox(height: 24),
            // Actions
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

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AdminTheme.textMuted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AdminTheme.textSecondary),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted, fontWeight: FontWeight.w600)),
        Text(value, style: AdminTheme.label(13).copyWith(color: AdminTheme.textPrimary)),
      ])),
    ]),
  );

  Widget _perfTile(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AdminTheme.textMuted, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ]),
    ),
  );

  void _showChangeRoleSheet(
      BuildContext ctx, String uid, String name, String currentRole) {
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
              color: AdminTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          color: AdminTheme.textMuted,
                          borderRadius: BorderRadius.circular(2))),
                  Text('Change Role — $name', style: AdminTheme.heading(18)),
                  const SizedBox(height: 6),
                  Text('Current role: ${currentRole.toUpperCase()}',
                      style: AdminTheme.label(13)),
                  const SizedBox(height: 24),
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
                                  : AdminTheme.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: active ? c : AdminTheme.cardBorder,
                                  width: active ? 1.5 : 1),
                            ),
                            child: Text(r.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        active ? c : AdminTheme.textSecondary)),
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
                              await RoleBasedAuthService()
                                  .assignRole(uid, selectedRole);
                              if (ctx2.mounted) Navigator.pop(ctx2);
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
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: AdminTheme.label(11)),
    ]);
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: AdminTheme.cardBorder);

  // ── Assign Role by Email (for existing registered users) ──────────────
  void _showAssignRoleByEmailSheet(BuildContext ctx) {
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
              color: AdminTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          color: AdminTheme.textMuted,
                          borderRadius: BorderRadius.circular(2))),
                  Text('Assign Role by Email', style: AdminTheme.heading(20)),
                  const SizedBox(height: 6),
                  Text('Assign a role to an existing registered user',
                      style: AdminTheme.label(13)),
                  const SizedBox(height: 24),
                  _buildField(
                      emailCtrl, 'User Email Address', Icons.email_outlined,
                      keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  Text('Role to Assign', style: AdminTheme.label(13)),
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
                                  : AdminTheme.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: active ? c : AdminTheme.cardBorder,
                                  width: active ? 1.5 : 1),
                            ),
                            child: Text(r.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        active ? c : AdminTheme.textSecondary)),
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
                              setLocal(() {
                                isLoading = false;
                                if (result['success'] == true) {
                                  feedback =
                                      '✓ Role assigned to ${result['name'] ?? emailCtrl.text}';
                                  emailCtrl.clear();
                                } else {
                                  feedback =
                                      '✗ ${result['error'] ?? 'Failed to assign role'}';
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

  void _showAddEmployeeSheet(BuildContext ctx) {
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

    // Scroll controller so keyboard pushes content up
    final scrollCtrl = ScrollController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) {
          return AnimatedPadding(
            // Moves sheet up when keyboard appears
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx2).viewInsets.bottom),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx2).size.height * 0.92,
              ),
              decoration: BoxDecoration(
                  color: AdminTheme.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Drag handle + header ──────────────────
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
                                  color: AdminTheme.textMuted,
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
                            Text('Add New Employee', style: AdminTheme.heading(18)),
                            Text('Fill in the employee details below',
                                style: AdminTheme.label(12)),
                          ]),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AdminTheme.cardBorder, height: 1),

                  // ── Scrollable form body ──────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── SECTION: Personal Info ──
                          _sectionLabel('Personal Information'),
                          const SizedBox(height: 12),
                          _buildField(nameCtrl, 'Full Name *',
                              Icons.person_outline_rounded),
                          const SizedBox(height: 12),
                          _buildField(emailCtrl, 'Email Address *',
                              Icons.email_outlined,
                              keyboard: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _buildField(phoneCtrl, 'Phone Number *',
                              Icons.phone_outlined,
                              keyboard: TextInputType.phone),
                          const SizedBox(height: 12),

                          // Gender picker
                          Text('Gender', style: AdminTheme.label(13)),
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
                                        : AdminTheme.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: active
                                            ? AdminTheme.accent
                                            : AdminTheme.cardBorder,
                                        width: active ? 1.5 : 1),
                                  ),
                                  child: Text(g,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: active
                                              ? AdminTheme.accent
                                              : AdminTheme.textSecondary)),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),

                          // Date of Birth — tap to pick
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
                                      surface: AdminTheme.surface,
                                      onSurface: AdminTheme.textPrimary,
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
                              child: _buildField(dobCtrl, 'Date of Birth',
                                  Icons.cake_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildField(addressCtrl, 'Home Address',
                              Icons.home_outlined,
                              maxLines: 2),
                          const SizedBox(height: 12),
                          _buildField(emergencyCtrl, 'Emergency Contact Number',
                              Icons.emergency_outlined,
                              keyboard: TextInputType.phone),

                          const SizedBox(height: 20),

                          // ── SECTION: Work Details ──
                          _sectionLabel('Work Details'),
                          const SizedBox(height: 12),

                          _buildField(employeeIdCtrl, 'Employee ID',
                              Icons.badge_outlined),
                          const SizedBox(height: 12),

                          // Role
                          Text('Role *', style: AdminTheme.label(13)),
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
                                        : AdminTheme.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: active
                                            ? c
                                            : AdminTheme.cardBorder,
                                        width: active ? 1.5 : 1),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(
                                      r == 'delivery'
                                          ? Icons.delivery_dining_rounded
                                          : r == 'manager'
                                              ? Icons.manage_accounts_rounded
                                              : Icons.engineering_rounded,
                                      color: active ? c : AdminTheme.textSecondary,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(r.toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: active
                                                ? c
                                                : AdminTheme.textSecondary)),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),

                          // Shift
                          Text('Shift', style: AdminTheme.label(13)),
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
                                        : AdminTheme.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: active
                                            ? AdminTheme.cyan
                                            : AdminTheme.cardBorder,
                                        width: active ? 1.5 : 1),
                                  ),
                                  child: Text(s,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: active
                                              ? AdminTheme.cyan
                                              : AdminTheme.textSecondary)),
                                ),
                              );
                            }).toList(),
                          ),

                          // Feedback banner
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

                  // ── Sticky Submit Button ──────────────────
                  Container(
                    padding: EdgeInsets.fromLTRB(
                        24, 12, 24, MediaQuery.of(ctx2).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: AdminTheme.surface,
                      border: Border(
                          top: BorderSide(color: AdminTheme.cardBorder)),
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
                                final messenger =
                                    ScaffoldMessenger.of(context);
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
                                  final data = <String, dynamic>{
                                    'name': nameCtrl.text.trim(),
                                    'email': emailCtrl.text.trim().toLowerCase(),
                                    'phone': phoneCtrl.text.trim(),
                                    'gender': selectedGender,
                                    'dateOfBirth': dobCtrl.text.trim(),
                                    'address': addressCtrl.text.trim(),
                                    'emergencyContact': emergencyCtrl.text.trim(),
                                    'employeeId': employeeIdCtrl.text.trim(),
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
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };
                                  if (selectedRole == 'delivery') {
                                    data['isOnline'] = false;
                                    data['vehicleType'] = 'bike';
                                    data['rating'] = 5.0;
                                  } else if (selectedRole == 'manager') {
                                    data['managedStaffCount'] = 0;
                                  }

                                  final existing = await db
                                      .collection('users')
                                      .where('email',
                                          isEqualTo: data['email'])
                                      .limit(1)
                                      .get();

                                  if (existing.docs.isNotEmpty) {
                                    await db
                                        .collection('users')
                                        .doc(existing.docs.first.id)
                                        .update({
                                      'role': selectedRole,
                                      'name': nameCtrl.text.trim().isNotEmpty
                                          ? nameCtrl.text.trim()
                                          : existing.docs.first['name'],
                                      'phone': phoneCtrl.text.trim().isNotEmpty
                                          ? phoneCtrl.text.trim()
                                          : existing.docs.first['phone'],
                                      'gender': selectedGender,
                                      'shift': selectedShift.toLowerCase(),
                                      if (dobCtrl.text.isNotEmpty)
                                        'dateOfBirth': dobCtrl.text.trim(),
                                      if (addressCtrl.text.isNotEmpty)
                                        'address': addressCtrl.text.trim(),
                                      if (emergencyCtrl.text.isNotEmpty)
                                        'emergencyContact':
                                            emergencyCtrl.text.trim(),
                                      'updatedAt':
                                          FieldValue.serverTimestamp(),
                                    });
                                    if (ctx2.mounted) Navigator.pop(ctx2);
                                    messenger.showSnackBar(SnackBar(
                                        content: Text(
                                            '✓ Existing user updated to ${selectedRole.toUpperCase()}'),
                                        backgroundColor: AdminTheme.emerald,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        margin: const EdgeInsets.all(16)));
                                  } else {
                                    final newDocRef =
                                        db.collection('users').doc();
                                    await newDocRef.set({
                                      ...data,
                                      'uid': newDocRef.id,
                                      'createdByAdmin': true,
                                    });
                                    if (ctx2.mounted) Navigator.pop(ctx2);
                                    messenger.showSnackBar(SnackBar(
                                        content: Text(
                                            '✓ "${nameCtrl.text.trim()}" added as ${selectedRole.toUpperCase()}'),
                                        backgroundColor: AdminTheme.emerald,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        margin: const EdgeInsets.all(16)));
                                  }
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

  Widget _sectionLabel(String label) => Row(children: [
        Container(width: 3, height: 16,
            decoration: BoxDecoration(
                color: AdminTheme.gold,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AdminTheme.textPrimary,
                letterSpacing: 0.3)),
      ]);

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AdminTheme.label(13),
        prefixIcon: Icon(icon, color: AdminTheme.textSecondary, size: 20),
        filled: true,
        fillColor: AdminTheme.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AdminTheme.cardBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AdminTheme.cardBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AdminTheme.gold, width: 2)),
      ),
    );
  }
}
