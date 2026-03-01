import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/firestore_service.dart';
import '../widgets/windows_layout.dart';
import 'track_order_page.dart';
import 'feedback_page.dart';
import 'cancel_order_page.dart';

// ═══════════════════════════════════════════════════════════
// MY ORDERS PAGE — Real Firestore data, filter, PDF invoice
// ═══════════════════════════════════════════════════════════

const _navy = Color(0xFF080F1E);
const _navyCard = Color(0xFF111827);
const _navyBorder = Color(0xFF1C2537);
const _blue = Color(0xFF1B4FD8);
const _blueSoft = Color(0xFF3B82F6);
const _gold = Color(0xFFF5C518);
const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _rose = Color(0xFFEF4444);
const _violet = Color(0xFF8B5CF6);
const _cyan = Color(0xFF06B6D4);

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _firestore = FirestoreService();
  String _selectedFilter = 'all';
  final _filters = ['all', 'active', 'completed', 'cancelled'];

  bool _matchesFilter(String status) {
    switch (_selectedFilter) {
      case 'all': return true;
      case 'active': return ['confirmed', 'pickup', 'processing', 'ready', 'out_for_delivery'].contains(status);
      case 'completed': return status == 'delivered';
      case 'cancelled': return status == 'cancelled';
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        Text('Your laundry history', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // FILTER TOGGLE (like signup page)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _navyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _navyBorder),
              ),
              child: Row(
                children: _filters.map((f) => _toggleFilterBtn(f)).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ORDERS LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.getUserOrdersStream(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return _buildShimmer();
                  }
                  if (snap.hasError) {
                    return _buildEmpty('Error loading orders', Icons.error_outline_rounded, _rose);
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return _buildEmpty('No orders yet', Icons.shopping_bag_outlined, _blueSoft);
                  }

                  final filtered = snap.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _matchesFilter(data['status'] ?? 'confirmed');
                  }).toList();

                  if (filtered.isEmpty) {
                    return _buildEmpty('No $_selectedFilter orders', Icons.inbox_outlined, _blueSoft);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final data = filtered[i].data() as Map<String, dynamic>;
                      return _OrderCard(
                        doc: filtered[i],
                        onTrack: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackOrderPage(orderId: filtered[i].id))),
                        onDownloadInvoice: () => _generateInvoice(filtered[i].id, data),
                        onFeedback: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackPage(
                          orderId: filtered[i].id,
                          orderSummary: (data['services'] as List?)?.isNotEmpty == true
                              ? ((data['services'] as List).first['serviceName'] ?? '')
                              : '',
                        ))),
                        onCancel: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CancelOrderPage(
                          orderId: filtered[i].id,
                          orderData: data,
                        ))),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    return WindowsLayout(
      title: 'My Orders',
      currentRoute: '/orders',
      child: scaffold,
    );
  }

  Future<void> _generateInvoice(String orderId, Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final services = (data['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('LAUNDRIFY', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text('Premium Laundry Service', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('INVOICE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('#${orderId.substring(0, 8).toUpperCase()}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            ]),
          ]),

          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // Customer & Order Info
          pw.Row(children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('BILL TO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, fontSize: 10)),
              pw.SizedBox(height: 6),
              pw.Text(data['customerName'] ?? 'Customer', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(data['customerEmail'] ?? '', style: const pw.TextStyle(fontSize: 12)),
              pw.Text(data['address'] ?? '', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ])),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              _invoiceRow(pdf, 'Order Date', data['orderDate'] ?? 'N/A'),
              _invoiceRow(pdf, 'Pickup', '${data['pickupDate'] ?? 'N/A'} ${data['pickupTime'] ?? ''}'),
              _invoiceRow(pdf, 'Delivery', '${data['deliveryDate'] ?? 'N/A'} ${data['deliveryTime'] ?? ''}'),
              _invoiceRow(pdf, 'Payment', data['paymentMethod'] ?? 'Online'),
            ])),
          ]),

          pw.SizedBox(height: 24),

          // Services table header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: PdfColors.blue800,
            child: pw.Row(children: [
              pw.Expanded(flex: 3, child: pw.Text('SERVICE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11))),
              pw.Expanded(child: pw.Text('QTY', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.center)),
              pw.Expanded(child: pw.Text('PRICE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right)),
            ]),
          ),

          // Services rows
          ...services.map((s) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
            child: pw.Row(children: [
              pw.Expanded(flex: 3, child: pw.Text(s['serviceName'] ?? s['name'] ?? '', style: const pw.TextStyle(fontSize: 12))),
              pw.Expanded(child: pw.Text('${s['qty'] ?? 1}', style: const pw.TextStyle(fontSize: 12), textAlign: pw.TextAlign.center)),
              pw.Expanded(child: pw.Text('₹${(s['price'] ?? 0).toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 12), textAlign: pw.TextAlign.right)),
            ]),
          )),

          pw.SizedBox(height: 16),

          // Totals
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 200,
              child: pw.Column(children: [
                _totRow(pdf, 'Subtotal', '₹${(data['subtotal'] ?? 0).toStringAsFixed(2)}'),
                _totRow(pdf, 'Delivery Fee', '₹${(data['deliveryFee'] ?? 0).toStringAsFixed(2)}'),
                _totRow(pdf, 'GST (18%)', '₹${(data['gst'] ?? 0).toStringAsFixed(2)}'),
                pw.Divider(),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('₹${(data['total'] ?? data['totalAmount'] ?? 0).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue800)),
                ]),
              ]),
            ),
          ),

          pw.SizedBox(height: 30),
          pw.Center(child: pw.Text('Thank you for choosing Laundrify! 🧺', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600))),
        ],
      ),
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  pw.Widget _invoiceRow(pw.Document _, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('$label: ', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  pw.Widget _totRow(pw.Document _, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
      ]),
    );
  }

  Widget _toggleFilterBtn(String filter) {
    final active = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [_blue, _blueSoft])
                : null,
            color: active ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [BoxShadow(color: _blue.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            filter.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon, Color color) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color.withValues(alpha: 0.5), size: 64),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
      const SizedBox(height: 8),
      const Text('Your orders will appear here', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
    ]));
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 4,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 130,
        decoration: BoxDecoration(color: _navyCard, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ─── ORDER CARD ──────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback onTrack;
  final VoidCallback onDownloadInvoice;
  final VoidCallback onFeedback;
  final VoidCallback onCancel;

  const _OrderCard({required this.doc, required this.onTrack, required this.onDownloadInvoice, required this.onFeedback, required this.onCancel});

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered': return _green;
      case 'cancelled': return _rose;
      case 'processing': return _violet;
      case 'out_for_delivery': return _gold;
      case 'ready': return _cyan;
      case 'pickup': return _amber;
      default: return _blueSoft;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmed': return 'Confirmed';
      case 'pickup': return 'Pickup Scheduled';
      case 'processing': return 'Being Washed';
      case 'ready': return 'Ready for Delivery';
      case 'out_for_delivery': return 'Out for Delivery';
      case 'delivered': return 'Delivered ✓';
      case 'cancelled': return 'Cancelled';
      default: return s.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] ?? 'confirmed';
    final color = _statusColor(status);
    final isActive = ['confirmed', 'pickup', 'processing', 'ready', 'out_for_delivery'].contains(status);
    final ts = (d['createdAt'] as Timestamp?)?.toDate();
    final services = (d['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (d['total'] ?? d['totalAmount'] ?? 0).toDouble();

    return GestureDetector(
      onTap: onTrack,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _navyCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color.withValues(alpha: 0.3) : _navyBorder, width: isActive ? 1.5 : 1),
          boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 16, spreadRadius: 0)] : null,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(_statusIcon(status), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              services.isNotEmpty ? services.map((s) => s['serviceName'] ?? s['name'] ?? '').join(', ') : 'Laundry Service',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '#${doc.id.substring(0, 8).toUpperCase()}  •  ${ts != null ? '${ts.day}/${ts.month}/${ts.year}' : 'N/A'}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
                            child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 13, color: const Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(d['address'] ?? 'N/A', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),

            Container(height: 1, color: _navyBorder),
            // Primary action row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  if (isActive) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: onTrack,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_blue, _blueSoft]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.location_on_rounded, color: Colors.white, size: 15),
                            SizedBox(width: 6),
                            Text('Track Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (status == 'delivered')
                    Expanded(
                      child: GestureDetector(
                        onTap: onDownloadInvoice,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _green.withValues(alpha: 0.3))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.receipt_long_rounded, color: _green, size: 15),
                            SizedBox(width: 6),
                            Text('Download Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _green)),
                          ]),
                        ),
                      ),
                    )
                  else if (!isActive)
                    Expanded(
                      child: GestureDetector(
                        onTap: onTrack,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 15),
                            SizedBox(width: 6),
                            Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Secondary action row — Feedback & Cancel
            if (status != 'cancelled')
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    // Feedback button — always visible except for cancelled orders
                    Expanded(
                      child: GestureDetector(
                        onTap: onFeedback,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _violet.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _violet.withValues(alpha: 0.25)),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.feedback_rounded, color: _violet, size: 14),
                            SizedBox(width: 5),
                            Text('Feedback', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _violet)),
                          ]),
                        ),
                      ),
                    ),
                    // Cancel button — only for active (not delivered/cancelled)
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: onCancel,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _rose.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _rose.withValues(alpha: 0.25)),
                            ),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.cancel_outlined, color: _rose, size: 14),
                              SizedBox(width: 5),
                              Text('Cancel Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _rose)),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'delivered': return Icons.check_circle_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      case 'processing': return Icons.local_laundry_service_rounded;
      case 'out_for_delivery': return Icons.delivery_dining_rounded;
      case 'ready': return Icons.done_all_rounded;
      case 'pickup': return Icons.local_shipping_outlined;
      default: return Icons.receipt_long_rounded;
    }
  }
}
