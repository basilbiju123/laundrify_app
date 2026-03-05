import 'package:flutter/material.dart';
import 'order_summary_page.dart';
import '../widgets/service_page_scaffold.dart';

class ShoeDryCleanPage extends StatefulWidget {
  final bool fromSummary;
  const ShoeDryCleanPage({super.key, this.fromSummary = false});
  @override
  State<ShoeDryCleanPage> createState() => _ShoeDryCleanPageState();
}

class _ShoeDryCleanPageState extends State<ShoeDryCleanPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _cartAnim;

  final List<Map<String, dynamic>> items = [
    {"name": "Sneakers (pair)",       "price": 149, "icon": Icons.sports_handball_rounded, "qty": 0, "category": "Casual"},
    {"name": "Formal Shoes (pair)",   "price": 179, "icon": Icons.work_rounded,             "qty": 0, "category": "Formal"},
    {"name": "Sports Shoes (pair)",   "price": 169, "icon": Icons.directions_run_rounded,   "qty": 0, "category": "Sports"},
    {"name": "Boots (pair)",          "price": 199, "icon": Icons.hiking_rounded,            "qty": 0, "category": "Premium"},
    {"name": "Sandals (pair)",        "price": 99,  "icon": Icons.beach_access_rounded,      "qty": 0, "category": "Casual"},
    {"name": "Heels (pair)",          "price": 149, "icon": Icons.female_rounded,            "qty": 0, "category": "Premium"},
    {"name": "Canvas Shoes (pair)",   "price": 129, "icon": Icons.style_rounded,             "qty": 0, "category": "Casual"},
    {"name": "Leather Polish",        "price": 79,  "icon": Icons.auto_fix_high_rounded,     "qty": 0, "category": "Add-on"},
  ];

  int get totalItems => items.fold(0, (s, i) => s + (i["qty"] as int));
  double get totalAmount => items.fold(0.0, (s, i) => s + (i["qty"] as int) * (i["price"] as int));

  @override
  void initState() {
    super.initState();
    _cartAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }
  @override
  void dispose() { _cartAnim.dispose(); super.dispose(); }

  void _inc(int i) { setState(() => items[i]["qty"]++); _cartAnim.forward().then((_) => _cartAnim.reverse()); }
  void _dec(int i) { if (items[i]["qty"] > 0) setState(() => items[i]["qty"]--); }

  void _checkout() {
    final sel = items.where((i) => i["qty"] > 0)
        .map((i) => {"name": i["name"], "price": i["price"], "qty": i["qty"], "image": ""}).toList();
    if (sel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one item'), backgroundColor: Colors.orange));
      return;
    }
    if (widget.fromSummary) {
      Navigator.pop(context, {'serviceName': 'Shoe Clean', 'items': sel});
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderSummaryPage(serviceName: "Shoe Clean", selectedItems: sel)));
    }
  }

  @override
  Widget build(BuildContext context) => ServicePageScaffold(
    serviceName: 'Shoe Cleaning',
    serviceIcon: Icons.checkroom_rounded,
    serviceColor: const Color(0xFF0891B2),
    items: items,
    totalItems: totalItems,
    totalAmount: totalAmount,
    onCheckout: _checkout,
    onIncrement: _inc,
    onDecrement: _dec,
    cartAnimController: _cartAnim,
  );
}
