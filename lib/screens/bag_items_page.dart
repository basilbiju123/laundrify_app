import '../widgets/item_image.dart';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'order_summary_page.dart';

class BagCleaningPage extends StatefulWidget {
  final bool fromSummary;
  const BagCleaningPage({super.key, this.fromSummary = false});

  @override
  State<BagCleaningPage> createState() => _BagCleaningPageState();
}

class _BagCleaningPageState extends State<BagCleaningPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _cartAnimController;

  final List<Map<String, dynamic>> items = [
    {
      "name": "School Bag",
      "price": 80,
      "image": "assets/images/items/bag_school.jpg",
      "qty": 0,
    },
    {
      "name": "College Bag",
      "price": 100,
      "image": "assets/images/items/bag_college.jpg",
      "qty": 0,
    },
    {
      "name": "Office Bag",
      "price": 120,
      "image": "assets/images/items/bag_office.jpg",
      "qty": 0,
    },
    {
      "name": "Ladies Hand Bag",
      "price": 150,
      "image": "assets/images/items/bag_hand.jpg",
      "qty": 0,
    },
    {
      "name": "Travel Bag",
      "price": 200,
      "image": "assets/images/items/bag_travel.jpg",
      "qty": 0,
    },
    {
      "name": "Laptop Bag",
      "price": 140,
      "image": "assets/images/items/bag_laptop.jpg",
      "qty": 0,
    },
    {
      "name": "Leather Bag",
      "price": 220,
      "image": "assets/images/items/bag_leather.jpg",
      "qty": 0,
    },
  ];

  int get totalItems =>
      items.fold(0, (sum, item) => sum + (item["qty"] as int));

  double get totalAmount =>
      items.fold(0.0, (sum, item) => sum + (item["qty"] * item["price"]));

  @override
  void initState() {
    super.initState();
    _cartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _cartAnimController.dispose();
    super.dispose();
  }

  void _incrementItem(int index) {
    setState(() {
      items[index]["qty"]++;
    });
    _cartAnimController.forward().then((_) => _cartAnimController.reverse());
  }

  void _decrementItem(int index) {
    if (items[index]["qty"] > 0) {
      setState(() {
        items[index]["qty"]--;
      });
    }
  }

  void _proceedToCheckout() {
    final selectedItems = items
        .where((item) => item["qty"] > 0)
        .map((item) => {
              "name": item["name"],
              "price": item["price"],
              "qty": item["qty"],
              "image": item["image"],
            })
        .toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.fromSummary) {
      Navigator.pop(context, {
        'serviceName': 'Bag Clean',
        'items': selectedItems,
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSummaryPage(
            serviceName: "Bag Clean",
            selectedItems: selectedItems,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBlue,

      // ---------------- APP BAR ----------------
      appBar: AppBar(
        title: const Text(
          "Bag Cleaning",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Cart icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, size: 26),
                onPressed: () {
                  if (totalItems > 0) {
                    _proceedToCheckout();
                  }
                },
              ),
              if (totalItems > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                      CurvedAnimation(
                        parent: _cartAnimController,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryBlue, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        totalItems > 9 ? '9+' : '$totalItems',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ---------------- BODY ----------------
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final bool hasItems = item["qty"] > 0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasItems ? primaryBlue : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasItems
                      ? primaryBlue.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: hasItems ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _incrementItem(index),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // IMAGE
                      Hero(
                        tag: 'item_${item["name"]}',
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                lightBlue,
                                lightBlue.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ItemImage(
                            assetPath: item["image"],
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // NAME + PRICE
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item["name"],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "₹${item["price"]}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "per bag",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            if (hasItems) ...[
                              const SizedBox(height: 6),
                              Text(
                                "Total: ₹${item["qty"] * item["price"]}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // QUANTITY CONTROLS
                      hasItems
                          ? Container(
                              decoration: BoxDecoration(
                                color: lightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  _qtyButton(
                                    icon: Icons.remove,
                                    onTap: () => _decrementItem(index),
                                  ),
                                  Container(
                                    constraints:
                                        const BoxConstraints(minWidth: 32),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Text(
                                      item["qty"].toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textDark,
                                      ),
                                    ),
                                  ),
                                  _qtyButton(
                                    icon: Icons.add,
                                    onTap: () => _incrementItem(index),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "ADD",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),

      // ---------------- BOTTOM BAR ----------------
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: totalItems > 0 ? 140 : 0,
        child: totalItems > 0
            ? Container(
                decoration: BoxDecoration(
                  color: cardWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Order Summary
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$totalItems ${totalItems == 1 ? 'Item' : 'Items'}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "₹${totalAmount.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _proceedToCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "PROCEED TO CHECKOUT",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  // ---------------- HELPERS ----------------

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: primaryBlue,
        ),
      ),
    );
  }
}
