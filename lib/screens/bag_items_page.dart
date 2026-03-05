import 'package:flutter/material.dart';
import 'order_summary_page.dart';
import '../widgets/service_page_scaffold.dart';

class BagCleaningPage extends StatefulWidget {
  final bool fromSummary;
  const BagCleaningPage({super.key, this.fromSummary = false});
  @override
  State<BagCleaningPage> createState() => _BagCleaningPageState();
}

class _BagCleaningPageState extends State<BagCleaningPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _cartAnim;

  final List<Map<String, dynamic>> items = [
    {"name": "School Bag",      "price": 80,  "image": "images/items/bag_school.jpg",  "qty": 0, "category": "Casual"},
    {"name": "College Bag",     "price": 100, "image": "images/items/bag_college.jpg", "qty": 0, "category": "Casual"},
    {"name": "Office Bag",      "price": 120, "image": "images/items/bag_office.jpg",  "qty": 0, "category": "Formal"},
    {"name": "Ladies Hand Bag", "price": 150, "image": "images/items/bag_hand.jpg",    "qty": 0, "category": "Premium"},
    {"name": "Travel Bag",      "price": 200, "image": "images/items/bag_travel.jpg",  "qty": 0, "category": "Premium"},
    {"name": "Laptop Bag",      "price": 130, "image": "images/items/bag_laptop.jpg",  "qty": 0, "category": "Formal"},
    {"name": "Backpack",        "price": 110, "image": "images/items/bag_back.jpg",    "qty": 0, "category": "Casual"},
    {"name": "Clutch / Purse",  "price": 90,  "image": "images/items/bag_clutch.jpg",  "qty": 0, "category": "Premium"},
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
      Navigator.pop(context, {"serviceName": "Bag Cleaning", "items": sel});
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderSummaryPage(serviceName: "Bag Cleaning", selectedItems: sel)));
    }
  }

  @override
  Widget build(BuildContext context) => ServicePageScaffold(
    serviceName: "Bag Cleaning",
    serviceIcon: Icons.shopping_bag_rounded,
    serviceColor: const Color(0xFFD97706),
    items: items,
    totalItems: totalItems,
    totalAmount: totalAmount,
    onCheckout: _checkout,
    onIncrement: _inc,
    onDecrement: _dec,
    cartAnimController: _cartAnim,
  );
}
