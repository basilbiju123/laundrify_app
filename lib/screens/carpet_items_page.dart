import 'package:flutter/material.dart';
import 'order_summary_page.dart';
import '../widgets/service_page_scaffold.dart';

class CarpetCleaningPage extends StatefulWidget {
  final bool fromSummary;
  const CarpetCleaningPage({super.key, this.fromSummary = false});
  @override
  State<CarpetCleaningPage> createState() => _CarpetCleaningPageState();
}

class _CarpetCleaningPageState extends State<CarpetCleaningPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _cartAnim;

  final List<Map<String, dynamic>> items = [
    {"name": "Small Carpet",        "price": 120, "image": "images/items/carpet_small.jpg",  "qty": 0, "category": "Standard"},
    {"name": "Medium Carpet",       "price": 180, "image": "images/items/carpet_medium.jpg", "qty": 0, "category": "Standard"},
    {"name": "Large Carpet",        "price": 250, "image": "images/items/carpet_large.jpg",  "qty": 0, "category": "Premium"},
    {"name": "Wall-to-Wall Carpet", "price": 350, "image": "images/items/carpet_wall.jpg",   "qty": 0, "category": "Premium"},
    {"name": "Prayer Mat",          "price": 90,  "image": "images/items/carpet_prayer.jpg", "qty": 0, "category": "Standard"},
    {"name": "Door Mat",            "price": 60,  "image": "images/items/carpet_door.jpg",   "qty": 0, "category": "Standard"},
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
      Navigator.pop(context, {"serviceName": "Carpet Cleaning", "items": sel});
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderSummaryPage(serviceName: "Carpet Cleaning", selectedItems: sel)));
    }
  }

  @override
  Widget build(BuildContext context) => ServicePageScaffold(
    serviceName: "Carpet Cleaning",
    serviceIcon: Icons.cleaning_services_rounded,
    serviceColor: const Color(0xFF059669),
    items: items,
    totalItems: totalItems,
    totalAmount: totalAmount,
    onCheckout: _checkout,
    onIncrement: _inc,
    onDecrement: _dec,
    cartAnimController: _cartAnim,
  );
}
