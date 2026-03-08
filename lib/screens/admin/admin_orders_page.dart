import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';
import '../../services/employee_notification_service.dart';
import 'admin_theme.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});
  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  String _filterStatus = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;

  final List<String> _statuses = [
    'all',
    'pending',
    'assigned',
    'pickup',
    'processing',
    'delivery',
    'completed',
    'cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _statuses.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _filterStatus = _statuses[_tabCtrl.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: AdminPageHeader(
              title: 'Order Management',
              subtitle: 'Track, assign and update all orders'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: at.textPrimary, fontSize: 14),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search orders...',
              hintStyle: at.label(14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: at.textSecondary, size: 20),
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
                  borderSide:
                      const BorderSide(color: AdminTheme.gold, width: 2)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Pill-style status filter
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _statuses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = _statuses[i];
              final active = _filterStatus == s;
              return GestureDetector(
                onTap: () => setState(() {
                  _filterStatus = s;
                  _tabCtrl.animateTo(i);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AdminTheme.gold.withValues(alpha: 0.15) : at.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: active ? AdminTheme.gold : at.cardBorder,
                      width: active ? 1.5 : 1,
                    ),
                    boxShadow: active ? [
                      BoxShadow(color: AdminTheme.gold.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))
                    ] : null,
                  ),
                  child: Text(
                    s.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? AdminTheme.gold : at.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filterStatus == 'all'
                ? _db
                    .collection('orders')
                    .orderBy('createdAt', descending: true)
                    .snapshots()
                : _db
                    .collection('orders')
                    .where('status', isEqualTo: _filterStatus)
                    .orderBy('createdAt', descending: true)
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
                  Icon(Icons.shopping_bag_outlined,
                      color: at.textMuted, size: 56),
                  const SizedBox(height: 16),
                  Text('No orders found', style: at.heading(16)),
                ]));
              }

              var docs = snap.data!.docs;
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['customerName'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery) ||
                      d.id.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (_, i) => _AdminOrderCard(doc: docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _AdminOrderCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] ?? 'pending';
    final color = statusColor(status);
    final ts = (d['createdAt'] as Timestamp?)?.toDate();

    return GestureDetector(
      onTap: () => _showDetail(context, doc.id, d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: at.cardDecoration(),
        child: Column(children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(statusIcon(status), color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(d['customerName'] ?? 'Customer',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: at.textPrimary))),
                    AdminBadge(label: status, color: color, fontSize: 10),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      '#${doc.id.substring(0, 8).toUpperCase()}  •  ${d['serviceType'] ?? 'Laundry'}',
                      style: at.label(12)),
                ])),
          ]),
          const SizedBox(height: 14),
          Container(height: 1, color: at.cardBorder),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _chip(context, Icons.location_on_outlined,
                d['pickupAddress'] ?? d['address'] ?? 'N/A'),
            _chip(context, Icons.schedule_rounded,
                ts != null ? '${ts.day}/${ts.month}' : 'N/A'),
            Text('₹${(d['totalAmount'] ?? 0).toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: at.textPrimary)),
          ]),
          if (d['driverId'] != null) ...[
            const SizedBox(height: 10),
            Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AdminTheme.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.delivery_dining_rounded,
                        color: AdminTheme.emerald, size: 13),
                    const SizedBox(width: 5),
                    Text('Driver: ${d['driverName'] ?? 'Assigned'}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AdminTheme.emerald)),
                  ]),
                )),
          ],
        ]),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text) {
    final at = DynAdmin.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: at.textSecondary, size: 13),
        const SizedBox(width: 4),
        Text(text.length > 16 ? '${text.substring(0, 14)}...' : text,
            style: at.label(11)),
      ]);
  }

  void _showDetail(BuildContext ctx, String orderId, Map<String, dynamic> d) {
    final at = DynAdmin.of(ctx);
    final statuses = [
      'pending',
      'assigned',
      'pickup',
      'processing',
      'delivery',
      'completed',
      'cancelled'
    ];
    String selStatus = d['status'] ?? 'pending';
    String? selDriverId = d['driverId'];
    String? selDriverName = d['driverName'];
    final db = FirebaseFirestore.instance;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: BoxDecoration(
              color: at.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                    color: at.textMuted,
                    borderRadius: BorderRadius.circular(2))),
            Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order Details', style: at.heading(20)),
                          AdminBadge(
                              label: selStatus, color: statusColor(selStatus)),
                        ]),
                    const SizedBox(height: 4),
                    Text('#${orderId.substring(0, 8).toUpperCase()}',
                        style: at.label(13)),
                    const SizedBox(height: 24),

                    _section(ctx, 'Customer Info', [
                      _row(ctx, 'Name', d['customerName'] ?? 'N/A'),
                      _row(ctx, 'Phone', d['customerPhone'] ?? 'N/A'),
                      _row(ctx, 'Pickup',
                          d['pickupAddress'] ?? d['address'] ?? 'N/A'),
                      _row(ctx, 'Delivery', d['deliveryAddress'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 16),
                    _section(ctx, 'Order Info', [
                      _row(ctx, 'Service', d['serviceType'] ?? 'Laundry'),
                      _row(ctx, 'Amount',
                          '₹${(d['totalAmount'] ?? 0).toStringAsFixed(2)}'),
                      _row(ctx, 'Payment', d['paymentStatus'] ?? 'pending'),
                    ]),
                    const SizedBox(height: 16),

                    // DRIVER ASSIGNMENT
                    Text('Assign Driver', style: at.heading(15)),
                    const SizedBox(height: 12),
                    if (selDriverId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: AdminTheme.emerald.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AdminTheme.emerald.withValues(alpha: 0.3))),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AdminTheme.emerald, size: 16),
                          const SizedBox(width: 8),
                          Text('Assigned to: $selDriverName',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AdminTheme.emerald)),
                          const Spacer(),
                          GestureDetector(
                              onTap: () => setLocal(() {
                                    selDriverId = null;
                                    selDriverName = null;
                                  }),
                              child: const Icon(Icons.close_rounded,
                                  color: AdminTheme.rose, size: 18)),
                        ]),
                      ),
                    StreamBuilder<QuerySnapshot>(
                      stream: db
                          .collection('delivery_agents')
                          .where('isActive', isEqualTo: true)
                          .snapshots(),
                      builder: (_, dSnap) {
                        if (!dSnap.hasData) {
                          return const SizedBox(
                              height: 40,
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: AdminTheme.gold, strokeWidth: 2)));
                        }
                        final drivers = dSnap.data!.docs;
                        if (drivers.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: at.cardDecoration(),
                            child: Row(children: [
                              Icon(Icons.info_outline,
                                  color: at.textSecondary, size: 18),
                              const SizedBox(width: 10),
                              Text('No delivery drivers found',
                                  style: at.label(13)),
                            ]),
                          );
                        }
                        return Column(
                            children: drivers.map((dDoc) {
                          final dd = dDoc.data() as Map<String, dynamic>;
                          final dName =
                              dd['name'] ?? dd['displayName'] ?? 'Driver';
                          final online = dd['isOnline'] ?? false;
                          final isSel = selDriverId == dDoc.id;
                          return GestureDetector(
                            onTap: () => setLocal(() {
                              selDriverId = dDoc.id;
                              selDriverName = dName;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AdminTheme.gold.withValues(alpha: 0.1)
                                    : at.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isSel
                                        ? AdminTheme.gold
                                        : at.cardBorder,
                                    width: isSel ? 1.5 : 1),
                              ),
                              child: Row(children: [
                                CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        AdminTheme.gold.withValues(alpha: 0.2),
                                    child: Text(
                                        dName.isNotEmpty
                                            ? dName[0].toUpperCase()
                                            : 'D',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AdminTheme.gold))),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(dName,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: at.textPrimary)),
                                      Text(dd['phone'] ?? '',
                                          style: at.label(11)),
                                    ])),
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: online
                                            ? AdminTheme.emerald
                                            : at.textMuted,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 5),
                                Text(online ? 'Online' : 'Offline',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: online
                                            ? AdminTheme.emerald
                                            : at.textMuted)),
                                if (isSel) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded,
                                      color: AdminTheme.gold, size: 18)
                                ],
                              ]),
                            ),
                          );
                        }).toList());
                      },
                    ),

                    const SizedBox(height: 16),
                    Text('Update Status', style: at.heading(15)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statuses
                          .map((s) => GestureDetector(
                                onTap: () => setLocal(() => selStatus = s),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selStatus == s
                                        ? statusColor(s).withValues(alpha: 0.2)
                                        : at.card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: selStatus == s
                                            ? statusColor(s)
                                            : at.cardBorder,
                                        width: selStatus == s ? 1.5 : 1),
                                  ),
                                  child: Text(s.toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: selStatus == s
                                              ? statusColor(s)
                                              : at.textSecondary)),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.gold,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0),
                        onPressed: () async {
                          final resolvedStatus = selDriverId != null && selStatus == 'pending'
                              ? 'assigned'
                              : selStatus;
                          final upd = <String, dynamic>{
                            'status': resolvedStatus,
                            'updatedAt': FieldValue.serverTimestamp(),
                            'statusHistory': FieldValue.arrayUnion([{
                              'status': resolvedStatus,
                              'note': 'Updated by admin',
                              'timestamp': DateTime.now().toIso8601String(),
                            }]),
                          };
                          if (selDriverId != null) {
                            upd['driverId'] = selDriverId;
                            upd['driverName'] = selDriverName;
                          }
                          await db
                              .collection('orders')
                              .doc(orderId)
                              .update(upd);

                          // Fire local notification on admin's device
                          NotificationService().showOrderNotification(
                            title: '✅ Order Updated',
                            body: 'Order #${orderId.substring(0, 6).toUpperCase()} → $resolvedStatus',
                            orderId: orderId,
                          );
                          // Notify assigned delivery agent
                          if (selDriverId != null) {
                            final body2 = 'You have a new order! Order #${orderId.substring(0, 6).toUpperCase()} has been assigned to you. Open the app to accept.';
                            await db.collection('notifications').add({
                              'title': '🚴 New Order Assigned!',
                              'message': body2,
                              'body': body2,
                              'userId': selDriverId,
                              'orderId': orderId,
                              'type': 'order_assigned',
                              'createdAt': FieldValue.serverTimestamp(),
                              'isRead': false,
                            });
                          }
                          // Notify customer
                          if (d['userId'] != null) {
                            final customerBody = 'Your order #${orderId.substring(0, 6).toUpperCase()} has been updated to $selStatus';
                            await db.collection('notifications').add({
                              'title': 'Order Update',
                              'message': customerBody,
                              'userId': d['userId'],
                              'targetGroup': 'user',
                              'orderId': orderId,
                              'type': 'order_update',
                              'createdAt': FieldValue.serverTimestamp(),
                              'isRead': false,
                            });
                            // Send status update email to customer
                            try {
                              final custDoc = await db.collection('users').doc(d['userId']).get();
                              final custEmail = custDoc.data()?['email'] as String? ?? '';
                              final custName  = custDoc.data()?['name']  as String? ?? 'Customer';
                              if (custEmail.isNotEmpty) {
                                EmployeeNotificationService().sendOrderStatusEmail(
                                  name: custName,
                                  email: custEmail,
                                  orderId: orderId,
                                  newStatus: selStatus,
                                );
                              }
                            } catch (_) {}
                          }

                          if (ctx2.mounted) Navigator.pop(ctx2);
                        },
                        child: const Text('SAVE CHANGES',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2)),
                      ),
                    ),
                  ]),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _section(BuildContext ctx, String title, List<Widget> rows) {
    final at = DynAdmin.of(ctx);
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: at.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: at.heading(13)
                  .copyWith(color: at.textSecondary)),
          const SizedBox(height: 12),
          ...rows,
        ]));
  }
  Widget _row(BuildContext context, String label, String value) {
    final at = DynAdmin.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 80, child: Text(label, style: at.label(12))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: at.textPrimary))),
        ]),
      );
  }
}
