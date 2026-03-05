import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _roleFilter = 'user';
  final _searchCtrl = TextEditingController();

  final _roles = ['user', 'admin', 'manager', 'delivery', 'staff'];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: AdminPageHeader(title: 'User Management', subtitle: 'Manage customers and their accounts'),
        ),

        // FILTERS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 14),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: AdminTheme.label(14),
                    prefixIcon: const Icon(Icons.search_rounded, color: AdminTheme.textSecondary, size: 20),
                    filled: true, fillColor: AdminTheme.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AdminTheme.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AdminTheme.cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminTheme.gold, width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: AdminTheme.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AdminTheme.cardBorder)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _roleFilter,
                    dropdownColor: AdminTheme.card,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminTheme.textSecondary),
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() => _roleFilter = v!),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').where('role', isEqualTo: _roleFilter).snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AdminTheme.gold, strokeWidth: 2));
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_outlined, color: AdminTheme.textMuted, size: 56),
                  const SizedBox(height: 16),
                  Text('No users found', style: AdminTheme.heading(16)),
                ]));
              }

              var docs = snap.data!.docs;
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['name'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
                         (data['email'] ?? '').toString().toLowerCase().contains(_searchQuery);
                }).toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (_, i) => _UserCard(doc: docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _UserCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final isBlocked = d['isBlocked'] ?? false;
    final role = d['role'] ?? 'user';
    final ts = (d['createdAt'] as Timestamp?)?.toDate();

    return GestureDetector(
      onTap: () => _showUserDetail(context, doc.id, d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AdminTheme.cardDecoration(),
        child: Row(
          children: [
            // AVATAR
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AdminTheme.gold.withValues(alpha: 0.2),
                  backgroundImage: (d['photoURL'] != null) ? NetworkImage(d['photoURL']) : null,
                  child: d['photoURL'] == null ? Text(
                    (d['name'] as String? ?? '').isNotEmpty ? (d['name'] as String)[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminTheme.gold),
                  ) : null,
                ),
                if (isBlocked)
                  Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: AdminTheme.rose, border: Border.all(color: AdminTheme.surface, width: 2)))),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(d['name'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary))),
                    AdminBadge(label: role, color: _roleColor(role), fontSize: 10),
                  ]),
                  const SizedBox(height: 4),
                  Text(d['email'] ?? '', style: AdminTheme.label(12)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.phone_outlined, size: 12, color: AdminTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(d['phone'] ?? 'No phone', style: AdminTheme.label(11).copyWith(color: AdminTheme.textMuted)),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today_outlined, size: 12, color: AdminTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(ts != null ? '${ts.day}/${ts.month}/${ts.year}' : 'N/A', style: AdminTheme.label(11).copyWith(color: AdminTheme.textMuted)),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AdminTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return AdminTheme.rose;
      case 'manager': return AdminTheme.violet;
      case 'delivery': return AdminTheme.gold;
      case 'staff': return AdminTheme.amber;
      default: return AdminTheme.emerald;
    }
  }

  void _showUserDetail(BuildContext ctx, String userId, Map<String, dynamic> d) {
    final db = FirebaseFirestore.instance;
    final roles = ['user', 'manager', 'delivery', 'staff', 'admin'];
    String selectedRole = d['role'] ?? 'user';
    bool isBlocked = d['isBlocked'] ?? false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(color: AdminTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: AdminTheme.textMuted, borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AdminTheme.gold.withValues(alpha: 0.2),
                          backgroundImage: (d['photoURL'] != null) ? NetworkImage(d['photoURL']) : null,
                          child: d['photoURL'] == null ? Text((d['name'] as String? ?? '').isNotEmpty ? (d['name'] as String)[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdminTheme.gold)) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['name'] ?? 'Unknown', style: AdminTheme.heading(18)),
                            Text(d['email'] ?? '', style: AdminTheme.label(13)),
                          ],
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: (isBlocked ? AdminTheme.rose : AdminTheme.emerald).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(isBlocked ? 'BLOCKED' : 'ACTIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isBlocked ? AdminTheme.rose : AdminTheme.emerald)),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      Text('Change Role', style: AdminTheme.heading(14)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: roles.map((r) => GestureDetector(
                          onTap: () => setLocal(() => selectedRole = r),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedRole == r ? AdminTheme.gold.withValues(alpha: 0.2) : AdminTheme.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: selectedRole == r ? AdminTheme.gold : AdminTheme.cardBorder, width: selectedRole == r ? 1.5 : 1),
                            ),
                            child: Text(r.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selectedRole == r ? AdminTheme.gold : AdminTheme.textSecondary)),
                          ),
                        )).toList(),
                      ),

                      const SizedBox(height: 24),

                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setLocal(() => isBlocked = !isBlocked),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: (isBlocked ? AdminTheme.emerald : AdminTheme.rose).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: (isBlocked ? AdminTheme.emerald : AdminTheme.rose).withValues(alpha: 0.3)),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded, color: isBlocked ? AdminTheme.emerald : AdminTheme.rose, size: 18),
                                const SizedBox(width: 8),
                                Text(isBlocked ? 'Unblock User' : 'Block User', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isBlocked ? AdminTheme.emerald : AdminTheme.rose)),
                              ]),
                            ),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.gold, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                          onPressed: () async {
                            await db.collection('users').doc(userId).update({'role': selectedRole, 'isBlocked': isBlocked, 'updatedAt': FieldValue.serverTimestamp()});
                            if (ctx2.mounted) Navigator.pop(ctx2);
                          },
                          child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
