import 'package:flutter/material.dart';
import 'order_summary_page.dart';
import '../widgets/service_page_scaffold.dart';

class DryCleanPage extends StatefulWidget {
  final bool fromSummary;
  const DryCleanPage({super.key, this.fromSummary = false});
  @override
  State<DryCleanPage> createState() => _DryCleanPageState();
}

class _DryCleanPageState extends State<DryCleanPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _cartAnim;

  final List<Map<String, dynamic>> items = [
    {"name": "Shirt (Formal)",    "price": 40,  "image": "images/items/shirtformal.jpg",  "qty": 0, "category": "Formal"},
    {"name": "Pant (Formal)",     "price": 45,  "image": "images/items/pantformal.jpg",   "qty": 0, "category": "Formal"},
    {"name": "Suit (2 Piece)",    "price": 200, "image": "images/items/suit2.jpg",         "qty": 0, "category": "Premium"},
    {"name": "Suit (3 Piece)",    "price": 280, "image": "images/items/suit3.jpg",         "qty": 0, "category": "Premium"},
    {"name": "Blazer",            "price": 180, "image": "images/items/blazer.jpg",        "qty": 0, "category": "Premium"},
    {"name": "Saree (Silk)",      "price": 120, "image": "images/items/saree.jpg",         "qty": 0, "category": "Traditional"},
    {"name": "Sherwani",          "price": 350, "image": "images/items/sherwani.jpg",      "qty": 0, "category": "Traditional"},
    {"name": "Lehenga",           "price": 400, "image": "images/items/lehenga.jpg",       "qty": 0, "category": "Traditional"},
    {"name": "Kurta (Cotton)",    "price": 60,  "image": "images/items/kurta.jpg",         "qty": 0, "category": "Casual"},
    {"name": "Jacket",            "price": 150, "image": "images/items/jacket.jpg",        "qty": 0, "category": "Premium"},
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
        .map((i) => {"name": i["name"], "price": i["price"], "qty": i["qty"], "image": i["image"]}).toList();
    if (sel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one item'), backgroundColor: Colors.orange));
      return;
    }
    if (widget.fromSummary) {
      Navigator.pop(context, {'serviceName': 'Dry Clean', 'items': sel});
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderSummaryPage(serviceName: "Dry Clean", selectedItems: sel)));
    }
  }

  @override
  Widget build(BuildContext context) => ServicePageScaffold(
    serviceName: 'Dry Clean',
    serviceIcon: Icons.dry_cleaning_rounded,
    serviceColor: const Color(0xFF7C3AED),
    items: items,
    totalItems: totalItems,
    totalAmount: totalAmount,
    onCheckout: _checkout,
    onIncrement: _inc,
    onDecrement: _dec,
    cartAnimController: _cartAnim,
  );
}
