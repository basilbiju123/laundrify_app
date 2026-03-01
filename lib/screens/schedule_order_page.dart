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

class _ScheduleOrderPageState extends State<ScheduleOrderPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _paymentMethod = 'online';
  final bool _isPlacing = false;

  static const _navy = Color(0xFF080F1E);
  static const _gold = Color(0xFFF5C518);
  static const _bg = Color(0xFFF0F4FF);
  static const _card = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Schedule Pickup',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ORDER SUMMARY
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.totalItems} items across ${widget.services.length} services',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        '₹${widget.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _navy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // PICKUP DATE
            _sectionTitle('Pickup Date'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedDate != null ? _gold : const Color(0xFFE8EDF5),
                    width: _selectedDate != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: _selectedDate != null ? _gold : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select pickup date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedDate != null ? _navy : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // PICKUP TIME
            _sectionTitle('Pickup Time'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedTime != null ? _gold : const Color(0xFFE8EDF5),
                    width: _selectedTime != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: _selectedTime != null ? _gold : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : 'Select pickup time',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedTime != null ? _navy : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // PAYMENT METHOD
            _sectionTitle('Payment Method'),
            const SizedBox(height: 12),
            Row(
              children: ['online', 'cod'].map((method) {
                final active = _paymentMethod == method;
                return Expanded(
                  child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = method),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: active ? _gold.withValues(alpha: 0.15) : _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active ? _gold : const Color(0xFFE8EDF5),
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          method == 'online'
                              ? Icons.credit_card_rounded
                              : Icons.money_rounded,
                          color: active ? _gold : const Color(0xFF94A3B8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          method == 'online' ? 'Online' : 'Cash on Delivery',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: active ? _navy : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // PLACE ORDER BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _isPlacing ? null : _placeOrder,
                child: _isPlacing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF080F1E),
                        ),
                      )
                    : const Text(
                        'PLACE ORDER',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: _navy,
        ),
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _placeOrder() async {
    if (_selectedDate == null) {
      _showSnack('Please select a pickup date');
      return;
    }
    if (_selectedTime == null) {
      _showSnack('Please select a pickup time');
      return;
    }
    final pickupDateStr =
        '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    final pickupTimeStr = _selectedTime!.format(context);
    // Navigate to PaymentPage — it handles Firestore write after payment
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          totalAmount: widget.totalAmount,
          totalItems: widget.totalItems,
          services: widget.services,
          pickupDate: pickupDateStr,
          pickupTime: pickupTimeStr,
          paymentMethod: _paymentMethod,
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0A1628),
      ),
    );
  }
}
