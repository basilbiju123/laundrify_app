// ═══════════════════════════════════════════════════════════
//  order_history_page.dart
//
//  pubspec.yaml dependencies required:
//    firebase_core: ^3.x.x
//    firebase_auth: ^5.x.x
//    cloud_firestore: ^5.x.x
//    pdf: ^3.10.8
//    printing: ^5.12.0
// ═══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── Design tokens ──────────────────────────────────────────
const _hNavy = Color(0xFF080F1E);
const _hNMid = Color(0xFF0D1F3C);
const _hBlue = Color(0xFF1B4FD8);
const _hGold = Color(0xFFF5C518);
const _hGreen = Color(0xFF10B981);
const _hRed = Color(0xFFEF4444);
const _hAmber = Color(0xFFF59E0B);

Color _hAccent(String n) {
  switch (n) {
    case 'Laundry':
      return const Color(0xFF1B4FD8);
    case 'Dry Clean':
      return const Color(0xFF7C3AED);
    case 'Shoe Clean':
      return const Color(0xFF0891B2);
    case 'Bag Clean':
      return const Color(0xFFD97706);
    case 'Carpet':
      return const Color(0xFF059669);
    case 'Curtain':
      return const Color(0xFFE11D48);
    default:
      return const Color(0xFF1B4FD8);
  }
}

IconData _hIcon(String n) {
  switch (n) {
    case 'Laundry':
      return Icons.local_laundry_service_rounded;
    case 'Dry Clean':
      return Icons.dry_cleaning_rounded;
    case 'Shoe Clean':
      return Icons.cleaning_services_rounded;
    case 'Bag Clean':
      return Icons.shopping_bag_outlined;
    case 'Carpet':
      return Icons.grid_on_rounded;
    case 'Curtain':
      return Icons.curtains_rounded;
    default:
      return Icons.category_rounded;
  }
}

// ── Firestore helper: save an order ────────────────────────
// Call this from PaymentPage after successful payment:
//
//   await OrderService.saveOrder(orderData);
//
class OrderService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Saves a confirmed order to Firestore under the current user.
  /// [orderData] is the same map built in PaymentPage._buildOrderRecord().
  static Future<void> saveOrder(Map<String, dynamic> orderData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('orders')
        .doc(orderData['orderId'] as String)
        .set({
      ...orderData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of all orders for the current user, newest first.
  static Stream<List<Map<String, dynamic>>> ordersStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }
}

// ════════════════════════════════════════════════════════════
//  OrderHistoryPage — StatefulWidget with Firestore stream
// ════════════════════════════════════════════════════════════
class OrderHistoryPage extends StatefulWidget {
  /// Pass this when navigating from PaymentPage so the just-placed
  /// order appears immediately while Firestore syncs.
  final List<Map<String, dynamic>>? initialOrders;

  const OrderHistoryPage({super.key, this.initialOrders});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  String _filter = "All";
  final _filters = ["All", "Pending", "Processing", "Completed", "Cancelled"];

  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> all) {
    // Always exclude 'failed' from main list — shown separately
    final nonFailed = all.where((o) => ((o['status'] ?? '') as String).toLowerCase() != 'failed').toList();
    if (_filter == "All") return nonFailed;
    return nonFailed.where((o) {
      final status = ((o['status'] ?? '') as String).toLowerCase();
      final filterLower = _filter.toLowerCase();
      if (filterLower == 'processing') {
        return ['processing', 'assigned', 'pickup', 'confirmed', 'accepted', 'reached', 'picked', 'out_for_delivery'].contains(status);
      }
      if (filterLower == 'completed') {
        return ['completed', 'delivered'].contains(status);
      }
      return status == filterLower;
    }).toList();
  }

  List<Map<String, dynamic>> _getFailedOrders(List<Map<String, dynamic>> all) {
    return all.where((o) => ((o['status'] ?? '') as String).toLowerCase() == 'failed').toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: OrderService.ordersStream(),
        initialData: widget.initialOrders ?? [],
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              (snapshot.data?.isEmpty ?? true)) {
            return _loadingState();
          }
          if (snapshot.hasError) {
            return _errorState(snapshot.error.toString());
          }

          final allOrders = snapshot.data ?? [];
          final shown = _filterOrders(allOrders);

          return CustomScrollView(
            slivers: [
              // ── Gradient SliverAppBar ──────────────────────
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: _hNavy,
                foregroundColor: Colors.white,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                elevation: 0,
                leading: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18))),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Order History",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20)),
                      Text(
                          "${allOrders.length} order${allOrders.length != 1 ? 's' : ''}",
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [_hNavy, _hNMid],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Icon(Icons.history_rounded,
                                color: _hGold, size: 42)),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Filter chips ───────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final t = AppColors.of(context);
                        final isSel = _filter == f;
                        final count = f == "All"
                            ? allOrders.length
                            : allOrders.where((o) => ((o['status'] ?? '') as String).toLowerCase() == f.toLowerCase()).length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                  color: isSel ? AppColors.navy : t.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: isSel
                                          ? _hNavy
                                          : Colors.grey.withValues(alpha: 0.25),
                                      width: isSel ? 0 : 1),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                              color: _hNavy.withValues(
                                                  alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3))
                                        ]
                                      : [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2))
                                        ]),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(f,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isSel ? Colors.white : t.textMid)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: isSel ? AppColors.gold.withValues(alpha: 0.25) : t.surface,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Text("$count",
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isSel ? AppColors.gold : t.textDim)),
                                    ),
                                  ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // ── Orders list / empty state ──────────────────
              shown.isEmpty && _getFailedOrders(allOrders).isEmpty
                  ? SliverFillRemaining(child: _emptyState(_filter))
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _orderCard(ctx, shown[i]),
                          childCount: shown.length,
                        ),
                      ),
                    ),

              // ── Failed orders section ──────────────────────
              if (_getFailedOrders(allOrders).isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: t.isDark ? const Color(0xFF2A1515) : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Failed Orders (${_getFailedOrders(allOrders).length})',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.red.shade700)),
                      ]),
                    ),
                  ),
                ),
              if (_getFailedOrders(allOrders).isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _failedOrderCard(ctx, _getFailedOrders(allOrders)[i]),
                      childCount: _getFailedOrders(allOrders).length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Order card ─────────────────────────────────────────────
  Widget _orderCard(BuildContext context, Map<String, dynamic> order) {
    final t = AppColors.of(context);
    final services = (order['services'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final total = ((order['total'] ?? order['totalAmount'] ?? order['grandTotal'] ?? 0) as num).toDouble();
    final status = (order['status'] as String?) ?? 'Confirmed';
    final orderId = (order['orderId'] ?? order['id'] ?? '') as String;
    final displayId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();

    int totalItems = 0;
    for (final svc in services) {
      final items = svc['items'] as List? ?? [];
      for (final i in items) {
        totalItems += (i['qty'] as int? ?? 0);
      }
    }

    return GestureDetector(
      onTap: () => _showInvoiceSheet(context, order),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 5))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card header ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: t.isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.navy.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22))),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_hNavy, _hNMid]),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.receipt_long_rounded,
                    color: _hGold, size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text("#$displayId",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: t.textHi)),
                  const SizedBox(height: 2),
                  Text(
                      "${order['orderDate'] ?? ''}  ·  ${order['orderTime'] ?? ''}",
                      style: TextStyle(fontSize: 11, color: t.textDim)),
                ])),
            _statusBadge(status),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Service rows ─────────────────────────────────
            ...services.map((svc) {
              final t = AppColors.of(context);
              final sName = (svc['serviceName'] as String?) ?? '';
              final items = (svc['items'] as List?) ?? [];
              final accent = _hAccent(sName);
              final sTotal = items.fold<double>(
                  0.0,
                  (s, i) =>
                      s + ((i as Map)['qty'] as int) * ((i)['price'] as num));
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9)),
                      child: Icon(_hIcon(sName), color: accent, size: 15)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(sName,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: t.textHi)),
                        Text(
                            "${items.length} item${items.length > 1 ? 's' : ''}  ·  "
                            "$totalItems total",
                            style:
                                TextStyle(fontSize: 11, color: t.textDim)),
                      ])),
                  Text("₹${sTotal.toStringAsFixed(0)}",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                ]),
              );
            }),

            Container(height: 1, color: t.divider),
            const SizedBox(height: 10),

            // ── Schedule + Payment ───────────────────────────
            Row(children: [
              Icon(Icons.upload_rounded, size: 13, color: t.textDim),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(
                      "Pickup: ${order['pickupDate'] ?? ''}  ${order['pickupTime'] ?? ''}",
                      style: TextStyle(fontSize: 11, color: t.textDim))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.download_rounded, size: 13, color: t.textDim),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(
                      "Delivery: ${order['deliveryDate'] ?? ''}  ${order['deliveryTime'] ?? ''}",
                      style: TextStyle(fontSize: 11, color: t.textDim))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.payment_rounded, size: 13, color: t.textDim),
              const SizedBox(width: 4),
              Text(order['paymentMethod'] ?? 'N/A',
                  style: TextStyle(fontSize: 11, color: t.textDim)),
              const Spacer(),
              Icon(Icons.location_on_rounded, size: 13, color: t.textDim),
              const SizedBox(width: 4),
              Text(order['addressLabel'] ?? '',
                  style: TextStyle(fontSize: 11, color: t.textDim)),
            ]),
          ]),
        ),

        // ── Total + Action buttons ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Total Paid",
                    style: TextStyle(fontSize: 11, color: t.textDim)),
                const SizedBox(height: 2),
                Text("₹${total.toStringAsFixed(2)}",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: t.textHi)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () => _showInvoiceSheet(context, order),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_hNavy, _hNMid],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: _hNavy.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.picture_as_pdf_rounded,
                        color: _hGold, size: 15),
                    const SizedBox(width: 6),
                    const Text("Invoice",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ]),
                ),
              ),
            ]),

          ]),
        ),
      ]),
    ),  // closes GestureDetector
    );
  }

  // ── Failed order card ─────────────────────────────────────────
  Widget _failedOrderCard(BuildContext context, Map<String, dynamic> order) {
    final t = AppColors.of(context);
    final orderId = (order['id'] ?? order['orderId'] ?? '') as String;
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final total = ((order['totalAmount'] ?? order['total'] ?? 0) as num).toDouble();
    final date = order['pickupDate'] ?? order['orderDate'] ?? '';
    final reason = order['failureReason'] ?? order['cancellationReason'] ?? 'Payment failed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.error_rounded, color: Colors.red.shade600, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#$shortId', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0A1628))),
              const SizedBox(height: 2),
              Text(reason, style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
              if (date.isNotEmpty)
                Text(date, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0A1628))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
              child: Text('FAILED',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.red.shade700, letterSpacing: 0.5)),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Status badge ───────────────────────────────────────────
  Widget _statusBadge(String status) {
    final t = AppColors.of(context);
    final Color bg, fg;
    final IconData icon;

    switch (status.toLowerCase()) {
      case 'completed':
        bg = _hGreen.withValues(alpha: 0.1);
        fg = _hGreen;
        icon = Icons.check_circle_rounded;
        break;
      case 'processing':
        bg = _hAmber.withValues(alpha: 0.1);
        fg = _hAmber;
        icon = Icons.autorenew_rounded;
        break;
      case 'confirmed':
        bg = _hBlue.withValues(alpha: 0.1);
        fg = _hBlue;
        icon = Icons.schedule_rounded;
        break;
      case 'cancelled':
        bg = _hRed.withValues(alpha: 0.1);
        fg = _hRed;
        icon = Icons.cancel_rounded;
        break;
      case 'failed':
        bg = const Color(0xFF7C3AED).withValues(alpha: 0.1);
        fg = const Color(0xFF7C3AED);
        icon = Icons.error_rounded;
        break;
      default:
        bg = t.textDim.withValues(alpha: 0.1);
        fg = t.textDim;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg, size: 13),
        const SizedBox(width: 5),
        Text(status,
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  // ── Empty state ────────────────────────────────────────────
  Widget _emptyState(String filter) {
    final t = AppColors.of(context);
    final isAll = filter == "All";
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              color: _hBlue.withValues(alpha: 0.07), shape: BoxShape.circle),
          child:
              const Icon(Icons.receipt_long_outlined, color: _hBlue, size: 52)),
      const SizedBox(height: 18),
      Text(isAll ? "No orders yet" : "No $filter orders",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900, color: t.textHi)),
      const SizedBox(height: 6),
      Text(
          isAll
              ? "Your orders will appear here after booking."
              : "No orders found with status \"$filter\".",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: t.textDim)),
    ]));
  }

  // ── Loading ────────────────────────────────────────────────
  Widget _loadingState() {
    final t = AppColors.of(context);
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: _hNavy, strokeWidth: 3)),
        const SizedBox(height: 16),
        Text("Loading your orders...",
            style: TextStyle(
                fontSize: 14, color: t.textDim, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Error ──────────────────────────────────────────────────
  Widget _errorState(String msg) {
    final t = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: _hRed.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  color: _hRed, size: 48)),
          const SizedBox(height: 16),
          Text("Could not load orders",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: t.textHi)),
          const SizedBox(height: 6),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.textDim)),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _hNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text("Retry",
                  style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ),
    );
  }

  // ── Invoice popup sheet ────────────────────────────────────
  void _showInvoiceSheet(BuildContext context, Map<String, dynamic> order) {
    final t = AppColors.of(context);
    final orderId = (order['orderId'] ?? order['id'] ?? '') as String;
    final displayId = orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();
    final services = (order['services'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final status = (order['status'] ?? 'pending') as String;

    // Compute totals
    double computedSubtotal = 0;
    for (final svc in services) {
      for (final item in (svc['items'] as List? ?? [])) {
        final m = item as Map;
        computedSubtotal +=
            ((m['qty'] as int? ?? 0) * (m['price'] as num? ?? 0));
      }
    }
    final subtotal =
        ((order['subtotal'] as num?)?.toDouble() ?? 0) > 0
            ? (order['subtotal'] as num).toDouble()
            : computedSubtotal;
    final delivery = (order['deliveryFee'] as num? ?? 0).toDouble();
    final gst = (order['gst'] as num? ?? 0).toDouble();
    final couponDiscount = (order['couponDiscount'] as num? ?? 0).toDouble();
    final couponCode = order['couponCode'] as String?;
    final originalTotal = (order['originalTotal'] as num?)?.toDouble();
    final total =
        ((order['total'] ?? order['totalAmount'] ?? order['grandTotal'] ?? 0)
                as num)
            .toDouble();
    final payMethod = (order['paymentMethod'] ?? 'N/A') as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (ctx, sc) => Container(
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Top bar with download button ──────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: t.cardBdr)),
                ),
                child: Column(children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                          color: t.cardBdr,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(children: [
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: t.cardBdr)),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: t.textDim),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Invoice',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: t.textHi)),
                        Text('#$displayId',
                            style: TextStyle(
                                fontSize: 11,
                                color: t.textDim,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    // Download PDF button
                    GestureDetector(
                      onTap: () => _downloadBill(ctx, order),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_hNavy, _hNMid],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: _hNavy.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_rounded,
                                  color: _hGold, size: 16),
                              SizedBox(width: 6),
                              Text('Download PDF',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                ]),
              ),

              // ── Invoice body ──────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  controller: sc,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Brand header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_hNavy, _hNMid],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: _hGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(
                              Icons.local_laundry_service_rounded,
                              color: _hGold,
                              size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('LAUNDRIFY',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _hGold,
                                    letterSpacing: 2)),
                            Text('Professional Laundry Service',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white
                                        .withValues(alpha: 0.6))),
                          ]),
                        ),
                        _statusBadge(status),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Order meta
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.cardBdr)),
                      child: Column(children: [
                        _invoiceMetaRow(t, 'Order ID', '#$displayId'),
                        _dividerLine(t),
                        _invoiceMetaRow(
                            t,
                            'Date',
                            '${order['orderDate'] ?? ''} ${order['orderTime'] ?? ''}'),
                        _dividerLine(t),
                        _invoiceMetaRow(
                            t, 'Payment', payMethod.toUpperCase()),
                        _dividerLine(t),
                        _invoiceMetaRow(
                            t,
                            'Pickup',
                            '${order['pickupDate'] ?? ''} ${order['pickupTime'] ?? ''}'),
                        if ((order['deliveryDate'] ?? '').isNotEmpty) ...[
                          _dividerLine(t),
                          _invoiceMetaRow(
                              t,
                              'Delivery',
                              '${order['deliveryDate']} ${order['deliveryTime'] ?? ''}'),
                        ],
                        if ((order['address'] ?? '').isNotEmpty) ...[
                          _dividerLine(t),
                          _invoiceMetaRow(
                              t, 'Address', order['address'] as String),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Services & items
                    ...services.map((svc) {
                      final sName =
                          (svc['serviceName'] ?? svc['title'] ?? '') as String;
                      final items = (svc['items'] as List? ?? [])
                          .where((i) => ((i as Map)['qty'] ?? 0) > 0)
                          .toList();
                      if (items.isEmpty) return const SizedBox.shrink();
                      final accent = _hAccent(sName);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: t.cardBdr)),
                        child: Column(children: [
                          // Service header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.08),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14))),
                            child: Row(children: [
                              Icon(_hIcon(sName), color: accent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(sName,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: t.textHi))),
                              Text(
                                  '₹${items.fold<double>(0, (s, i) => s + ((i as Map)['qty'] as int) * ((i)['price'] as num)).toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: accent)),
                            ]),
                          ),
                          // Item rows
                          ...items.asMap().entries.map((e) {
                            final i = e.key;
                            final item = e.value as Map;
                            final qty = item['qty'] as int;
                            final price = (item['price'] as num).toInt();
                            return Column(children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(
                                          item['name']?.toString() ?? '',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: t.textHi,
                                              fontWeight:
                                                  FontWeight.w600))),
                                  Text('$qty ×',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: t.textDim)),
                                  const SizedBox(width: 4),
                                  Text('₹$price',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: t.textDim)),
                                  const SizedBox(width: 8),
                                  Text(
                                      '₹${(qty * price).toStringAsFixed(0)}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: t.textHi)),
                                ]),
                              ),
                              if (i < items.length - 1)
                                Divider(
                                    height: 1,
                                    indent: 14,
                                    endIndent: 14,
                                    color: t.cardBdr),
                            ]);
                          }),
                        ]),
                      );
                    }),

                    // Bill breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.cardBdr)),
                      child: Column(children: [
                        _billLine(t, 'Subtotal',
                            '₹${subtotal.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _billLine(t, 'Delivery Fee',
                            '₹${delivery.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _billLine(t, 'GST (5%)',
                            '₹${gst.toStringAsFixed(0)}'),
                        if (couponDiscount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  const Icon(Icons.local_offer_rounded,
                                      size: 13, color: _hGreen),
                                  const SizedBox(width: 4),
                                  Text(
                                      'Coupon Discount${couponCode != null ? ' ($couponCode)' : ''}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: _hGreen,
                                          fontWeight: FontWeight.w600)),
                                ]),
                                Text(
                                    '−₹${couponDiscount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _hGreen)),
                              ]),
                        ],
                        Divider(height: 20, color: t.cardBdr),
                        Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                          Text('Total Paid',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: t.textHi)),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                            if (couponDiscount > 0 &&
                                originalTotal != null) ...[
                              Text(
                                  '₹${originalTotal.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: t.textDim,
                                      decoration:
                                          TextDecoration.lineThrough)),
                            ],
                            Text('₹${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: _hGold)),
                          ]),
                        ]),
                        if (couponDiscount > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: _hGreen.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _hGreen.withValues(alpha: 0.2))),
                            child: Row(children: [
                              const Icon(Icons.savings_rounded,
                                  color: _hGreen, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                  'You saved ₹${couponDiscount.toStringAsFixed(0)} on this order!',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _hGreen)),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 30),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invoiceMetaRow(dynamic t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: (t as dynamic).textDim,
                    fontWeight: FontWeight.w600))),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    color: (t as dynamic).textHi,
                    fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _dividerLine(dynamic t) =>
      Divider(height: 1, color: (t as dynamic).cardBdr);

  Widget _billLine(dynamic t, String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: (t as dynamic).textMid)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: (t as dynamic).textHi)),
        ],
      );

  // ── PDF download ────────────────────────────────────────────
  Future<void> _downloadBill(
      BuildContext context, Map<String, dynamic> order) async {
    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        SizedBox(
            width: 18,
            height: 18,
            child:
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        SizedBox(width: 12),
        Text("Generating PDF bill..."),
      ]),
      backgroundColor: _hNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));

    final doc = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();
    final xb = await PdfGoogleFonts.nunitoExtraBold();

    final services = (order['services'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Compute subtotal from cart items directly — covers Cash on Delivery where
    // payment fields may be 0 or missing
    double computedSubtotal = 0;
    for (final svc in services) {
      final items = (svc['items'] as List?) ?? [];
      for (final item in items) {
        final m = item as Map;
        computedSubtotal += ((m['qty'] as int? ?? 0) * (m['price'] as num? ?? 0));
      }
    }

    // Use stored values if they are non-zero, else fall back to computed
    final storedSubtotal = (order['subtotal'] as num? ?? 0).toDouble();
    final subtotal = storedSubtotal > 0 ? storedSubtotal : computedSubtotal;
    final delivery = (order['deliveryFee'] as num? ?? 0).toDouble();
    final gst = (order['gst'] as num? ?? 0).toDouble();
    final couponDiscount = (order['couponDiscount'] as num? ?? 0).toDouble();
    final couponCode = order['couponCode'] as String?;
    final storedTotal = (order['total'] ?? order['totalAmount'] ?? order['grandTotal'] ?? 0 as num).toDouble();
    final total = storedTotal > 0 ? storedTotal : (subtotal + delivery + gst - couponDiscount).clamp(0, double.infinity);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        // ── HEADER ─────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(28),
          decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#080F1E'),
              borderRadius: pw.BorderRadius.circular(14)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Invoice title prominently at top
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F5C518'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text("INVOICE",
                    style: pw.TextStyle(
                      font: xb, fontSize: 18,
                      color: PdfColor.fromHex('#080F1E'),
                      letterSpacing: 4,
                    )),
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("LAUNDRIFY",
                          style: pw.TextStyle(
                              font: xb,
                              fontSize: 22,
                              color: PdfColor.fromHex('#F5C518'),
                              letterSpacing: 3)),
                      pw.SizedBox(height: 3),
                      pw.Text("Professional Laundry Service",
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              color: PdfColors.white)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Order #${order['orderId'] ?? order['id'] ?? 'N/A'}",
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 12,
                              color: PdfColors.white)),
                      pw.SizedBox(height: 4),
                      pw.Text(order['orderDate'] ?? '',
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              color: PdfColors.grey300)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColor.fromHex('#F5C518'), thickness: 0.8),
              pw.SizedBox(height: 14),
              pw.Row(children: [
                pw.Expanded(
                    child: _pdfLabelValue(
                        "Date", order['orderDate'] ?? '', font, bold)),
                pw.Expanded(
                    child: _pdfLabelValue(
                        "Time", order['orderTime'] ?? '', font, bold)),
                pw.Expanded(
                    child: _pdfLabelValue("Payment",
                        order['paymentMethod'] ?? 'N/A', font, bold)),
              ]),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // ── SCHEDULE ─────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              border:
                  pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
              borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Row(children: [
            pw.Expanded(
                child: _pdfScheduleCol(
                    "PICKUP",
                    '#1B4FD8',
                    order['pickupDate'] ?? '',
                    order['pickupTime'] ?? '',
                    font,
                    bold)),
            pw.Container(
                width: 0.8, height: 48, color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(width: 16),
            pw.Expanded(
                child: _pdfScheduleCol(
                    "DELIVERY",
                    '#10B981',
                    order['deliveryDate'] ?? '',
                    order['deliveryTime'] ?? '',
                    font,
                    bold)),
            pw.Container(
                width: 0.8, height: 48, color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(width: 16),
            pw.Expanded(
                child: _pdfScheduleCol(
                    "ADDRESS",
                    '#D97706',
                    order['addressLabel'] ?? '',
                    order['address'] ?? '',
                    font,
                    bold)),
          ]),
        ),

        pw.SizedBox(height: 20),

        // ── ITEMS BY SERVICE ──────────────────────────────────
        ...services.map((svc) {
          final sName = (svc['serviceName'] as String?) ?? '';
          final items = (svc['items'] as List?) ?? [];
          final sTotal = items.fold<double>(0.0,
              (s, i) => s + ((i as Map)['qty'] as int) * ((i)['price'] as num));

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Service header band
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F0F4FF'),
                    borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(sName.toUpperCase(),
                        style: pw.TextStyle(
                            font: xb,
                            fontSize: 11,
                            color: PdfColor.fromHex('#080F1E'))),
                    pw.Text("₹${sTotal.toStringAsFixed(2)}",
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 11,
                            color: PdfColor.fromHex('#080F1E'))),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // Column headers
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: pw.Row(children: [
                  pw.Expanded(
                      flex: 4,
                      child: pw.Text("ITEM",
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 9,
                              color: PdfColors.grey600))),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                      width: 36,
                      child: pw.Text("QTY",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 9,
                              color: PdfColors.grey600))),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                      width: 58,
                      child: pw.Text("RATE",
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 9,
                              color: PdfColors.grey600))),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                      width: 68,
                      child: pw.Text("AMOUNT",
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 9,
                              color: PdfColors.grey600))),
                ]),
              ),
              pw.Divider(
                  color: PdfColors.grey300,
                  thickness: 0.5,
                  indent: 14,
                  endIndent: 14),

              // Item rows
              ...items.map((item) {
                final m = item as Map;
                final qty = (m['qty'] as int? ?? 0);
                final price = (m['price'] as num? ?? 0);
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  child: pw.Row(children: [
                    pw.Expanded(
                        flex: 4,
                        child: pw.Text(m['name']?.toString() ?? '',
                            style: pw.TextStyle(
                                font: font,
                                fontSize: 11,
                                color: PdfColor.fromHex('#0A1628')))),
                    pw.SizedBox(width: 8),
                    pw.SizedBox(
                        width: 36,
                        child: pw.Text("$qty",
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                font: bold,
                                fontSize: 11,
                                color: PdfColor.fromHex('#1B4FD8')))),
                    pw.SizedBox(width: 8),
                    pw.SizedBox(
                        width: 58,
                        child: pw.Text("₹$price",
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                font: font,
                                fontSize: 11,
                                color: PdfColors.grey700))),
                    pw.SizedBox(width: 8),
                    pw.SizedBox(
                        width: 68,
                        child: pw.Text("₹${(qty * price).toStringAsFixed(2)}",
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                font: bold,
                                fontSize: 11,
                                color: PdfColor.fromHex('#0A1628')))),
                  ]),
                );
              }),

              pw.SizedBox(height: 12),
            ],
          );
        }),

        // ── BILL BREAKDOWN ────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              border:
                  pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
              borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Column(children: [
            _pdfBillRow(
                "Subtotal", "₹${subtotal.toStringAsFixed(2)}", font, bold),
            pw.SizedBox(height: 8),
            _pdfBillRow(
                "Delivery Fee", "₹${delivery.toStringAsFixed(2)}", font, bold),
            pw.SizedBox(height: 8),
            _pdfBillRow("GST (5%)", "₹${gst.toStringAsFixed(2)}", font, bold),
            if (couponDiscount > 0) ...[
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Coupon Discount${couponCode != null ? ' ($couponCode)' : ''}",
                    style: pw.TextStyle(
                        font: font, fontSize: 11, color: PdfColor.fromHex('#10B981')),
                  ),
                  pw.Text(
                    "−₹${couponDiscount.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                        font: bold, fontSize: 11, color: PdfColor.fromHex('#10B981')),
                  ),
                ],
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("GRAND TOTAL",
                    style: pw.TextStyle(
                        font: xb,
                        fontSize: 14,
                        color: PdfColor.fromHex('#0A1628'))),
                pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#080F1E'),
                        borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Text("₹${total.toStringAsFixed(2)}",
                        style: pw.TextStyle(
                            font: xb, fontSize: 14, color: PdfColors.white))),
              ],
            ),
          ]),
        ),

        pw.SizedBox(height: 20),

        // ── FOOTER ───────────────────────────────────────────
        pw.Center(
          child: pw.Column(children: [
            if (couponDiscount > 0) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                margin: const pw.EdgeInsets.only(bottom: 14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F0FDF4'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#10B981'), width: 0.5),
                ),
                child: pw.Text(
                  "🎉 You saved ₹${couponDiscount.toStringAsFixed(0)} with coupon${couponCode != null ? ' $couponCode' : ''}!",
                  style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColor.fromHex('#059669')),
                ),
              ),
            ],
            pw.Divider(color: PdfColors.grey200, thickness: 0.5),
            pw.SizedBox(height: 10),
            pw.Text("Thank you for choosing Laundrify!",
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 12,
                    color: PdfColor.fromHex('#080F1E'))),
            pw.SizedBox(height: 4),
            pw.Text(
                "This is a computer-generated invoice and does not require a signature.",
                style: pw.TextStyle(
                    font: font, fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(
                "support@laundrify.in  |  www.laundrify.in  |  +91 98765 43210",
                style: pw.TextStyle(
                    font: font, fontSize: 9, color: PdfColors.grey600)),
          ]),
        ),
      ],
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Laundrify_Bill_${order['orderId'] ?? 'unknown'}.pdf',
    );
  }

  // ── PDF helper widgets ─────────────────────────────────────
  pw.Widget _pdfLabelValue(
      String label, String value, pw.Font font, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style:
                pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
        pw.SizedBox(height: 3),
        pw.Text(value,
            style:
                pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.white)),
      ],
    );
  }

  pw.Widget _pdfScheduleCol(String label, String hexColor, String line1,
      String line2, pw.Font font, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: bold, fontSize: 9, color: PdfColor.fromHex(hexColor))),
        pw.SizedBox(height: 4),
        pw.Text(line1,
            style: pw.TextStyle(
                font: bold, fontSize: 11, color: PdfColor.fromHex('#0A1628'))),
        pw.Text(line2,
            style:
                pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey)),
      ],
    );
  }

  pw.Widget _pdfBillRow(
      String label, String value, pw.Font font, pw.Font bold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: font, fontSize: 11, color: PdfColors.grey700)),
        pw.Text(value,
            style: pw.TextStyle(
                font: bold, fontSize: 11, color: PdfColor.fromHex('#0A1628'))),
      ],
    );
  }
}
