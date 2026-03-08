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
  String _statusFilter = 'all'; // all | active | blocked
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _usersStream =>
      _db.collection('users').where('role', isEqualTo: 'user').snapshots();

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: AdminPageHeader(
            title: 'User Management',
            subtitle: 'Customers using the Laundrify app',
          ),
        ),

        // SEARCH + STATUS FILTER
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: at.textPrimary, fontSize: 14),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email…',
                    hintStyle: TextStyle(color: at.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: at.textMuted, size: 20),
                    filled: true,
                    fillColor: at.card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: at.cardBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: at.cardBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AdminTheme.gold, width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: at.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: at.cardBorder)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    dropdownColor: at.card,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: at.textPrimary),
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: at.textSecondary),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('ALL')),
                      DropdownMenuItem(value: 'active', child: Text('ACTIVE')),
                      DropdownMenuItem(value: 'blocked', child: Text('BLOCKED')),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v!),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _usersStream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AdminTheme.gold, strokeWidth: 2));
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_outlined,
                        color: at.textMuted, size: 56),
                    const SizedBox(height: 16),
                    Text('No customers yet',
                        style: at.heading(16)),
                    const SizedBox(height: 6),
                    Text('Users who sign up via the app appear here',
                        style: TextStyle(color: at.textSecondary, fontSize: 13)),
                  ]),
                );
              }

              var docs = snap.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                if (_statusFilter == 'active' &&
                    (data['isBlocked'] ?? false) == true) { return false; }
                if (_statusFilter == 'blocked' &&
                    (data['isBlocked'] ?? false) == false) { return false; }
                if (_searchQuery.isNotEmpty) {
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  if (!name.contains(_searchQuery) &&
                      !email.contains(_searchQuery)) { return false; }
                }
                return true;
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off_rounded,
                        color: at.textMuted, size: 48),
                    const SizedBox(height: 12),
                    Text('No results found', style: at.heading(15)),
                  ]),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AdminTheme.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AdminTheme.emerald.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          '${docs.length} customer${docs.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AdminTheme.emerald),
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (_, i) => _UserCard(doc: docs[i]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── User Card ──────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _UserCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    final d = doc.data() as Map<String, dynamic>;
    final isBlocked = d['isBlocked'] ?? false;
    final ts = (d['createdAt'] as Timestamp?)?.toDate();
    final orders = d['totalOrders'] ?? 0;

    return GestureDetector(
      onTap: () => _showUserDetail(context, doc.id, d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: at.cardDecoration(),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AdminTheme.gold.withValues(alpha: 0.2),
                  backgroundImage: d['photoURL'] != null
                      ? NetworkImage(d['photoURL'])
                      : null,
                  child: d['photoURL'] == null
                      ? Text(
                          (d['name'] as String? ?? '').isNotEmpty
                              ? (d['name'] as String)[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AdminTheme.gold),
                        )
                      : null,
                ),
                if (isBlocked)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AdminTheme.rose,
                          border: Border.all(color: at.surface, width: 2)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        d['name'] ?? 'Unknown',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: at.textPrimary),
                      ),
                    ),
                    if (isBlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AdminTheme.rose.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('BLOCKED',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AdminTheme.rose)),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(d['email'] ?? '',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: at.textSecondary)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.phone_outlined,
                        size: 11, color: at.textMuted),
                    const SizedBox(width: 3),
                    Text(d['phone'] ?? 'No phone',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: at.textMuted)),
                    const SizedBox(width: 14),
                    Icon(Icons.shopping_bag_outlined,
                        size: 11, color: at.textMuted),
                    const SizedBox(width: 3),
                    Text('$orders orders',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: at.textMuted)),
                    const SizedBox(width: 14),
                    Icon(Icons.calendar_today_outlined,
                        size: 11, color: at.textMuted),
                    const SizedBox(width: 3),
                    Text(
                        ts != null
                            ? '${ts.day}/${ts.month}/${ts.year}'
                            : 'N/A',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: at.textMuted)),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: at.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  void _showUserDetail(
      BuildContext ctx, String userId, Map<String, dynamic> d) {
    final at = DynAdmin.of(ctx);
    final db = FirebaseFirestore.instance;
    bool isBlocked = d['isBlocked'] ?? false;
    bool isSaving = false;
    final orders = d['totalOrders'] ?? 0;
    final spent = (d['totalSpent'] ?? 0.0).toDouble();
    final points = d['loyaltyPoints'] ?? 0;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Container(
          height: MediaQuery.of(ctx).size.height * 0.78,
          decoration: BoxDecoration(
              color: at.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            children: [
              // Handle bar
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                      color: at.cardBorder,
                      borderRadius: BorderRadius.circular(2))),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User header
                      Row(children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor:
                              AdminTheme.gold.withValues(alpha: 0.2),
                          backgroundImage: d['photoURL'] != null
                              ? NetworkImage(d['photoURL'])
                              : null,
                          child: d['photoURL'] == null
                              ? Text(
                                  (d['name'] as String? ?? '').isNotEmpty
                                      ? (d['name'] as String)[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: AdminTheme.gold))
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['name'] ?? 'Unknown',
                                  style: at.heading(18)),
                              const SizedBox(height: 3),
                              Text(d['email'] ?? '',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: at.textSecondary)),
                              const SizedBox(height: 3),
                              Text(d['phone'] ?? 'No phone',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: at.textMuted)),
                            ],
                          ),
                        ),
                        // Status badge — updates live as toggle changes
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: (isBlocked
                                      ? AdminTheme.rose
                                      : AdminTheme.emerald)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                              isBlocked ? 'BLOCKED' : 'ACTIVE',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isBlocked
                                      ? AdminTheme.rose
                                      : AdminTheme.emerald)),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      // Stats row
                      Row(children: [
                        _statTile(ctx2, 'Orders', '$orders',
                            Icons.shopping_bag_outlined, AdminTheme.gold),
                        const SizedBox(width: 10),
                        _statTile(ctx2, 'Spent',
                            '₹${spent.toStringAsFixed(0)}',
                            Icons.currency_rupee_rounded, AdminTheme.emerald),
                        const SizedBox(width: 10),
                        _statTile(ctx2, 'Points', '$points',
                            Icons.stars_rounded, AdminTheme.violet),
                      ]),

                      const SizedBox(height: 20),

                      if (d['authMethod'] != null) ...[
                        _infoRow(ctx2, Icons.login_rounded, 'Auth Method',
                            (d['authMethod'] as String).toUpperCase()),
                        const SizedBox(height: 8),
                      ],
                      if (d['createdAt'] != null) ...[
                        Builder(builder: (context) {
                          final ts =
                              (d['createdAt'] as Timestamp?)?.toDate();
                          return _infoRow(
                              ctx2,
                              Icons.calendar_today_outlined,
                              'Joined',
                              ts != null
                                  ? '${ts.day}/${ts.month}/${ts.year}'
                                  : '—');
                        }),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 24),

                      // Block / Unblock toggle
                      GestureDetector(
                        onTap: () => setLocal(() => isBlocked = !isBlocked),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: (isBlocked
                                    ? AdminTheme.emerald
                                    : AdminTheme.rose)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: (isBlocked
                                        ? AdminTheme.emerald
                                        : AdminTheme.rose)
                                    .withValues(alpha: 0.35)),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    isBlocked
                                        ? Icons.lock_open_rounded
                                        : Icons.block_rounded,
                                    color: isBlocked
                                        ? AdminTheme.emerald
                                        : AdminTheme.rose,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(
                                    isBlocked
                                        ? 'Tap to Unblock User'
                                        : 'Tap to Block User',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isBlocked
                                            ? AdminTheme.emerald
                                            : AdminTheme.rose)),
                              ]),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Save button — actually commits to Firestore
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.gold,
                              foregroundColor: const Color(0xFF080F1E),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setLocal(() => isSaving = true);
                                  try {
                                    // Update /users
                                    await db
                                        .collection('users')
                                        .doc(userId)
                                        .update({
                                      'isBlocked': isBlocked,
                                      'updatedAt':
                                          FieldValue.serverTimestamp(),
                                    });
                                    // Also update employee role collections
                                    for (final col in ['delivery_agents', 'managers', 'staff']) {
                                      try {
                                        final doc = await db.collection(col).doc(userId).get();
                                        if (doc.exists) {
                                          await db.collection(col).doc(userId).update({
                                            'isBlocked': isBlocked,
                                            'updatedAt': FieldValue.serverTimestamp(),
                                          });
                                        }
                                      } catch (_) {}
                                    }
                                    if (ctx2.mounted) {
                                      Navigator.pop(ctx2);
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Row(children: [
                                            Icon(
                                                isBlocked
                                                    ? Icons.block_rounded
                                                    : Icons
                                                        .check_circle_rounded,
                                                color: Colors.white,
                                                size: 18),
                                            const SizedBox(width: 10),
                                            Text(
                                              isBlocked
                                                  ? 'User blocked successfully'
                                                  : 'User unblocked successfully',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w700),
                                            ),
                                          ]),
                                          backgroundColor: isBlocked
                                              ? AdminTheme.rose
                                              : AdminTheme.emerald,
                                          behavior:
                                              SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          duration:
                                              const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setLocal(() => isSaving = false);
                                    if (ctx2.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e',
                                              style: const TextStyle(
                                                  color: Colors.white)),
                                          backgroundColor: AdminTheme.rose,
                                          behavior:
                                              SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF080F1E)))
                              : const Text('SAVE CHANGES',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 1.2)),
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

  Widget _statTile(BuildContext ctx, String label, String value,
      IconData icon, Color color) {
    final at = DynAdmin.of(ctx);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: at.textMuted,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _infoRow(BuildContext ctx, IconData icon, String label, String value) {
    final at = DynAdmin.of(ctx);
    return Row(children: [
      Icon(icon, size: 14, color: at.textSecondary),
      const SizedBox(width: 8),
      Text('$label: ',
          style: TextStyle(
              fontSize: 12,
              color: at.textMuted,
              fontWeight: FontWeight.w600)),
      Text(value,
          style: TextStyle(
              fontSize: 12,
              color: at.textPrimary,
              fontWeight: FontWeight.w700)),
    ]);
  }
}
