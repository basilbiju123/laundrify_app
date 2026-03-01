import 'package:flutter/material.dart';
import 'order_summary_page.dart';

class ShoeDryCleanPage extends StatefulWidget {
  final bool fromSummary;
  const ShoeDryCleanPage({super.key, this.fromSummary = false});

  @override
  State<ShoeDryCleanPage> createState() => _ShoeDryCleanPageState();
}

class _ShoeDryCleanPageState extends State<ShoeDryCleanPage> {
  static const _navy = Color(0xFF080F1E);
  static const _gold = Color(0xFFF5C518);
  static const _bg = Color(0xFFF0F4FF);

  final List<Map<String, dynamic>> _items = [
    {'name': 'Sneakers (pair)', 'price': 149.0, 'qty': 0},
    {'name': 'Formal Shoes (pair)', 'price': 179.0, 'qty': 0},
    {'name': 'Sports Shoes (pair)', 'price': 169.0, 'qty': 0},
    {'name': 'Boots (pair)', 'price': 199.0, 'qty': 0},
    {'name': 'Sandals (pair)', 'price': 99.0, 'qty': 0},
    {'name': 'Heels (pair)', 'price': 149.0, 'qty': 0},
    {'name': 'Canvas Shoes (pair)', 'price': 129.0, 'qty': 0},
    {'name': 'Leather Polish', 'price': 79.0, 'qty': 0},
  ];

  double get _total =>
      _items.fold(0.0, (sum, item) => sum + item['price'] * item['qty']);
  int get _totalItems =>
      _items.fold(0, (sum, item) => sum + (item['qty'] as int));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Shoe Cleaning',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.cleaning_services_rounded,
                    color: Color(0xFFF5C518), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Professional shoe cleaning and restoration service',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF080F1E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A1628),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${item['price'].toStringAsFixed(0)}/item',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (item['qty'] > 0) {
                            setState(() => _items[i]['qty']--);
                          }
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: item['qty'] > 0
                                ? _navy
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: item['qty'] > 0
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Container(
                        width: 36,
                        alignment: Alignment.center,
                        child: Text(
                          '${item['qty']}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A1628),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _items[i]['qty']++),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, size: 16, color: _navy),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: _totalItems > 0
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_totalItems items',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Text(
                          '₹${_total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0A1628),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final selectedItems =
                          _items.where((i) => i['qty'] > 0).toList();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderSummaryPage(
                            serviceName: 'Shoe Clean',
                            selectedItems: selectedItems,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Add to Order',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
