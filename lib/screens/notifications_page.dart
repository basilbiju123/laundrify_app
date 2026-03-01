import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ═══════════════════════════════════════════════════════════
// NOTIFICATIONS PAGE — Real Firestore backend
// Shows notifications for the current user
// ═══════════════════════════════════════════════════════════

const _nPrimary  = Color(0xFF1B4FD8);
const _nSuccess  = Color(0xFF10B981);
const _nWarning  = Color(0xFFF59E0B);
const _nBg       = Color(0xFFF5F7FA);
const _nWhite    = Colors.white;
const _nTextD    = Color(0xFF111827);
const _nTextG    = Color(0xFF9CA3AF);
const _nBorder   = Color(0xFFE5E7EB);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> _markAllRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      // Mark user-specific notifications as read (both userId and customerId for backwards compat)
      final snap = await _db.collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      // Also mark general (all-user) notifications
      final snap2 = await _db.collection('notifications')
          .where('targetGroup', isEqualTo: 'all')
          .where('isRead', isEqualTo: false)
          .get();
      for (final doc in snap2.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Mark all read error: $e');
    }
  }

  Future<void> _markRead(String docId) async {
    try {
      await _db.collection('notifications').doc(docId).update({'isRead': true});
    } catch (_) {}
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'order_update': return Icons.local_laundry_service_rounded;
      case 'promo':        return Icons.local_offer_rounded;
      case 'payment':      return Icons.payment_rounded;
      default:             return Icons.notifications_rounded;
    }
  }

  Color _getColor(String? type) {
    switch (type) {
      case 'order_update': return _nPrimary;
      case 'promo':        return _nWarning;
      case 'payment':      return _nSuccess;
      default:             return _nPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: _nBg,
      appBar: AppBar(
        backgroundColor: _nWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _nTextD),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _nTextD)),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _nPrimary)),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<QuerySnapshot>(
              stream: _db.collection('notifications')
                  .where(Filter.or(
                    Filter('userId', isEqualTo: uid),
                    Filter('targetGroup', isEqualTo: 'all'),
                    Filter('targetGroup', isEqualTo: 'users'),
                  ))
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _nPrimary, strokeWidth: 2));
                }

                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _nPrimary.withValues(alpha: 0.08), shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_off_outlined, color: _nPrimary, size: 48)),
                      const SizedBox(height: 16),
                      const Text('No notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _nTextD)),
                      const SizedBox(height: 6),
                      const Text('You\'re all caught up!', style: TextStyle(fontSize: 14, color: _nTextG)),
                    ]),
                  );
                }

                final docs = snap.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final d = doc.data() as Map<String, dynamic>;
                    final isRead = d['isRead'] ?? false;
                    final ts = (d['createdAt'] as Timestamp?)?.toDate();
                    final type = d['type'] as String?;
                    final color = _getColor(type);

                    return GestureDetector(
                      onTap: () => _markRead(doc.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isRead ? _nWhite : _nPrimary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isRead ? _nBorder : _nPrimary.withValues(alpha: 0.2), width: isRead ? 1 : 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                            child: Icon(_getIcon(type), color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(d['title'] ?? 'Notification',
                                  style: TextStyle(fontSize: 14, fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, color: _nTextD))),
                              if (!isRead)
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: _nPrimary, shape: BoxShape.circle)),
                            ]),
                            const SizedBox(height: 4),
                            Text(d['message'] ?? '', style: const TextStyle(fontSize: 13, color: _nTextG, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(ts != null ? _formatTime(ts) : '', style: const TextStyle(fontSize: 11, color: _nTextG, fontWeight: FontWeight.w500)),
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
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
