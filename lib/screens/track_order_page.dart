import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrackOrderPage extends StatefulWidget {
  final String orderId;
  const TrackOrderPage({super.key, required this.orderId});

  @override
  State<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends State<TrackOrderPage> {
  static const _navy = Color(0xFF080F1E);
  static const _gold = Color(0xFFF5C518);
  static const _bg = Color(0xFFF0F4FF);
  static const _card = Colors.white;

  final _db = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _stages = [
    {
      'label': 'Order Placed',
      'icon': Icons.receipt_long_rounded,
      'status': 'pending'
    },
    {
      'label': 'Pickup Scheduled',
      'icon': Icons.calendar_today_rounded,
      'status': 'assigned'
    },
    {
      'label': 'Picked Up',
      'icon': Icons.local_shipping_outlined,
      'status': 'pickup'
    },
    {
      'label': 'Processing',
      'icon': Icons.local_laundry_service_outlined,
      'status': 'processing'
    },
    {
      'label': 'Out for Delivery',
      'icon': Icons.delivery_dining_rounded,
      'status': 'delivery'
    },
    {
      'label': 'Delivered',
      'icon': Icons.check_circle_outline_rounded,
      'status': 'completed'
    },
  ];

  int _getStageIndex(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'assigned':
      case 'accepted':
        return 1;
      case 'pickup':
        return 2;
      case 'processing':
        return 3;
      case 'delivery':
      case 'out_for_delivery':
        return 4;
      case 'completed':
      case 'delivered':
        return 5;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Track Order',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: widget.orderId.isEmpty
          ? const Center(
              child: Text(
                'No order to track',
                style: TextStyle(color: Color(0xFF475569), fontSize: 15),
              ),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('orders').doc(widget.orderId).snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _gold,
                      strokeWidth: 2,
                    ),
                  );
                }
                if (!snap.data!.exists) {
                  return const Center(child: Text('Order not found'));
                }

                final order = snap.data!.data() as Map<String, dynamic>;
                final status = order['status'] ?? 'pending';
                final currentStage = _getStageIndex(status);
                final isCancelled = status == 'cancelled';

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ORDER ID CARD
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: _gold,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Order ID',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  Text(
                                    '#${widget.orderId.substring(0, 8).toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: _navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _StatusBadge(status: status),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // TRACKING TIMELINE
                      if (!isCancelled) ...[
                        const Text(
                          'Order Timeline',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Column(
                            children: _stages.asMap().entries.map((entry) {
                              final i = entry.key;
                              final stage = entry.value;
                              final isDone = i <= currentStage;
                              final isCurrent = i == currentStage;
                              final isLast = i == _stages.length - 1;

                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Column(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isDone
                                                  ? (isCurrent
                                                      ? _gold
                                                      : const Color(0xFF10B981))
                                                  : const Color(0xFFE8EDF5),
                                              boxShadow: isCurrent
                                                  ? [
                                                      BoxShadow(
                                                        color: _gold.withValues(
                                                            alpha: 0.4),
                                                        blurRadius: 10,
                                                        offset:
                                                            const Offset(0, 2),
                                                      )
                                                    ]
                                                  : null,
                                            ),
                                            child: Icon(
                                              isDone && !isCurrent
                                                  ? Icons.check_rounded
                                                  : stage['icon'] as IconData,
                                              color: isDone
                                                  ? Colors.white
                                                  : const Color(0xFF94A3B8),
                                              size: 20,
                                            ),
                                          ),
                                          if (!isLast)
                                            Container(
                                              width: 2,
                                              height: 32,
                                              color: i < currentStage
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFE8EDF5),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom: isLast ? 0 : 16,
                                          ),
                                          child: Text(
                                            stage['label'] as String,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isCurrent
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: isDone
                                                  ? _navy
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.cancel_outlined,
                                  color: Color(0xFFEF4444), size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This order has been cancelled.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (order['cancelReason'] != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Reason: ${order['cancelReason']}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // DELIVERY AGENT CARD (shown when assigned)
                      if (order['driverName'] != null) ...[ 
                        const SizedBox(height: 24),
                        const Text(
                          'Delivery Agent',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _gold.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: _gold.withValues(alpha: 0.15),
                                child: Text(
                                  ((order['driverName'] as String?) ?? 'D').isNotEmpty
                                      ? (order['driverName'] as String)[0].toUpperCase()
                                      : 'D',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: _navy,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order['driverName'] ?? 'Delivery Agent',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _navy,
                                      ),
                                    ),
                                    if (order['driverPhone'] != null)
                                      Text(
                                        order['driverPhone'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (order['driverPhone'] != null)
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: order['driverPhone']));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Phone number copied'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Color(0xFF0A1628),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.phone_rounded, color: _navy, size: 20),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      // ORDER DETAILS
                      const SizedBox(height: 24),
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            _infoRow('Total Amount',
                                '₹${(order['totalAmount'] ?? 0).toStringAsFixed(0)}'),
                            _infoRow(
                                'Payment',
                                order['paymentMethod'] == 'cod'
                                    ? 'Cash on Delivery'
                                    : 'Online'),
                            if (order['pickupDate'] != null)
                              _infoRow(
                                'Pickup Date',
                                _safeFormatPickupDate(order['pickupDate']),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A1628))),
          ],
        ),
      );

  /// Safely format pickupDate — handles both String (dd/mm/yyyy) and Timestamp
  String _safeFormatPickupDate(dynamic val) {
    if (val == null) return '';
    if (val is String) return val;                     // already formatted string
    if (val is Timestamp) {
      final dt = val.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return val.toString();
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = const Color(0xFFF59E0B);
        break;
      case 'pickup':
        color = const Color(0xFF3B82F6);
        break;
      case 'processing':
        color = const Color(0xFF8B5CF6);
        break;
      case 'delivery':
        color = const Color(0xFFF59E0B);
        break;
      case 'completed':
        color = const Color(0xFF10B981);
        break;
      case 'cancelled':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = const Color(0xFF94A3B8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
