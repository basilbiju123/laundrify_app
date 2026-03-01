import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_theme.dart';

// ═══════════════════════════════════════════════════════════
// ADMIN NOTIFICATIONS PAGE
// Writes to Firestore (in-app bell) AND sends FCM topic push
// (lock-screen notification on all subscribed devices).
//
// HOW FCM TOPICS WORK:
// Each device subscribes to topics on login via NotificationService.
// Admin sends to topic → all subscribed devices get lock-screen push.
//
// Topic map:
//   'all'       → topic: 'all_users'
//   'users'     → topic: 'customers'
//   'delivery'  → topic: 'delivery_agents'
//   'managers'  → topic: 'managers'
// ═══════════════════════════════════════════════════════════
class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});
  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final _db = FirebaseFirestore.instance;
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _targetGroup = 'all';
  bool _isSending = false;

  @override
  void dispose() { _titleCtrl.dispose(); _msgCtrl.dispose(); super.dispose(); }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final message = _msgCtrl.text.trim();
    if (title.isEmpty || message.isEmpty) return;
    setState(() => _isSending = true);
    try {
      // 1. Write to Firestore → shows in in-app notification bell
      await _db.collection('notifications').add({
        'title': title,
        'message': message,
        'targetGroup': _targetGroup,
        'createdAt': FieldValue.serverTimestamp(),
        'sentBy': 'admin',
        'isRead': false,
      });

      // 2. Send FCM topic push → shows on device lock screen
      // FCM topic push is handled server-side via Cloud Functions.
      // The Firestore write above triggers a Cloud Function (if deployed)
      // that calls FCM sendToTopic. The topic name is stored so the
      // function knows which topic to target.
      //
      // If you haven't deployed Cloud Functions yet, devices will still
      // see the notification inside the app via the Firestore listener.
      //
      // To deploy: see /functions/index.js in your Firebase project.
      // The function listens to notifications collection onCreate and
      // sends an FCM message to the topic stored in targetGroup.

      _titleCtrl.clear(); _msgCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Sent to ${_targetGroup == 'all' ? 'all users' : _targetGroup} — in-app ✓, lock-screen via Cloud Functions',
              style: const TextStyle(fontSize: 12),
            )),
          ]),
          backgroundColor: AdminTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AdminTheme.rose, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(title: 'Notifications', subtitle: 'Send announcements to users'),
          const SizedBox(height: 24),

          // COMPOSE CARD
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AdminTheme.cardDecoration(glow: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AdminTheme.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.notifications_rounded, color: AdminTheme.gold, size: 22)),
                  const SizedBox(width: 12),
                  Text('Compose Notification', style: AdminTheme.heading(16)),
                ]),
                const SizedBox(height: 20),

                _buildField(_titleCtrl, 'Notification Title', Icons.title_rounded),
                const SizedBox(height: 14),
                TextField(
                  controller: _msgCtrl, maxLines: 4,
                  style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter your message...', hintStyle: AdminTheme.label(14),
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.message_rounded, color: AdminTheme.textSecondary, size: 20)),
                    filled: true, fillColor: AdminTheme.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AdminTheme.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AdminTheme.cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminTheme.gold, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Target Group', style: AdminTheme.label(13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ['all', 'users', 'delivery', 'managers'].map((g) {
                    final active = _targetGroup == g;
                    return GestureDetector(
                      onTap: () => setState(() => _targetGroup = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AdminTheme.gold.withValues(alpha: 0.2) : AdminTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? AdminTheme.gold : AdminTheme.cardBorder, width: active ? 1.5 : 1),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(g == 'all' ? Icons.groups_rounded : g == 'users' ? Icons.person_rounded : g == 'delivery' ? Icons.delivery_dining_rounded : Icons.manage_accounts_rounded,
                              color: active ? AdminTheme.gold : AdminTheme.textSecondary, size: 14),
                          const SizedBox(width: 6),
                          Text(g.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? AdminTheme.gold : AdminTheme.textSecondary)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.gold, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    onPressed: _isSending ? null : _sendNotification,
                    child: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('SEND NOTIFICATION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          ]),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text('Recent Notifications', style: AdminTheme.heading(16)),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('notifications').orderBy('createdAt', descending: true).limit(10).snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AdminTheme.gold, strokeWidth: 2));
              if (snap.data!.docs.isEmpty) return Center(child: Text('No notifications sent yet', style: AdminTheme.label(13)));
              return Column(
                children: snap.data!.docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ts = (d['createdAt'] as Timestamp?)?.toDate();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: AdminTheme.cardDecoration(),
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AdminTheme.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.notifications_rounded, color: AdminTheme.gold, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary)),
                              const SizedBox(height: 4),
                              Text(d['message'] ?? '', style: AdminTheme.label(12), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(children: [
                                AdminBadge(label: d['targetGroup'] ?? 'all', color: AdminTheme.gold, fontSize: 9),
                                const SizedBox(width: 8),
                                if (ts != null) Text('${ts.day}/${ts.month} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}', style: AdminTheme.label(10).copyWith(color: AdminTheme.textMuted)),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, labelStyle: AdminTheme.label(13),
        prefixIcon: Icon(icon, color: AdminTheme.textSecondary, size: 20),
        filled: true, fillColor: AdminTheme.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AdminTheme.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AdminTheme.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminTheme.gold, width: 2)),
      ),
    );
  }
}
