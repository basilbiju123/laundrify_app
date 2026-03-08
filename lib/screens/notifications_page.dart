import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════
// NOTIFICATIONS PAGE — Real Firestore backend, full dark mode
// ═══════════════════════════════════════════════════════════

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Mark all as read when user opens notifications page
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  Future<void> _markAllRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      // Fetch by single field only — multiple fields require a composite index.
      // Filter unread client-side before batching updates.
      final snap = await _db.collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      final snap2 = await _db.collection('notifications')
          .where('targetGroup', isEqualTo: 'all')
          .get();
      final snap3 = await _db.collection('notifications')
          .where('targetGroup', isEqualTo: 'users')
          .get();
      final batch = _db.batch();
      for (final doc in [...snap.docs, ...snap2.docs, ...snap3.docs]) {
        final data = doc.data();
        if (data['isRead'] != true) {
          batch.update(doc.reference, {'isRead': true});
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Mark all read error: \$e');
    }
  }

  Future<void> _markRead(String docId) async {
    try {
      await _db.collection('notifications').doc(docId).update({'isRead': true});
    } catch (_) {}
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'welcome':          return Icons.waving_hand_rounded;
      case 'employee_welcome': return Icons.work_rounded;
      case 'order_update': return Icons.local_laundry_service_rounded;
      case 'promo':        return Icons.local_offer_rounded;
      case 'payment':      return Icons.payment_rounded;
      default:             return Icons.notifications_rounded;
    }
  }

  Color _getColor(String? type) {
    switch (type) {
      case 'order_update': return AppColors.blue;
      case 'promo':        return AppColors.amber;
      case 'payment':      return AppColors.emerald;
      default:             return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t   = AppColors.of(context);
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
          ),
        ],
      ),
      body: uid == null
          ? Center(child: Text('Please log in', style: TextStyle(color: t.textHi)))
          : StreamBuilder<QuerySnapshot>(
              stream: _db.collection('notifications')
                  // Filter.or does not support orderBy without a composite index.
                  // Fetch all matching docs and sort client-side instead.
                  .where(Filter.or(
                    Filter('userId', isEqualTo: uid),
                    Filter('targetGroup', isEqualTo: 'all'),
                    Filter('targetGroup', isEqualTo: 'users'),
                  ))
                  .limit(100)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(
                      color: AppColors.blue, strokeWidth: 2));
                }

                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  final t = AppColors.of(context);
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.08),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_off_outlined,
                            color: AppColors.blue, size: 48),
                      ),
                      const SizedBox(height: 16),
                      Text('No notifications',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.textHi)),
                      const SizedBox(height: 6),
                      Text("You're all caught up!",
                          style: TextStyle(fontSize: 14, color: t.textDim)),
                    ]),
                  );
                }

                // Sort client-side by createdAt descending (no composite index needed)
                final docs = snap.data!.docs.toList()
                  ..sort((a, b) {
                    final aT = (a.data() as Map)['createdAt'] as Timestamp?;
                    final bT = (b.data() as Map)['createdAt'] as Timestamp?;
                    if (aT == null && bT == null) return 0;
                    if (aT == null) return 1;
                    if (bT == null) return -1;
                    return bT.compareTo(aT);
                  });

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final t = AppColors.of(context);
                    final doc    = docs[i];
                    final d      = doc.data() as Map<String, dynamic>;
                    final isRead = d['isRead'] as bool? ?? false;
                    final ts     = (d['createdAt'] as Timestamp?)?.toDate();
                    final type   = d['type'] as String?;
                    final color  = _getColor(type);

                    // Plain Container — avoid AnimatedContainer in streams to prevent flash
                    return GestureDetector(
                      onTap: () => _markRead(doc.id),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isRead
                              ? t.card
                              : AppColors.blue.withValues(alpha: t.isDark ? 0.12 : 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isRead ? t.cardBdr : AppColors.blue.withValues(alpha: 0.3),
                            width: isRead ? 1.0 : 1.5,
                          ),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: t.isDark ? 0.2 : 0.04),
                            blurRadius: 6, offset: const Offset(0, 2),
                          )],
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(_getIcon(type), color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(
                                  d['title'] as String? ?? 'Notification',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                      color: t.textHi))),
                              if (!isRead)
                                Container(width: 8, height: 8,
                                    decoration: BoxDecoration(
                                        color: AppColors.blue, shape: BoxShape.circle)),
                            ]),
                            const SizedBox(height: 4),
                            Text(d['message'] as String? ?? '',
                                style: TextStyle(fontSize: 13, color: t.textMid, height: 1.4),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(
                              ts != null ? _formatTime(ts) : '',
                              style: TextStyle(fontSize: 11, color: t.textDim, fontWeight: FontWeight.w500),
                            ),
                          ])),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
