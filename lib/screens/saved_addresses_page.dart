import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

// ═══════════════════════════════════════════════════════════
// SAVED ADDRESSES PAGE
// Multiple addresses with nicknames, types, default selection
// ═══════════════════════════════════════════════════════════

const _navy = Color(0xFF080F1E);
const _blue = Color(0xFF1B4FD8);
const _blueSoft = Color(0xFF3B82F6);
const _green = Color(0xFF10B981);
const _gold = Color(0xFFF5C518);
const _rose = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);
const _violet = Color(0xFF8B5CF6);

class SavedAddressesPage extends StatelessWidget {
  const SavedAddressesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(child: Text('Saved Addresses', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white))),
                GestureDetector(
                  onTap: () => _showAddAddressSheet(context, firestore),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_blue, _blueSoft]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // ADDRESS LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firestore.getSavedAddressesStream(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _blueSoft, strokeWidth: 2));
                  }

                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.location_off_rounded, color: Color(0xFF475569), size: 64),
                        const SizedBox(height: 16),
                        const Text('No saved addresses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 8),
                        const Text('Add an address for faster checkout', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () => _showAddAddressSheet(ctx, firestore),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_blue, _blueSoft]), borderRadius: BorderRadius.circular(14)),
                            child: const Text('+ Add First Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                      ]),
                    );
                  }

                  final docs = snap.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (_, i) => _AddressCard(
                      doc: docs[i],
                      onSetDefault: () => firestore.setDefaultAddress(docs[i].id),
                      onDelete: () => _confirmDelete(context, docs[i].id, firestore),
                    ),
                  );
                },
              ),
            ),

            // ADD BUTTON
            Padding(
              padding: const EdgeInsets.all(20),
              child: GestureDetector(
                onTap: () => _showAddAddressSheet(context, firestore),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_blue, _blueSoft]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 6))],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Add New Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, String addressId, FirestoreService firestore) {
    final t = AppColors.of(ctx);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to remove this address?', style: TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _rose, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async { Navigator.pop(ctx); await firestore.deleteAddress(addressId); },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showAddAddressSheet(BuildContext ctx, FirestoreService firestore) {
    final t = AppColors.of(ctx);
    final nicknameCtrl = TextEditingController();
    final houseCtrl = TextEditingController();
    final fullAddrCtrl = TextEditingController();
    String selectedType = 'Home';
    bool isDefault = false;
    bool isLoading = false;

    final addressTypes = [
      {'type': 'Home', 'icon': Icons.home_rounded, 'color': _blue},
      {'type': 'Office', 'icon': Icons.business_rounded, 'color': _violet},
      {'type': 'Hostel', 'icon': Icons.apartment_rounded, 'color': _amber},
      {'type': 'Other', 'icon': Icons.location_on_rounded, 'color': _green},
    ];

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const Text('Add New Address', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 20),

                // ADDRESS TYPE SELECTOR
                Row(
                  children: addressTypes.map((t) {
                    final active = selectedType == t['type'];
                    final color = t['color'] as Color;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () { setLocal(() { selectedType = t['type'] as String; nicknameCtrl.text = t['type'] as String; }); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: active ? color.withValues(alpha: 0.2) : _navy,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: active ? color : Colors.white.withValues(alpha: 0.1), width: active ? 1.5 : 1),
                          ),
                          child: Column(children: [
                            Icon(t['icon'] as IconData, color: active ? color : Colors.white38, size: 20),
                            const SizedBox(height: 4),
                            Text(t['type'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? color : Colors.white38)),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                _formField(nicknameCtrl, 'Nickname (Home, Office...)', Icons.label_outline_rounded),
                const SizedBox(height: 12),
                _formField(houseCtrl, 'House / Flat / Building No.', Icons.home_outlined),
                const SizedBox(height: 12),
                _formField(fullAddrCtrl, 'Full Address (Street, Area, City)', Icons.location_on_outlined, maxLines: 2),

                const SizedBox(height: 14),

                // DEFAULT TOGGLE
                GestureDetector(
                  onTap: () => setLocal(() => isDefault = !isDefault),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: isDefault ? _gold.withValues(alpha: 0.1) : _navy, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDefault ? _gold.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1))),
                    child: Row(children: [
                      Icon(isDefault ? Icons.star_rounded : Icons.star_outline_rounded, color: isDefault ? _gold : Colors.white38, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Set as default address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24, height: 24,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isDefault ? _gold : Colors.white.withValues(alpha: 0.1), border: Border.all(color: isDefault ? _gold : Colors.white.withValues(alpha: 0.3))),
                        child: isDefault ? const Icon(Icons.check_rounded, color: Colors.black, size: 14) : null,
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    onPressed: isLoading ? null : () async {
                      if (houseCtrl.text.isEmpty || fullAddrCtrl.text.isEmpty) return;
                      setLocal(() => isLoading = true);
                      await firestore.saveAddress(
                        nickname: nicknameCtrl.text.isEmpty ? selectedType : nicknameCtrl.text,
                        fullAddress: fullAddrCtrl.text.trim(),
                        houseNumber: houseCtrl.text.trim(),
                        latitude: 0, longitude: 0, // Will be populated from GPS in real flow
                        isDefault: isDefault,
                        type: selectedType,
                      );
                      if (ctx2.mounted) Navigator.pop(ctx2);
                    },
                    child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('SAVE ADDRESS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl, maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        prefixIcon: Padding(padding: EdgeInsets.only(bottom: maxLines > 1 ? 40 : 0), child: Icon(icon, color: const Color(0xFF475569), size: 18)),
        filled: true, fillColor: const Color(0xFF0A0F1E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _blueSoft, width: 2)),
      ),
    );
  }
}

// ─── ADDRESS CARD ────────────────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard({required this.doc, required this.onSetDefault, required this.onDelete});

  Color _typeColor(String type) {
    switch (type) {
      case 'Home': return _blue;
      case 'Office': return _violet;
      case 'Hostel': return _amber;
      default: return _green;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Home': return Icons.home_rounded;
      case 'Office': return Icons.business_rounded;
      case 'Hostel': return Icons.apartment_rounded;
      default: return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    final d = doc.data() as Map<String, dynamic>;
    final isDefault = d['isDefault'] ?? false;
    final type = d['type'] ?? 'Home';
    final color = _typeColor(type);
    final nick = d['nickname'] ?? type;
    final house = d['houseNumber'] ?? '';
    final full = d['fullAddress'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDefault ? _gold.withValues(alpha: 0.4) : t.cardBdr, width: isDefault ? 1.5 : 1),
        boxShadow: isDefault ? [BoxShadow(color: _gold.withValues(alpha: 0.08), blurRadius: 16, spreadRadius: 0)] : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                  child: Icon(_typeIcon(type), color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(nick, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: const Text('DEFAULT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _gold, letterSpacing: 1))),
                        ],
                      ]),
                      if (house.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(house, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                      const SizedBox(height: 3),
                      Text(full, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: t.cardBdr),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              if (!isDefault)
                Expanded(
                  child: GestureDetector(
                    onTap: onSetDefault,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(color: _gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _gold.withValues(alpha: 0.3))),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.star_outline_rounded, color: _gold, size: 14),
                        SizedBox(width: 6),
                        Text('Set Default', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _gold)),
                      ]),
                    ),
                  ),
                ),
              if (!isDefault) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(color: _rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _rose.withValues(alpha: 0.3))),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.delete_outline_rounded, color: _rose, size: 14),
                      SizedBox(width: 6),
                      Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _rose)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
