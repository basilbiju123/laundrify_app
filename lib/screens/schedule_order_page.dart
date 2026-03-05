import 'package:flutter/material.dart';
import 'payment_page.dart';
import '../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════
// SCHEDULE ORDER PAGE — Elegant redesign
// Step 1: Schedule   Step 2: Review Invoice   Step 3: Payment
// ════════════════════════════════════════════════════════════
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

class _ScheduleOrderPageState extends State<ScheduleOrderPage>
    with TickerProviderStateMixin {
  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;
  DateTime? _deliveryDate;
  TimeOfDay? _deliveryTime;
  bool _pickupEnabled = true;
  bool _deliveryEnabled = true;
  String _paymentMethod = 'online';
  bool _showInvoice = false;

  late AnimationController _pageAnimCtrl;
  late Animation<double> _pageFade;

  static const _navy = Color(0xFF080F1E);
  static const _gold = Color(0xFFF5C518);
  static const _blue = Color(0xFF1B4FD8);
  static const _green = Color(0xFF059669);

  double get _subtotal => widget.totalAmount;
  double get _deliveryFee => 40.0;
  double get _gst => _subtotal * 0.05;
  double get _grandTotal => _subtotal + _deliveryFee + _gst;

  @override
  void initState() {
    super.initState();
    _pageAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _pageFade = CurvedAnimation(parent: _pageAnimCtrl, curve: Curves.easeOut);
    _pageAnimCtrl.forward();
  }

  @override
  void dispose() {
    _pageAnimCtrl.dispose();
    super.dispose();
  }

  bool _isSameDateTime(DateTime d1, TimeOfDay t1, DateTime d2, TimeOfDay t2) =>
      d1.year == d2.year &&
      d1.month == d2.month &&
      d1.day == d2.day &&
      t1.hour == t2.hour &&
      t1.minute == t2.minute;

  bool _hasMinGap(DateTime pD, TimeOfDay pT, DateTime dD, TimeOfDay dT) {
    final pickup = DateTime(pD.year, pD.month, pD.day, pT.hour, pT.minute);
    final delivery = DateTime(dD.year, dD.month, dD.day, dT.hour, dT.minute);
    return delivery.difference(pickup).inMinutes >= 90;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtTime(TimeOfDay t, BuildContext ctx) => t.format(ctx);

  String _dayLabel(DateTime d) {
    final today = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(d.weekday - 1) % 7];
  }

  Future<void> _pickDate({required bool isPickup}) async {
    final now = DateTime.now();
    final earliest = isPickup ? now : (_pickupDate ?? now);
    final initial = isPickup
        ? (_pickupDate ?? now.add(const Duration(days: 1)))
        : (_deliveryDate ?? earliest.add(const Duration(days: 1)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: now.add(Duration(days: isPickup ? 14 : 21)),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (picked != null && mounted) {
      setState(() => isPickup ? _pickupDate = picked : _deliveryDate = picked);
    }
  }

  Future<void> _pickTime({required bool isPickup}) async {
    final init = isPickup
        ? (_pickupTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_deliveryTime ?? const TimeOfDay(hour: 18, minute: 0));
    final picked = await showTimePicker(
        context: context,
        initialTime: init,
        builder: (ctx, child) => _themedPicker(ctx, child));
    if (picked != null && mounted) {
      setState(() => isPickup ? _pickupTime = picked : _deliveryTime = picked);
    }
  }

  Widget _themedPicker(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: _navy,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _navy),
          dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)))),
        ),
        child: child!,
      );

  void _proceed() {
    if (_pickupEnabled) {
      if (_pickupDate == null) {
        _snack('Select a pickup date');
        return;
      }
      if (_pickupTime == null) {
        _snack('Select a pickup time');
        return;
      }
    }
    if (_deliveryEnabled) {
      if (_deliveryDate == null) {
        _snack('Select a delivery date');
        return;
      }
      if (_deliveryTime == null) {
        _snack('Select a delivery time');
        return;
      }
    }
    if (_pickupEnabled &&
        _deliveryEnabled &&
        _pickupDate != null &&
        _pickupTime != null &&
        _deliveryDate != null &&
        _deliveryTime != null) {
      if (_isSameDateTime(
          _pickupDate!, _pickupTime!, _deliveryDate!, _deliveryTime!)) {
        _snack('Pickup and delivery cannot be at the same time');
        return;
      }
      if (!_hasMinGap(
          _pickupDate!, _pickupTime!, _deliveryDate!, _deliveryTime!)) {
        _snack('Delivery must be at least 1.5 hrs after pickup');
        return;
      }
    }
    setState(() {
      _showInvoice = true;
      _pageAnimCtrl.forward(from: 0);
    });
  }

  void _confirmAndPay() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          totalAmount: _grandTotal,
          totalItems: widget.totalItems,
          services: widget.services,
          pickupDate: _pickupDate != null ? _fmtDate(_pickupDate!) : '',
          pickupTime:
              _pickupTime != null ? _fmtTime(_pickupTime!, context) : '',
          deliveryDate: _deliveryDate != null ? _fmtDate(_deliveryDate!) : '',
          deliveryTime:
              _deliveryTime != null ? _fmtTime(_deliveryTime!, context) : '',
          paymentMethod: _paymentMethod,
        ),
      ));

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 10),
          Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: FadeTransition(
              opacity: _pageFade,
              child: _showInvoice ? _buildInvoice() : _buildSchedule(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: () {
                  if (_showInvoice) {
                    setState(() {
                      _showInvoice = false;
                      _pageAnimCtrl.forward(from: 0);
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      _showInvoice ? 'Review Invoice' : 'Schedule Order',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                    Text(
                      _showInvoice
                          ? 'Verify details before payment'
                          : 'Choose your preferred timings',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ])),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shopping_bag_rounded,
                      color: _gold, size: 13),
                  const SizedBox(width: 5),
                  Text('${widget.totalItems} items',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _gold)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            _stepper(),
          ]),
        ),
      );

  Widget _stepper() {
    final steps = ['Schedule', 'Invoice', 'Payment'];
    final current = _showInvoice ? 1 : 0;
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = i ~/ 2 < current;
          return Expanded(
              child: Container(
                  height: 2,
                  color: done ? _gold : Colors.white.withValues(alpha: 0.15)));
        }
        final idx = i ~/ 2;
        final done = idx <= current;
        final active = idx == current;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: done ? _gold : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: done ? _gold : Colors.white.withValues(alpha: 0.2),
                  width: active ? 2.5 : 1.5),
              boxShadow: done
                  ? [
                      BoxShadow(
                          color: _gold.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]
                  : null,
            ),
            child: Center(
                child: (done && idx < current)
                    ? const Icon(Icons.check_rounded, size: 16, color: _navy)
                    : Text('${idx + 1}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: done
                                ? _navy
                                : Colors.white.withValues(alpha: 0.35)))),
          ),
          const SizedBox(height: 5),
          Text(steps[idx],
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: done ? _gold : Colors.white.withValues(alpha: 0.35))),
        ]);
      }),
    );
  }

  // ───────────────────────────────────────────────────────────
  // SCHEDULE VIEW
  // ───────────────────────────────────────────────────────────
  Widget _buildSchedule() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        physics: const BouncingScrollPhysics(),
        child: Column(children: [
          _scheduleCard(
              isPickup: true,
              title: 'Pickup',
              subtitle: 'When should we collect your laundry?',
              icon: Icons.local_laundry_service_rounded,
              accentColor: _blue,
              enabled: _pickupEnabled,
              date: _pickupDate,
              time: _pickupTime,
              onToggle: (v) => setState(() => _pickupEnabled = v),
              onDateTap: () => _pickDate(isPickup: true),
              onTimeTap: () => _pickTime(isPickup: true)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 28),
            child: Row(children: [
              Column(children: [
                Container(
                    width: 1.5,
                    height: 10,
                    color: _blue.withValues(alpha: 0.3)),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: _green.withValues(alpha: 0.3))),
                  child: const Icon(Icons.arrow_downward_rounded,
                      size: 12, color: _green),
                ),
                Container(
                    width: 1.5,
                    height: 10,
                    color: _green.withValues(alpha: 0.3)),
              ]),
              const SizedBox(width: 10),
              Text('Est. 1–3 days turnaround',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          _scheduleCard(
              isPickup: false,
              title: 'Delivery',
              subtitle: 'When should we return your clean laundry?',
              icon: Icons.delivery_dining_rounded,
              accentColor: _green,
              enabled: _deliveryEnabled,
              date: _deliveryDate,
              time: _deliveryTime,
              onToggle: (v) => setState(() => _deliveryEnabled = v),
              onDateTap: () => _pickDate(isPickup: false),
              onTimeTap: () => _pickTime(isPickup: false),
              hint: (_pickupEnabled && _pickupTime != null)
                  ? 'Min. 1.5 hrs after pickup (${_pickupTime!.format(context)})'
                  : null),
          const SizedBox(height: 20),
          _paymentSection(),
          const SizedBox(height: 20),
          _priceSummaryCompact(),
          const SizedBox(height: 24),
          _ctaBtn(
              label: 'REVIEW ORDER',
              icon: Icons.receipt_long_rounded,
              onTap: _proceed),
        ]),
      );

  Widget _scheduleCard({
    required bool isPickup,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool enabled,
    required DateTime? date,
    required TimeOfDay? time,
    required ValueChanged<bool> onToggle,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
    String? hint,
  }) {
    final t = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: enabled ? accentColor.withValues(alpha: 0.25) : t.cardBdr,
            width: enabled ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: enabled
                  ? accentColor.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: t.isDark ? 0.2 : 0.025),
              blurRadius: enabled ? 16 : 6,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: enabled ? accentColor.withValues(alpha: 0.1) : t.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color:
                        accentColor.withValues(alpha: enabled ? 0.18 : 0.06)),
              ),
              child: Icon(icon,
                  color: enabled ? accentColor : t.textDim, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: t.textHi)),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
            _toggle(
                enabled: enabled,
                color: accentColor,
                onTap: () => onToggle(!enabled)),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: enabled
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        const SizedBox(height: 16),
                        if (hint != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color:
                                        accentColor.withValues(alpha: 0.12))),
                            child: Row(children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 14, color: accentColor),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(hint,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: accentColor,
                                          fontWeight: FontWeight.w600))),
                            ]),
                          ),
                        Row(children: [
                          Expanded(
                              child: _pickerTile(
                                  Icons.calendar_month_rounded,
                                  date != null
                                      ? '${_dayLabel(date)}, ${date.day}/${date.month}'
                                      : 'Select Date',
                                  date != null,
                                  accentColor,
                                  onDateTap)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _pickerTile(
                                  Icons.schedule_rounded,
                                  time != null
                                      ? time.format(context)
                                      : 'Select Time',
                                  time != null,
                                  accentColor,
                                  onTimeTap)),
                        ]),
                        if (date != null && time != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 14, color: accentColor),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                '${_dayLabel(date)}, ${_fmtDate(date)} at ${time.format(context)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor),
                              )),
                            ]),
                          ),
                        ],
                      ])
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _toggle(
          {required bool enabled,
          required Color color,
          required VoidCallback onTap}) =>
      GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 48,
            height: 26,
            decoration: BoxDecoration(
              color: enabled ? color : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(13),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle)),
            ),
          ));

  Widget _pickerTile(IconData icon, String label, bool selected, Color color,
      VoidCallback onTap) {
    final t = AppColors.of(context);
    return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.07) : t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? color.withValues(alpha: 0.35) : t.cardBdr,
                width: selected ? 1.5 : 1),
          ),
          child: Row(children: [
            Icon(icon, size: 17, color: selected ? color : t.textDim),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? t.textHi : t.textDim))),
          ]),
        ));
  }

  Widget _paymentSection() {
    final t = AppColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Payment Method',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: t.textHi)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _paymentTile('online', 'Online Pay',
                Icons.credit_card_rounded, _blue, 'UPI / Card / Net Banking')),
        const SizedBox(width: 12),
        Expanded(
            child: _paymentTile('cod', 'Cash on Delivery',
                Icons.payments_rounded, _green, 'Pay when delivered')),
      ]),
    ]);
  }

  Widget _paymentTile(
      String method, String label, IconData icon, Color color, String sub) {
    final active = _paymentMethod == method;
    final t = AppColors.of(context);
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.07) : t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? color : const Color(0xFFE8EDF5),
              width: active ? 2 : 1),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: active ? color.withValues(alpha: 0.15) : t.surface,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: active ? color : t.textDim, size: 18)),
            const Spacer(),
            if (active)
              Container(
                  width: 18,
                  height: 18,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)),
          ]),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: active ? t.textHi : t.textMid)),
          const SizedBox(height: 2),
          Text(sub,
              style: TextStyle(
                  fontSize: 10, color: t.textDim, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _priceSummaryCompact() {
    final t = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.cardBdr)),
      child: Column(children: [
        _priceRow('Subtotal', '₹${_subtotal.toStringAsFixed(0)}', false),
        const SizedBox(height: 6),
        _priceRow('Delivery Fee', '₹${_deliveryFee.toStringAsFixed(0)}', false),
        const SizedBox(height: 6),
        _priceRow('GST (5%)', '₹${_gst.toStringAsFixed(0)}', false),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: t.cardBdr)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [AppColors.navy, Color(0xFF1A3057)]),
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('TOTAL',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8)),
            Text('₹${_grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold)),
          ]),
        ),
      ]),
    );
  }

  Widget _priceRow(String label, String value, bool bold) {
    final t = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: bold ? t.textHi : t.textMid,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: bold ? t.textHi : t.textMid)),
      ],
    );
  }

  Widget _ctaBtn(
          {required String label,
          required IconData icon,
          required VoidCallback onTap}) =>
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: _navy,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 4,
            shadowColor: _gold.withValues(alpha: 0.4),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ]),
        ),
      );

  // ───────────────────────────────────────────────────────────
  // INVOICE VIEW
  // ───────────────────────────────────────────────────────────
  Widget _buildInvoice() {
    final pickupStr = _pickupEnabled && _pickupDate != null
        ? '${_dayLabel(_pickupDate!)}, ${_fmtDate(_pickupDate!)} at ${_pickupTime?.format(context) ?? ''}'
        : 'Not scheduled';
    final deliveryStr = _deliveryEnabled && _deliveryDate != null
        ? '${_dayLabel(_deliveryDate!)}, ${_fmtDate(_deliveryDate!)} at ${_deliveryTime?.format(context) ?? ''}'
        : 'Not scheduled';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      physics: const BouncingScrollPhysics(),
      child: Column(children: [
        Builder(builder: (context) {
          final t = AppColors.of(context);
          return Container(
            decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: t.isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6))
                ]),
            child: Column(children: [
              // Dark header
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_navy, Color(0xFF0D2545)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(
                                  Icons.local_laundry_service_rounded,
                                  color: _gold,
                                  size: 16)),
                          const SizedBox(width: 10),
                          const Text('LAUNDRIFY',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _gold,
                                  letterSpacing: 2)),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _gold.withValues(alpha: 0.25))),
                          child: Text(
                              _paymentMethod == 'cod'
                                  ? 'CASH ON DELIVERY'
                                  : 'ONLINE PAYMENT',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _gold,
                                  letterSpacing: 0.5)),
                        ),
                      ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1))),
                    child: Column(children: [
                      _invoiceTimeRow(Icons.local_laundry_service_rounded,
                          'Pickup', pickupStr, _blue),
                      const SizedBox(height: 10),
                      _invoiceTimeRow(Icons.delivery_dining_rounded, 'Delivery',
                          deliveryStr, _green),
                    ]),
                  ),
                ]),
              ),

              // Items
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Items',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _navy)),
                      const SizedBox(height: 12),
                      ...widget.services.map((svc) {
                        final items = ((svc['items'] as List?) ?? [])
                            .where((i) => ((i as Map)['qty'] ?? 0) > 0)
                            .toList();
                        if (items.isEmpty) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppColors.of(context).surface,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE8EDF5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                          color: _gold,
                                          shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text(svc['title'] ?? svc['serviceName'] ?? '',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)),
                                ]),
                                const SizedBox(height: 8),
                                ...items.map((item) {
                                  final m = item as Map;
                                  final qty = m['qty'] ?? 0;
                                  final price = (m['price'] ?? 0) as num;
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        left: 14, bottom: 4),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${m['name']} × $qty',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B))),
                                          Text(
                                              '₹${(qty * price).toStringAsFixed(0)}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700)),
                                        ]),
                                  );
                                }),
                              ]),
                        );
                      }),
                      const SizedBox(height: 4),
                      // Price summary in invoice
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppColors.of(context).surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8EDF5))),
                        child: Column(children: [
                          _priceRow('Subtotal',
                              '₹${_subtotal.toStringAsFixed(0)}', false),
                          const SizedBox(height: 6),
                          _priceRow('Delivery Fee',
                              '₹${_deliveryFee.toStringAsFixed(0)}', false),
                          const SizedBox(height: 6),
                          _priceRow('GST (5%)', '₹${_gst.toStringAsFixed(0)}',
                              false),
                          const Divider(height: 20, color: Color(0xFFE8EDF5)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [_navy, Color(0xFF1A3057)]),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('GRAND TOTAL',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.8)),
                                  Text('₹${_grandTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: _gold)),
                                ]),
                          ),
                        ]),
                      ),
                    ]),
              ),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(24)),
                    border: Border(top: BorderSide(color: Color(0xFFE8EDF5)))),
                child: const Row(children: [
                  Icon(Icons.verified_rounded, color: _green, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Computer-generated invoice. No signature required.',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8)))),
                ]),
              ),
            ]),
          );
        }), // end Builder

        const SizedBox(height: 24),
        _ctaBtn(
          label: 'CONFIRM & PAY  •  ₹${_grandTotal.toStringAsFixed(0)}',
          icon: Icons.lock_rounded,
          onTap: _confirmAndPay,
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: () => setState(() {
            _showInvoice = false;
            _pageAnimCtrl.forward(from: 0);
          }),
          icon: const Icon(Icons.edit_rounded,
              size: 14, color: Color(0xFF64748B)),
          label: const Text('Edit Schedule',
              style: TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _invoiceTimeRow(
          IconData icon, String label, String value, Color color) =>
      Row(children: [
        Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 14)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.5))),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ])),
      ]);
}
