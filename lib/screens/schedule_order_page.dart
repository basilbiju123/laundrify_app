import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'payment_page.dart';
import '../services/firestore_service.dart';

const _navy = Color(0xFF080F1E);
const _navyMid = Color(0xFF0D1F3C);
const _blue = Color(0xFF1B4FD8);
const _gold = Color(0xFFF5C518);
const _goldSoft = Color(0xFFFDE68A);
const _green = Color(0xFF10B981);
const _surface = Color(0xFFF0F4FF);
const _tDark = Color(0xFF0A1628);
const _tMid = Color(0xFF475569);
const _tFade = Color(0xFF94A3B8);

Color _accentFor(String n) {
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
      return _blue;
  }
}

IconData _iconFor(String n) {
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

class ScheduleOrderPage extends StatefulWidget {
  final double totalAmount;
  final int totalItems;
  final List<Map<String, dynamic>> services;

  const ScheduleOrderPage({
    super.key,
    required this.totalAmount,
    required this.totalItems,
    required this.services,
  });

  @override
  State<ScheduleOrderPage> createState() => _ScheduleOrderPageState();
}

class _ScheduleOrderPageState extends State<ScheduleOrderPage> {
  DateTime? selectedPickupDate;
  String? selectedPickupTime;
  DateTime? selectedDeliveryDate;
  String? selectedDeliveryTime;
  String selectedAddress = "Home";

  final List<String> timeSlots = [
    "8:00 AM - 10:00 AM",
    "10:00 AM - 12:00 PM",
    "12:00 PM - 2:00 PM",
    "2:00 PM - 4:00 PM",
    "4:00 PM - 6:00 PM",
    "6:00 PM - 8:00 PM",
  ];

  final List<Map<String, dynamic>> addresses = [
    {
      'label': 'Home',
      'address': '123 Main Street, Apartment 4B',
      'icon': Icons.home_rounded
    },
    {
      'label': 'Office',
      'address': '456 Business Park, Floor 2',
      'icon': Icons.business_rounded
    },
    {
      'label': 'Other',
      'address': 'Add new address',
      'icon': Icons.add_location_rounded
    },
  ];

  // ── Pricing ────────────────────────────────────────────────
  double get subtotal => widget.services.fold(0.0, (s, svc) {
        return s +
            (svc['items'] as List).fold(
                0.0, (ss, i) => ss + (i['qty'] as int) * (i['price'] as num));
      });
  double get deliveryFee => 40.0;
  double get gst => subtotal * 0.18;
  double get total => subtotal + deliveryFee + gst;

  bool get isFormValid =>
      selectedPickupDate != null &&
      selectedPickupTime != null &&
      selectedDeliveryDate != null &&
      selectedDeliveryTime != null &&
      _timeConflictWarning == null;

  String? _timeConflictWarning;

  void _validateTimes() {
    if (selectedPickupDate == null || selectedDeliveryDate == null ||
        selectedPickupTime == null || selectedDeliveryTime == null) {
      setState(() => _timeConflictWarning = null);
      return;
    }
    final sameDay = selectedPickupDate!.year == selectedDeliveryDate!.year &&
        selectedPickupDate!.month == selectedDeliveryDate!.month &&
        selectedPickupDate!.day == selectedDeliveryDate!.day;
    final deliveryBefore = selectedDeliveryDate!.isBefore(selectedPickupDate!);
    if (deliveryBefore) {
      setState(() => _timeConflictWarning = '⚠️ Delivery date cannot be before pickup date');
    } else if (sameDay) {
      final ph = _parseHour(selectedPickupTime!);
      final dh = _parseHour(selectedDeliveryTime!);
      if (dh <= ph) {
        setState(() => _timeConflictWarning = '⚠️ Delivery time must be after pickup time on the same day');
      } else {
        setState(() => _timeConflictWarning = null);
      }
    } else {
      setState(() => _timeConflictWarning = null);
    }
  }

  int _parseHour(String slot) {
    final part = slot.split(' - ')[0].trim();
    final hm = part.split(':');
    int hour = int.tryParse(hm[0]) ?? 0;
    if (part.contains('PM') && hour != 12) hour += 12;
    if (part.contains('AM') && hour == 12) hour = 0;
    return hour;
  }

  // ── Helpers ────────────────────────────────────────────────
  String _fmt(DateTime? d) {
    if (d == null) return '';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  String _fmtFull(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _now() {
    final d = DateTime.now();
    final h = d.hour > 12
        ? d.hour - 12
        : d.hour == 0
            ? 12
            : d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:$m $ampm';
  }

  String _orderId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'LDY-${ts.substring(ts.length - 8).toUpperCase()}';
  }

  Future<void> _savePendingOrder(String orderId, String orderDate, String orderTime, Map addr) async {
    try {
      final firestore = FirestoreService();
      await firestore.saveOrder({
        'orderId': orderId,
        'orderDate': orderDate,
        'orderTime': orderTime,
        'paymentMethod': 'Pending',
        'paymentId': '',
        'services': widget.services,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'gst': gst,
        'total': total,
        'pickupDate': _fmt(selectedPickupDate!),
        'pickupTime': selectedPickupTime!,
        'deliveryDate': _fmt(selectedDeliveryDate!),
        'deliveryTime': selectedDeliveryTime!,
        'address': addr['address'] as String,
        'addressLabel': selectedAddress,
        'status': 'pending_payment', // incomplete — show "Complete Payment" in history
      });
    } catch (_) {}
  }

  Future<void> _selectDate(bool isPickup) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1B4FD8),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      // Validate: delivery must be after pickup
      if (!isPickup && selectedPickupDate != null) {
        if (picked.isBefore(selectedPickupDate!) || picked.isAtSameMomentAs(selectedPickupDate!)) {
          if (!mounted) return;
          _showDateWarning('Delivery date must be after your pickup date.');
          return;
        }
      }
      setState(() {
        if (isPickup) {
          selectedPickupDate = picked;
          // If delivery is now before pickup, reset delivery
          if (selectedDeliveryDate != null && 
              !selectedDeliveryDate!.isAfter(picked)) {
            selectedDeliveryDate = null;
            selectedDeliveryTime = null;
            _showDateWarning('Delivery date was reset — please pick a date after pickup.');
          }
        } else {
          selectedDeliveryDate = picked;
        }
      });
    }
  }

  void _showDateWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: const Color(0xFFD97706),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Show bill summary then navigate to payment ─────────────────
  void _confirmOrder() {
    // Validate time slots don't conflict (same day: pickup time should be before delivery time)
    if (selectedPickupDate != null && selectedDeliveryDate != null &&
        selectedPickupDate!.isAtSameMomentAs(selectedDeliveryDate!) &&
        selectedPickupTime != null && selectedDeliveryTime != null) {
      final pickupHour = _parseHour(selectedPickupTime!);
      final deliveryHour = _parseHour(selectedDeliveryTime!);
      if (deliveryHour <= pickupHour) {
        _showDateWarning('Delivery time must be after pickup time on same day.');
        return;
      }
    }
    final orderId = _orderId();
    final orderDate = _fmtFull(DateTime.now());
    final orderTime = _now();
    final addr = addresses.firstWhere((a) => a['label'] == selectedAddress);

    // Save as pending (incomplete) order so it shows in history as "Complete Payment"
    _savePendingOrder(orderId, orderDate, orderTime, addr);

    // Show bill summary sheet first
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BillSummarySheet(
        orderId: orderId,
        orderDate: orderDate,
        orderTime: orderTime,
        services: widget.services,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        gst: gst,
        total: total,
        pickupDate: _fmt(selectedPickupDate!),
        pickupTime: selectedPickupTime!,
        deliveryDate: _fmt(selectedDeliveryDate!),
        deliveryTime: selectedDeliveryTime!,
        address: addr['address'] as String,
        addressLabel: selectedAddress,
        onProceed: () {
          // Close the sheet
          Navigator.pop(context);
          // Navigate to payment page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentPage(
                orderId: orderId,
                orderDate: orderDate,
                orderTime: orderTime,
                services: widget.services,
                subtotal: subtotal,
                deliveryFee: deliveryFee,
                gst: gst,
                total: total,
                pickupDate: _fmt(selectedPickupDate!),
                pickupTime: selectedPickupTime!,
                deliveryDate: _fmt(selectedDeliveryDate!),
                deliveryTime: selectedDeliveryTime!,
                address: addr['address'] as String,
                addressLabel: selectedAddress,
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_navy, _navyMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight))),
        leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18))),
        title: const Text("Schedule Order",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20)),
      ),
      body: Column(children: [
        Expanded(
            child: SingleChildScrollView(
                child: Column(children: [
          // ── Hero band ──────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_navy, _navyMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32))),
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
                left: 22,
                right: 22,
                bottom: 24),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: _gold, size: 26)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text("Pick Your Schedule",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text("${widget.totalItems} items to pick up",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13)),
                  ])),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [_gold, _goldSoft]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: _gold.withValues(alpha: 0.4), blurRadius: 10)
                      ]),
                  child: Text("₹${total.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 14))),
            ]),
          ),

          const SizedBox(height: 22),

          // ── Pickup Schedule ────────────────────────────────
          _section(
              "Pickup Schedule",
              Icons.upload_rounded,
              Column(children: [
                _datePicker(
                    "Pickup Date", selectedPickupDate, () => _selectDate(true)),
                const SizedBox(height: 14),
                _timeSlots("Pickup Time Slot", selectedPickupTime,
                    (t) { setState(() => selectedPickupTime = t); _validateTimes(); }),
              ])),

          const SizedBox(height: 16),

          // ── Delivery Schedule ──────────────────────────────
          _section(
              "Delivery Schedule",
              Icons.download_rounded,
              Column(children: [
                _datePicker("Delivery Date", selectedDeliveryDate,
                    () => _selectDate(false)),
                const SizedBox(height: 14),
                _timeSlots("Delivery Time Slot", selectedDeliveryTime,
                    (t) { setState(() => selectedDeliveryTime = t); _validateTimes(); }),
              ])),

          const SizedBox(height: 16),

          // ── Address ────────────────────────────────────────
          _section(
            "Delivery Address",
            Icons.location_on_rounded,
            Column(
                children: addresses.map((addr) {
              final sel = selectedAddress == addr['label'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() => selectedAddress = addr['label']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: sel
                            ? _blue.withValues(alpha: 0.07)
                            : const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: sel
                                ? _blue.withValues(alpha: 0.5)
                                : Colors.grey.withValues(alpha: 0.2),
                            width: sel ? 1.8 : 1)),
                    child: Row(children: [
                      Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                              color: sel ? _blue : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(addr['icon'],
                              color: sel ? Colors.white : Colors.grey.shade500,
                              size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(addr['label'],
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: sel ? _blue : _tDark)),
                            const SizedBox(height: 2),
                            Text(addr['address'],
                                style: TextStyle(
                                    fontSize: 12, color: sel ? _tMid : _tFade)),
                          ])),
                      if (sel)
                        Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: _blue, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 12)),
                    ]),
                  ),
                ),
              );
            }).toList()),
          ),

          const SizedBox(height: 120),
        ]))),

        // ── Time conflict warning ──────────────────────────────
        if (_timeConflictWarning != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(_timeConflictWarning!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600))),
            ]),
          ),

        // ── Bottom bar ─────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, -6))
              ]),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${widget.totalItems} items",
                  style: const TextStyle(fontSize: 12, color: _tFade)),
              const SizedBox(height: 2),
              Text("₹${total.toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _tDark)),
            ]),
            const Spacer(),
            GestureDetector(
              onTap: isFormValid ? _confirmOrder : null,
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                      gradient: isFormValid
                          ? const LinearGradient(
                              colors: [_navy, _navyMid],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : null,
                      color: isFormValid ? null : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: isFormValid
                          ? [
                              BoxShadow(
                                  color: _navy.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5))
                            ]
                          : null),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text("CONFIRM ORDER",
                        style: TextStyle(
                            color: isFormValid
                                ? Colors.white
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: isFormValid
                                ? _gold.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7)),
                        child: Icon(Icons.check_rounded,
                            color: isFormValid ? _gold : Colors.grey.shade400,
                            size: 16)),
                  ])),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Section wrapper ────────────────────────────────────────
  Widget _section(String title, IconData icon, Widget content) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ]),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.04),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22))),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_navy, _navyMid]),
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: Colors.white, size: 18)),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _tDark)),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: content),
        ]),
      ),
    );
  }

  // ── Date picker row ────────────────────────────────────────
  Widget _datePicker(String label, DateTime? date, VoidCallback onTap) {
    final sel = date != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color:
                sel ? _blue.withValues(alpha: 0.06) : const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: sel
                    ? _blue.withValues(alpha: 0.45)
                    : Colors.grey.withValues(alpha: 0.2),
                width: sel ? 1.8 : 1)),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: sel ? _blue : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.calendar_today_rounded,
                  color: sel ? Colors.white : Colors.grey.shade400, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: sel ? _blue : _tFade,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(sel ? _fmt(date) : "Tap to select a date",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: sel ? _tDark : _tFade)),
              ])),
          Icon(Icons.chevron_right_rounded,
              color: sel ? _blue : Colors.grey.shade300, size: 20),
        ]),
      ),
    );
  }

  // ── Time slot picker ───────────────────────────────────────
  Widget _timeSlots(String label, String? selected, Function(String) onSel) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: _tFade)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: timeSlots.map((t) {
          final isSel = selected == t;
          return GestureDetector(
            onTap: () => onSel(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: isSel ? _navy : const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isSel ? _navy : Colors.grey.withValues(alpha: 0.2),
                      width: isSel ? 0 : 1),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                              color: _navy.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : null),
              child: Text(t,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : _tMid)),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
//  PROFESSIONAL INVOICE BOTTOM SHEET
// ════════════════════════════════════════════════════════════
class _BillSummarySheet extends StatelessWidget {
  final String orderId, orderDate, orderTime;
  final List<Map<String, dynamic>> services;
  final double subtotal, deliveryFee, gst, total;
  final String pickupDate, pickupTime, deliveryDate, deliveryTime;
  final String address, addressLabel;
  final VoidCallback onProceed;

  const _BillSummarySheet({
    required this.orderId,
    required this.orderDate,
    required this.orderTime,
    required this.services,
    required this.subtotal,
    required this.deliveryFee,
    required this.gst,
    required this.total,
    required this.pickupDate,
    required this.pickupTime,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.address,
    required this.addressLabel,
    required this.onProceed,
  });

  int get _totalItems => services.fold(
      0,
      (s, svc) =>
          s +
          (svc['items'] as List)
              .fold<int>(0, (ss, i) => ss + (i['qty'] as int)));

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(children: [
        // Handle
        Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Summary Header ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_navy, _navyMid],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: _navy.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: _green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.check_circle_rounded,
                                color: _green, size: 22)),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text("Order Summary",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              SizedBox(height: 3),
                              Text("Review before payment",
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ])),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _gold.withValues(alpha: 0.4))),
                            child: Text(orderId,
                                style: const TextStyle(
                                    color: _gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900))),
                      ]),
                    ]),
              ),

              const SizedBox(height: 20),

              // ── Services Summary ──────────────────────────────
              ...services.map((svc) {
                final svcName = svc['serviceName'] as String;
                final items = svc['items'] as List;
                final accent = _accentFor(svcName);
                final icon = _iconFor(svcName);
                final grpTotal = items.fold<double>(
                    0.0, (s, i) => s + (i['qty'] as int) * (i['price'] as num));

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withValues(alpha: 0.07),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ]),
                  child: Column(children: [
                    // Service header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.07),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18))),
                      child: Row(children: [
                        Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(9)),
                            child: Icon(icon, color: accent, size: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(svcName,
                                style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14))),
                        Text("₹${grpTotal.toStringAsFixed(0)}",
                            style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 14)),
                      ]),
                    ),
                    // Items
                    ...items.asMap().entries.map((e) {
                      final isLast = e.key == items.length - 1;
                      final item = e.value;
                      return Column(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Expanded(
                                child: Text(item['name'],
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _tDark))),
                            Text("₹${item['price']} × ${item['qty']}",
                                style: const TextStyle(
                                    fontSize: 12, color: _tFade)),
                            const SizedBox(width: 12),
                            Text(
                                "₹${(item['qty'] as int) * (item['price'] as num)}",
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: _tDark)),
                          ]),
                        ),
                        if (!isLast)
                          Divider(
                              height: 1,
                              indent: 14,
                              endIndent: 14,
                              color: Colors.grey.withValues(alpha: 0.1)),
                      ]);
                    }),
                  ]),
                );
              }),

              const SizedBox(height: 14),

              // ── Schedule Info ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]),
                child: Column(children: [
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: _navy.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.calendar_today_rounded,
                            color: _navy, size: 16)),
                    const SizedBox(width: 10),
                    const Text("Schedule Details",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _tDark)),
                  ]),
                  const SizedBox(height: 14),
                  _scheduleRow(Icons.upload_rounded, "Pickup",
                      "$pickupDate · $pickupTime", _blue),
                  const SizedBox(height: 12),
                  _scheduleRow(Icons.download_rounded, "Delivery",
                      "$deliveryDate · $deliveryTime", _green),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        color: _tFade, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text("$addressLabel: $address",
                            style: const TextStyle(
                                fontSize: 12,
                                color: _tMid,
                                fontWeight: FontWeight.w600))),
                  ]),
                ]),
              ),

              const SizedBox(height: 14),

              // ── Bill Breakdown ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]),
                child: Column(children: [
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: _navy.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: _navy, size: 16)),
                    const SizedBox(width: 10),
                    const Text("Bill Summary",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _tDark)),
                  ]),
                  const SizedBox(height: 16),
                  _billRow("Total Items", "$_totalItems items", false),
                  const SizedBox(height: 10),
                  _billRow(
                      "Subtotal", "₹${subtotal.toStringAsFixed(2)}", false),
                  const SizedBox(height: 10),
                  _billRow("Delivery Fee", "₹${deliveryFee.toStringAsFixed(2)}",
                      false),
                  const SizedBox(height: 10),
                  _billRow("GST (18%)", "₹${gst.toStringAsFixed(2)}", false),
                  const SizedBox(height: 14),
                  Container(height: 1, color: const Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Grand Total",
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: _tDark)),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [_navy, _navyMid]),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: _navy.withValues(alpha: 0.3),
                                      blurRadius: 10)
                                ]),
                            child: Text("₹${total.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18))),
                      ]),
                ]),
              ),

              const SizedBox(height: 24),
            ]),
          ),
        ),

        // ── Proceed to Payment Button ──────────────────────────────────────
        Container(
          decoration: BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ]),
          padding: EdgeInsets.fromLTRB(
              20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onProceed,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18))),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("PROCEED TO PAYMENT",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5)),
                const SizedBox(width: 10),
                Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.payment_rounded,
                        color: _gold, size: 16)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _scheduleRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 14)),
      const SizedBox(width: 10),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _tDark)),
      ])),
    ]);
  }

  Widget _billRow(String l, String v, bool bold) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l,
          style: TextStyle(
              fontSize: 13,
              color: bold ? _tDark : _tFade,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      Text(v,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: bold ? _navy : _tDark)),
    ]);
  }
}
