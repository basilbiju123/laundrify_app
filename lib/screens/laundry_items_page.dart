import 'package:flutter/material.dart';
import 'constants.dart';
import 'order_summary_page.dart';
import '../widgets/service_page_scaffold.dart';

class LaundryPage extends StatefulWidget {
  final bool fromSummary;
  const LaundryPage({super.key, this.fromSummary = false});
  @override
  State<LaundryPage> createState() => _LaundryPageState();
}

class _LaundryPageState extends State<LaundryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _cartAnim;

  final List<Map<String, dynamic>> items = [
    {"name": "Shirt",          "price": 20,  "image": "images/items/shirt.jpg",     "qty": 0, "category": "Regular"},
    {"name": "T-Shirt",        "price": 18,  "image": "images/items/tshirt.jpg",    "qty": 0, "category": "Regular"},
    {"name": "Pant",           "price": 25,  "image": "images/items/pant.jpg",      "qty": 0, "category": "Regular"},
    {"name": "Jeans",          "price": 30,  "image": "images/items/jeans.jpg",     "qty": 0, "category": "Regular"},
    {"name": "Saree (Cotton)", "price": 40,  "image": "images/items/saree.jpg",     "qty": 0, "category": "Traditional"},
    {"name": "Party Wear",     "price": 60,  "image": "images/items/partywear.jpg", "qty": 0, "category": "Premium"},
    {"name": "Wedding Dress",  "price": 150, "image": "images/items/wedding.jpg",   "qty": 0, "category": "Premium"},
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
      Navigator.pop(context, {'serviceName': 'Laundry', 'items': sel});
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderSummaryPage(serviceName: "Laundry", selectedItems: sel)));
    }
  }

  @override
  Widget build(BuildContext context) => ServicePageScaffold(
    serviceName: 'Laundry',
    serviceIcon: Icons.local_laundry_service_rounded,
    serviceColor: primaryBlue,
    items: items,
    totalItems: totalItems,
    totalAmount: totalAmount,
    onCheckout: _checkout,
    onIncrement: _inc,
    onDecrement: _dec,
    cartAnimController: _cartAnim,
  );
}
