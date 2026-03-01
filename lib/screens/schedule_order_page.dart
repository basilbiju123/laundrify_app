import 'package:flutter/material.dart';
import 'payment_page.dart';

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
    with SingleTickerProviderStateMixin {
  // Pickup
  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;

  // Delivery
  DateTime? _deliveryDate;
  TimeOfDay? _deliveryTime;

  // Toggles
  bool _pickupEnabled = true;
  bool _deliveryEnabled = true;

  String _paymentMethod = 'online';
  bool _showInvoice = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _navy = Color(0xFF080F1E);
  static const _gold = Color(0xFFF5C518);
  static const _bg = Color(0xFFF5F7FF);
  static const _card = Colors.white;

  // Fees
  double get _subtotal => widget.totalAmount;
  double get _deliveryFee => 20.0;
  double get _gst => _subtotal * 0.05;
  double get _grandTotal => _subtotal + _deliveryFee + _gst;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Validation helpers ────────────────────────────────────────
  bool _isSameDateTime(DateTime date, TimeOfDay time, DateTime oDate, TimeOfDay oTime) {
    return date.year == oDate.year &&
        date.month == oDate.month &&
        date.day == oDate.day &&
        time.hour == oTime.hour &&
        time.minute == oTime.minute;
  }

  bool _hasMinGap(DateTime pDate, TimeOfDay pTime, DateTime dDate, TimeOfDay dTime) {
    final pickup = DateTime(pDate.year, pDate.month, pDate.day, pTime.hour, pTime.minute);
    final delivery = DateTime(dDate.year, dDate.month, dDate.day, dTime.hour, dTime.minute);
    return delivery.difference(pickup).inMinutes >= 90;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTime(TimeOfDay t, BuildContext ctx) => t.format(ctx);

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dt = DateTime(d.year, d.month, d.day);
    final diff = dt.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(d.weekday - 1) % 7];
  }

  // ── Date/Time pickers ─────────────────────────────────────────
  Future<void> _pickPickupDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (picked != null && mounted) setState(() => _pickupDate = picked);
  }

  Future<void> _pickPickupTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _pickupTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (picked != null && mounted) setState(() => _pickupTime = picked);
  }

  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final earliest = _pickupDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? earliest.add(const Duration(days: 1)),
      firstDate: earliest,
      lastDate: now.add(const Duration(days: 21)),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (picked != null && mounted) setState(() => _deliveryDate = picked);
  }

  Future<void> _pickDeliveryTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _deliveryTime ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (picked != null && mounted) setState(() => _deliveryTime = picked);
  }

  Widget _themedPicker(BuildContext ctx, Widget? child) {
    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(
          primary: _navy, onPrimary: Colors.white,
          surface: Colors.white, onSurface: _navy,
        ),
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        ),
      ),
      child: child!,
    );
  }

  // ── Validation & proceed ──────────────────────────────────────
  void _proceed() {
    if (_pickupEnabled) {
      if (_pickupDate == null) { _snack('Please select pickup date'); return; }
      if (_pickupTime == null) { _snack('Please select pickup time'); return; }
    }
    if (_deliveryEnabled) {
      if (_deliveryDate == null) { _snack('Please select delivery date'); return; }
      if (_deliveryTime == null) { _snack('Please select delivery time'); return; }
    }
    if (_pickupEnabled && _deliveryEnabled && _pickupDate != null && _pickupTime != null && _deliveryDate != null && _deliveryTime != null) {
      if (_isSameDateTime(_pickupDate!, _pickupTime!, _deliveryDate!, _deliveryTime!)) {
        _snack('Pickup and delivery cannot be at the same date & time');
        return;
      }
      if (!_hasMinGap(_pickupDate!, _pickupTime!, _deliveryDate!, _deliveryTime!)) {
        _snack('Delivery must be at least 1.5 hours after pickup');
        return;
      }
    }
    setState(() => _showInvoice = true);
  }

  void _confirmAndPay() {
    final pickupDateStr = _pickupDate != null ? _formatDate(_pickupDate!) : '';
    final pickupTimeStr = _pickupTime != null ? _formatTime(_pickupTime!, context) : '';
    final deliveryDateStr = _deliveryDate != null ? _formatDate(_deliveryDate!) : '';
    final deliveryTimeStr = _deliveryTime != null ? _formatTime(_deliveryTime!, context) : '';

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaymentPage(
        totalAmount: _grandTotal,
        totalItems: widget.totalItems,
        services: widget.services,
        pickupDate: pickupDateStr,
        pickupTime: pickupTimeStr,
        deliveryDate: deliveryDateStr,
        deliveryTime: deliveryTimeStr,
        paymentMethod: _paymentMethod,
      ),
    ));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _navy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _showInvoice ? 'Order Invoice' : 'Schedule & Pay',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_showInvoice) { setState(() => _showInvoice = false); }
            else { Navigator.pop(context); }
          },
        ),
      ),
      body: _showInvoice ? _buildInvoiceView() : _buildScheduleView(),
    );
  }

  // ── SCHEDULE VIEW ─────────────────────────────────────────────
  Widget _buildScheduleView() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Progress indicator ──
            _progressBar(step: 1),
            const SizedBox(height: 20),

            // ── Pickup Section ──
            _sectionCard(
              icon: Icons.local_laundry_service_rounded,
              iconColor: const Color(0xFF1B4FD8),
              title: 'Pickup',
              subtitle: 'When should we pick up your laundry?',
              enabled: _pickupEnabled,
              onToggle: (v) => setState(() { _pickupEnabled = v; }),
              child: _pickupEnabled ? Column(children: [
                const SizedBox(height: 16),
                _dateTimeRow(
                  date: _pickupDate,
                  time: _pickupTime,
                  onDateTap: _pickPickupDate,
                  onTimeTap: _pickPickupTime,
                  color: const Color(0xFF1B4FD8),
                ),
              ]) : const SizedBox.shrink(),
            ),

            const SizedBox(height: 14),

            // ── Connector line ──
            Center(
              child: Container(
                width: 2, height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B4FD8), Color(0xFF059669)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Delivery Section ──
            _sectionCard(
              icon: Icons.delivery_dining_rounded,
              iconColor: const Color(0xFF059669),
              title: 'Delivery',
              subtitle: 'When should we deliver back to you?',
              enabled: _deliveryEnabled,
              onToggle: (v) => setState(() { _deliveryEnabled = v; }),
              child: _deliveryEnabled ? Column(children: [
                const SizedBox(height: 16),
                if (_pickupDate != null && _pickupTime != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Min. 1.5 hrs after pickup (${_pickupTime!.format(context)})',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                      )),
                    ]),
                  ),
                _dateTimeRow(
                  date: _deliveryDate,
                  time: _deliveryTime,
                  onDateTap: _pickDeliveryDate,
                  onTimeTap: _pickDeliveryTime,
                  color: const Color(0xFF059669),
                ),
              ]) : const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // ── Payment Method ──
            _sectionLabel('Payment Method'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _paymentTile('online', 'Online Pay', Icons.credit_card_rounded, const Color(0xFF1B4FD8))),
                const SizedBox(width: 12),
                Expanded(child: _paymentTile('cod', 'Cash on Delivery', Icons.money_rounded, const Color(0xFF059669))),
              ],
            ),

            const SizedBox(height: 20),

            // ── Mini price summary ──
            _miniSummary(),

            const SizedBox(height: 24),

            // ── CTA ──
            _ctaButton('REVIEW INVOICE', Icons.receipt_long_rounded, _proceed),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── INVOICE VIEW ──────────────────────────────────────────────
  Widget _buildInvoiceView() {
    final pickupStr = _pickupEnabled && _pickupDate != null
        ? '${_dayLabel(_pickupDate!)}, ${_formatDate(_pickupDate!)} at ${_pickupTime?.format(context) ?? ''}'
        : 'Not scheduled';
    final deliveryStr = _deliveryEnabled && _deliveryDate != null
        ? '${_dayLabel(_deliveryDate!)}, ${_formatDate(_deliveryDate!)} at ${_deliveryTime?.format(context) ?? ''}'
        : 'Not scheduled';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _progressBar(step: 2),
          const SizedBox(height: 20),

          // ── Invoice card ──
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('INVOICE',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _navy, letterSpacing: 4)),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('LAUNDRIFY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _gold, letterSpacing: 2)),
                            const Text('Professional Laundry', style: TextStyle(fontSize: 11, color: Colors.white60)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(
                              '${widget.totalItems} item${widget.totalItems != 1 ? "s" : ""}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            Text(
                              'Payment: ${_paymentMethod == 'cod' ? 'COD' : 'Online'}',
                              style: const TextStyle(fontSize: 11, color: Colors.white60),
                            ),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),

                // Schedule
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _invoiceRow(Icons.local_laundry_service_rounded, 'Pickup', pickupStr, const Color(0xFF1B4FD8)),
                      const SizedBox(height: 10),
                      _invoiceRow(Icons.delivery_dining_rounded, 'Delivery', deliveryStr, const Color(0xFF059669)),
                      const Divider(height: 24),

                      // Services breakdown
                      ...widget.services.map((svc) {
                        final items = ((svc['items'] as List?) ?? []).where((i) => ((i as Map)['qty'] ?? 0) > 0).toList();
                        if (items.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(svc['title'] ?? svc['serviceName'] ?? '',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
                            ]),
                            const SizedBox(height: 6),
                            ...items.map((item) {
                              final m = item as Map;
                              final qty = m['qty'] ?? 0;
                              final price = (m['price'] ?? 0) as num;
                              return Padding(
                                padding: const EdgeInsets.only(left: 16, bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${m['name']} × $qty',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                    Text('₹${(qty * price).toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),

                      const Divider(height: 8),
                      const SizedBox(height: 12),

                      // Bill rows
                      _billRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}', false),
                      const SizedBox(height: 6),
                      _billRow('Delivery Fee', '₹${_deliveryFee.toStringAsFixed(2)}', false),
                      const SizedBox(height: 6),
                      _billRow('GST (5%)', '₹${_gst.toStringAsFixed(2)}', false),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _navy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GRAND TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                            Text('₹${_grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _gold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border.all(color: const Color(0xFFE8EDF5)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Computer-generated invoice. No signature required.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    )),
                  ]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Confirm & Pay button ──
          _ctaButton('CONFIRM & PAY  ₹${_grandTotal.toStringAsFixed(0)}', Icons.lock_rounded, _confirmAndPay),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _showInvoice = false),
            child: const Text('← Edit Schedule', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────

  Widget _progressBar({required int step}) {
    return Row(
      children: [
        _progressStep(1, 'Schedule', step >= 1),
        Expanded(child: Container(height: 2, color: step >= 2 ? _gold : const Color(0xFFE8EDF5))),
        _progressStep(2, 'Invoice', step >= 2),
        Expanded(child: Container(height: 2, color: const Color(0xFFE8EDF5))),
        _progressStep(3, 'Payment', false),
      ],
    );
  }

  Widget _progressStep(int n, String label, bool active) {
    return Column(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: active ? _navy : const Color(0xFFE8EDF5),
          shape: BoxShape.circle,
        ),
        child: Center(child: active
          ? (n < 3 ? const Icon(Icons.check_rounded, size: 16, color: _gold)
              : Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)))
          : Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
        color: active ? _navy : const Color(0xFF94A3B8))),
    ]);
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled ? iconColor.withValues(alpha: 0.3) : const Color(0xFFE8EDF5),
          width: enabled ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(
          color: enabled ? iconColor.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
          blurRadius: enabled ? 12 : 4,
          offset: const Offset(0, 3),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                )),
                Switch.adaptive(
                  value: enabled,
                  onChanged: onToggle,
                  activeThumbColor: iconColor,
                  activeTrackColor: iconColor.withValues(alpha: 0.3),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimeRow({
    required DateTime? date,
    required TimeOfDay? time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
    required Color color,
  }) {
    return Row(
      children: [
        Expanded(child: _pickerTile(
          icon: Icons.calendar_month_rounded,
          label: date != null ? '${_dayLabel(date)}, ${date.day}/${date.month}' : 'Pick Date',
          selected: date != null,
          color: color,
          onTap: onDateTap,
        )),
        const SizedBox(width: 10),
        Expanded(child: _pickerTile(
          icon: Icons.schedule_rounded,
          label: time != null ? time.format(context) : 'Pick Time',
          selected: time != null,
          color: color,
          onTap: onTimeTap,
        )),
      ],
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: selected ? color : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: selected ? _navy : const Color(0xFF94A3B8)),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          )),
        ]),
      ),
    );
  }

  Widget _paymentTile(String method, String label, IconData icon, Color color) {
    final active = _paymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.08) : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color : const Color(0xFFE8EDF5),
            width: active ? 2 : 1,
          ),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Column(children: [
          Icon(icon, color: active ? color : const Color(0xFF94A3B8), size: 24),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? _navy : const Color(0xFF94A3B8))),
        ]),
      ),
    );
  }

  Widget _miniSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Subtotal', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text('₹${_subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Delivery Fee', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text('₹${_deliveryFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('GST (5%)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text('₹${_gst.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
        ]),
        const Divider(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
          Text('₹${_grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _navy)),
        ]),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy));

  Widget _ctaButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold, foregroundColor: _navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          shadowColor: _gold.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _invoiceRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
        ]),
      ],
    );
  }

  Widget _billRow(String label, String value, bool bold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: bold ? _navy : const Color(0xFF475569),
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: bold ? _navy : const Color(0xFF475569))),
      ],
    );
  }
}
