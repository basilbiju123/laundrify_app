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
          padding: const EdgeInsets.all(24),
          child: AdminPageHeader(
            title: 'Employee Management',
            subtitle: 'Manage delivery agents, managers & staff',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showAssignRoleByEmailSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AdminTheme.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminTheme.gold.withValues(alpha: 0.3))),
                    child: const Row(children: [
                      Icon(Icons.email_rounded, color: AdminTheme.gold, size: 16),
                      SizedBox(width: 6),
                      Text('Assign by Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.gold)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showAddEmployeeSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AdminTheme.emerald.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminTheme.emerald.withValues(alpha: 0.3))),
                    child: const Row(children: [
                      Icon(Icons.add_rounded, color: AdminTheme.emerald, size: 18),
                      SizedBox(width: 6),
                      Text('Add New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.emerald)),
                    ]),
                  ),
                ),
              ],
            ),
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
                final c = r == 'delivery' ? AdminTheme.gold : r == 'manager' ? AdminTheme.violet : r == 'staff' ? AdminTheme.amber : AdminTheme.textSecondary;
                return GestureDetector(
                  onTap: () => setState(() => _filterRole = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? c.withValues(alpha: 0.2) : AdminTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? c : AdminTheme.cardBorder, width: active ? 1.5 : 1),
                    ),
                    child: Text(r.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? c : AdminTheme.textSecondary)),
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
                ? _db.collection('users').where('role', whereIn: ['delivery', 'manager', 'staff']).snapshots()
                : _db.collection('users').where('role', isEqualTo: _filterRole).snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AdminTheme.gold, strokeWidth: 2));
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.badge_outlined, color: AdminTheme.textMuted, size: 56),
                  const SizedBox(height: 16),
                  Text('No employees found', style: AdminTheme.heading(16)),
                  const SizedBox(height: 8),
                  GestureDetector(onTap: () => _showAddEmployeeSheet(ctx), child: const Text('Add first employee →', style: TextStyle(color: AdminTheme.gold, fontWeight: FontWeight.w700))),
                ]));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                itemCount: snap.data!.docs.length,
                itemBuilder: (_, i) {
                  final doc = snap.data!.docs[i];
                  final d = doc.data() as Map<String, dynamic>;
                  final role = d['role'] ?? 'staff';
                  final roleColor = role == 'delivery' ? AdminTheme.gold : role == 'manager' ? AdminTheme.violet : AdminTheme.amber;
                  final activeOrders = d['activeOrders'] ?? 0;
                  final completedOrders = d['completedOrders'] ?? 0;

                  return Container(
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
                                  backgroundColor: roleColor.withValues(alpha: 0.2),
                                  backgroundImage: d['photoURL'] != null ? NetworkImage(d['photoURL']) : null,
                                  child: d['photoURL'] == null ? Text((d['name'] as String? ?? 'E')[0].toUpperCase(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: roleColor)) : null,
                                ),
                                Positioned(bottom: 0, right: 0, child: Container(
                                  width: 14, height: 14,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: (d['isActive'] ?? true) ? AdminTheme.emerald : AdminTheme.rose, border: Border.all(color: AdminTheme.surface, width: 2)),
                                )),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(child: Text(d['name'] ?? 'Employee', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary))),
                                    AdminBadge(label: role, color: roleColor, fontSize: 10),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(d['email'] ?? '', style: AdminTheme.label(12)),
                                  const SizedBox(height: 4),
                                  Text(d['phone'] ?? '', style: AdminTheme.label(11).copyWith(color: AdminTheme.textMuted)),
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
                            _statCol('Active', activeOrders.toString(), AdminTheme.amber),
                            _divider(),
                            _statCol('Completed', completedOrders.toString(), AdminTheme.emerald),
                            _divider(),
                            _statCol('Rating', '${(d['rating'] ?? 4.5).toStringAsFixed(1)}⭐', AdminTheme.gold),
                          ],
                        ),

                        const SizedBox(height: 12),
                        Container(height: 1, color: AdminTheme.cardBorder),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showChangeRoleSheet(context, doc.id, d['name'] ?? '', role),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.violet.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AdminTheme.violet.withValues(alpha: 0.2)),
                                  ),
                                  child: const Text('Change Role', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.violet)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AdminTheme.surface,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: Text('Remove ${d['name'] ?? 'employee'}?', style: AdminTheme.heading(16)),
                                      content: const Text('This will set their role back to regular user.', style: TextStyle(color: AdminTheme.textSecondary)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Remove', style: TextStyle(color: AdminTheme.rose)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await RoleBasedAuthService().removeRole(doc.id);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.rose.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AdminTheme.rose.withValues(alpha: 0.2)),
                                  ),
                                  child: const Text('Remove Role', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.rose)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showChangeRoleSheet(BuildContext ctx, String uid, String name, String currentRole) {
    String selectedRole = currentRole;
    bool isLoading = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Container(
          decoration: const BoxDecoration(
            color: AdminTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AdminTheme.textMuted, borderRadius: BorderRadius.circular(2))),
              Text('Change Role — $name', style: AdminTheme.heading(18)),
              const SizedBox(height: 6),
              Text('Current role: ${currentRole.toUpperCase()}', style: AdminTheme.label(13)),
              const SizedBox(height: 24),
              Row(
                children: ['manager', 'delivery', 'staff'].map((r) {
                  final active = selectedRole == r;
                  final c = r == 'delivery' ? AdminTheme.gold : r == 'manager' ? AdminTheme.violet : AdminTheme.amber;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setLocal(() => selectedRole = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: r != 'staff' ? 10 : 0),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: active ? c.withValues(alpha: 0.2) : AdminTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: active ? c : AdminTheme.cardBorder, width: active ? 1.5 : 1),
                        ),
                        child: Text(r.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? c : AdminTheme.textSecondary)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.violet, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                  onPressed: isLoading ? null : () async {
                    setLocal(() => isLoading = true);
                    await RoleBasedAuthService().assignRole(uid, selectedRole);
                    if (ctx2.mounted) Navigator.pop(ctx2);
                  },
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('UPDATE ROLE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: AdminTheme.label(11)),
    ]);
  }

  Widget _divider() => Container(width: 1, height: 30, color: AdminTheme.cardBorder);

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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AdminTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AdminTheme.textMuted, borderRadius: BorderRadius.circular(2))),
                Text('Assign Role by Email', style: AdminTheme.heading(20)),
                const SizedBox(height: 6),
                Text('Assign a role to an existing registered user', style: AdminTheme.label(13)),
                const SizedBox(height: 24),
                _buildField(emailCtrl, 'User Email Address', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 14),
                Text('Role to Assign', style: AdminTheme.label(13)),
                const SizedBox(height: 8),
                Row(
                  children: ['manager', 'delivery', 'staff'].map((r) {
                    final active = selectedRole == r;
                    final c = r == 'delivery' ? AdminTheme.gold : r == 'manager' ? AdminTheme.violet : AdminTheme.amber;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setLocal(() => selectedRole = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(right: r != 'staff' ? 10 : 0),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? c.withValues(alpha: 0.2) : AdminTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: active ? c : AdminTheme.cardBorder, width: active ? 1.5 : 1),
                          ),
                          child: Text(r.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? c : AdminTheme.textSecondary)),
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
                    child: Text(feedback!, style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: feedback!.startsWith('✓') ? AdminTheme.emerald : AdminTheme.rose,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isLoading ? null : () async {
                      if (emailCtrl.text.trim().isEmpty) return;
                      setLocal(() { isLoading = true; feedback = null; });
                      final roleService = RoleBasedAuthService();
                      final result = await roleService.addRoleByEmail(emailCtrl.text.trim(), selectedRole);
                      setLocal(() {
                        isLoading = false;
                        if (result['success'] == true) {
                          feedback = '✓ Role assigned to ${result['name'] ?? emailCtrl.text}';
                          emailCtrl.clear();
                        } else {
                          feedback = '✗ ${result['error'] ?? 'Failed to assign role'}';
                        }
                      });
                    },
                    child: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('ASSIGN ROLE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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

  void _showAddEmployeeSheet(BuildContext ctx) {
    final db = FirebaseFirestore.instance;
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'delivery';
    bool isLoading = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: AdminTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AdminTheme.textMuted, borderRadius: BorderRadius.circular(2))),
                Text('Add New Employee', style: AdminTheme.heading(20)),
                const SizedBox(height: 6),
                Text('Create an employee account', style: AdminTheme.label(13)),
                const SizedBox(height: 24),

                _buildField(nameCtrl, 'Full Name', Icons.person_outline_rounded),
                const SizedBox(height: 14),
                _buildField(emailCtrl, 'Email Address', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _buildField(phoneCtrl, 'Phone Number', Icons.phone_outlined, keyboard: TextInputType.phone),
                const SizedBox(height: 14),

                Text('Role', style: AdminTheme.label(13)),
                const SizedBox(height: 8),
                Row(
                  children: ['delivery', 'manager', 'staff'].map((r) {
                    final active = selectedRole == r;
                    final c = r == 'delivery' ? AdminTheme.gold : r == 'manager' ? AdminTheme.violet : AdminTheme.amber;
                    return GestureDetector(
                      onTap: () => setLocal(() => selectedRole = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: active ? c.withValues(alpha: 0.2) : AdminTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: active ? c : AdminTheme.cardBorder, width: active ? 1.5 : 1),
                        ),
                        child: Text(r.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? c : AdminTheme.textSecondary)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.emerald, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    onPressed: isLoading ? null : () async {
                      if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                      setLocal(() => isLoading = true);
                      try {
                        final data = <String, dynamic>{
                          'name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'role': selectedRole,
                          'isBlocked': false,
                          'isActive': true,
                          'loyaltyPoints': 0,
                          'totalOrders': 0,
                          'totalSpent': 0.0,
                          'createdAt': FieldValue.serverTimestamp(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        // Add role-specific fields
                        if (selectedRole == 'delivery') {
                          data['isOnline'] = false;
                          data['vehicleType'] = 'bike';
                          data['deliveryStats'] = {
                            'totalDeliveries': 0,
                            'completedToday': 0,
                            'earnings': 0.0,
                            'rating': 5.0,
                          };
                        } else if (selectedRole == 'staff') {
                          data['department'] = 'washing';
                          data['shift'] = 'morning';
                          data['employeeId'] = 'EMP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        } else if (selectedRole == 'manager') {
                          data['managedStaffCount'] = 0;
                        }
                        await db.collection('users').add(data);
                        if (ctx2.mounted) Navigator.pop(ctx2);
                      } catch (e) {
                        setLocal(() => isLoading = false);
                      }
                    },
                    child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('CREATE EMPLOYEE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl, keyboardType: keyboard,
      style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, labelStyle: AdminTheme.label(13),
        prefixIcon: Icon(icon, color: AdminTheme.textSecondary, size: 20),
        filled: true, fillColor: AdminTheme.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AdminTheme.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AdminTheme.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminTheme.gold, width: 2)),
      ),
    );
  }
}
