import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pos_models.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/barcode_scanner_sheet.dart';
import '../widgets/tender_payment_sheet.dart';

/// Layar Kasir Universal: Split-View (Tablet >=720dp) & Katalog + Sticky Cart Bar (HP <720dp)
class PosCashierScreen extends StatefulWidget {
  final PosController controller;

  const PosCashierScreen({super.key, required this.controller});

  @override
  State<PosCashierScreen> createState() => _PosCashierScreenState();
}

class _PosCashierScreenState extends State<PosCashierScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  int? _selectedCategoryId;
  String _searchQuery = '';

  PosController get ctrl => widget.controller;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProductItem> get _filteredProducts {
    final q = _searchQuery.trim().toLowerCase();
    return ctrl.products.where((p) {
      if (!p.isActive) return false;
      if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          (p.sku ?? '').toLowerCase().contains(q) ||
          (p.barcode ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _handleScanBarcode() async {
    final code = await BarcodeScannerSheet.show(context);
    if (code == null || !mounted) return;
    final found = ctrl.findProductByBarcodeOrSku(code);
    if (found != null) {
      ctrl.addToCart(found);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ditambahkan: ${found.name}')),
      );
    } else {
      setState(() {
        _searchQuery = code;
        _searchCtrl.text = code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barcode "$code" tidak ditemukan di katalog')),
      );
    }
  }

  void _handleSearchSubmit(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;
    final exact = ctrl.findProductByBarcodeOrSku(code);
    if (exact != null) {
      ctrl.addToCart(exact);
      _searchCtrl.clear();
      setState(() => _searchQuery = '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('+1 ${exact.name}')),
      );
    }
  }

  void _openManualItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Item Manual / Jasa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Item / Layanan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Harga (${ctrl.currencySymbol})',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = int.tryParse(priceCtrl.text) ?? 0;
              if (name.isEmpty || price <= 0) return;
              final now = DateTime.now().toUtc().toIso8601String();
              ctrl.addToCart(
                ProductItem(
                  name: name,
                  itemType: 'service',
                  sellPrice: price,
                  costPrice: 0,
                  trackStock: false,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Tambahkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openHoldCartDialog() async {
    if (ctrl.cart.isEmpty) return;
    final labelCtrl = TextEditingController(
      text: ctrl.tableNumber.isNotEmpty
          ? 'Meja ${ctrl.tableNumber}'
          : 'Parkir #${ctrl.heldCarts.length + 1}',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan / Parkir Pesanan'),
        content: TextField(
          controller: labelCtrl,
          decoration: const InputDecoration(
            labelText: 'Label Pesanan / Nomor Meja',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              await ctrl.holdCurrentCart(labelCtrl.text);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Simpan Parkir'),
          ),
        ],
      ),
    );
  }

  void _openHeldCartsSheet() {
    final sym = ctrl.currencySymbol;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pesanan Tertunda (Hold / Open Table)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (ctrl.heldCarts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Belum ada pesanan yang diparkir.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: ctrl.heldCarts.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final h = ctrl.heldCarts[i];
                      return ListTile(
                        title: Text(h.cartLabel,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${h.orderType.toUpperCase()} • ${PosFormatters.time(h.createdAt)}${h.discountAmount > 0 ? " • Diskon ${PosFormatters.currency(h.discountAmount, symbol: sym)}" : ""}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (h.id != null) {
                                  await ctrl.deleteHeldCart(h.id!);
                                }
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                await ctrl.resumeHeldCart(h);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                              child: const Text('Buka'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDiscountDialog() {
    final discCtrl = TextEditingController(
      text: ctrl.cartDiscountAmount > 0 ? ctrl.cartDiscountAmount.toString() : '',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diskon Transaksi'),
        content: TextField(
          controller: discCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Nominal Diskon (${ctrl.currencySymbol})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctrl.setCartDiscount(0);
              Navigator.of(ctx).pop();
            },
            child: const Text('Reset'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(discCtrl.text) ?? 0;
              ctrl.setCartDiscount(val);
              Navigator.of(ctx).pop();
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  void _openItemNotesDialog(int index, CartItem item) {
    final noteCtrl = TextEditingController(text: item.itemNotes);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Catatan: ${item.productName}'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Contoh: Tidak pedas, es sedikit, bungkus terpisah',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              ctrl.updateCartItemNotes(index, noteCtrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCheckout() async {
    if (ctrl.cart.isEmpty) return;
    if (ctrl.activeShift == null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Shift Belum Dibuka'),
          content: const Text(
            'Disarankan membuka Shift Kasir terlebih dahulu agar arus uang laci kas tercatat. Tetap lanjutkan pembayaran?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Lanjut Bayar'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    await TenderPaymentSheet.show(context, ctrl);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final colors = context.posColors;

    if (isTablet) {
      return Row(
        children: [
          Expanded(flex: 62, child: _buildCatalogPane(colors, isTablet)),
          const VerticalDivider(width: 1),
          SizedBox(width: 370, child: _buildCartPane(colors)),
        ],
      );
    }

    // Mobile (< 720dp): Katalog penuh + Sticky Floating Cart Bar
    return Stack(
      children: [
        _buildCatalogPane(colors, false),
        if (ctrl.cart.isNotEmpty)
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: _buildStickyMobileCartBar(colors),
          ),
      ],
    );
  }

  Widget _buildCatalogPane(PosColors colors, bool isTablet) {
    final items = _filteredProducts;
    final sym = ctrl.currencySymbol;

    return Column(
      children: [
        Container(
          color: colors.surfacePrimary,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      onSubmitted: _handleSearchSubmit,
                      decoration: InputDecoration(
                        hintText: 'Cari nama, SKU, atau scan barcode...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: _handleScanBarcode,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: IconButton.outlined(
                      tooltip: 'Tambah Item Manual / Jasa',
                      onPressed: _openManualItemDialog,
                      icon: const Icon(Icons.add_box_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Semua'),
                        selected: _selectedCategoryId == null,
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = null),
                      ),
                    ),
                    ...ctrl.categories.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: _selectedCategoryId == cat.id,
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = cat.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: colors.textMuted),
                        const SizedBox(height: 10),
                        const Text(
                          'Belum ada produk yang sesuai',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tambahkan produk di menu Stok & Label atau gunakan tombol Item Manual.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    (!isTablet && ctrl.cart.isNotEmpty) ? 88 : 20,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: isTablet ? 0.96 : 0.88,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, idx) {
                    final p = items[idx];
                    final lowStock =
                        p.trackStock && p.stockQty <= p.minStock;
                    final outOfStock = p.trackStock && p.stockQty <= 0;

                    return InkWell(
                      onTap: () => ctrl.addToCart(p),
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    p.sku?.isNotEmpty == true
                                        ? p.sku!
                                        : p.itemType.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (p.trackStock)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (outOfStock
                                              ? colors.statusDanger
                                              : (lowStock
                                                  ? colors.statusWarning
                                                  : colors.statusSuccess))
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      outOfStock
                                          ? 'Habis'
                                          : '${PosFormatters.number(p.stockQty)} ${p.unit}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: outOfStock
                                            ? colors.statusDanger
                                            : (lowStock
                                                ? colors.statusWarning
                                                : colors.statusSuccess),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildCatalogThumbnail(p, colors),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Text(
                              PosFormatters.currency(p.sellPrice, symbol: sym),
                              style: AppTheme.tabular(
                                null,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: colors.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCatalogThumbnail(ProductItem p, PosColors colors) {
    Widget fallback() {
      final iconData = p.itemType == 'fnb_menu'
          ? Icons.restaurant_rounded
          : (p.itemType == 'service'
              ? Icons.design_services_rounded
              : Icons.inventory_2_rounded);
      return Container(
        color: colors.surfaceElevated,
        alignment: Alignment.center,
        child: Icon(iconData, size: 28, color: colors.textMuted),
      );
    }

    final url = p.imageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 62,
        width: double.infinity,
        child: url.isEmpty
            ? fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback(),
              ),
      ),
    );
  }

  Widget _buildStickyMobileCartBar(PosColors colors) {
    final sym = ctrl.currencySymbol;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: colors.brandPrimary,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.88,
              child: _buildCartPane(colors, inSheet: true),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${PosFormatters.number(ctrl.cartTotalItems)} Item • ${PosFormatters.currency(ctrl.cartGrandTotal, symbol: sym)}',
                  style: AppTheme.tabular(
                    null,
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Text(
                'Keranjang →',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartPane(PosColors colors, {bool inSheet = false}) {
    final sym = ctrl.currencySymbol;

    return Container(
      color: colors.surfacePrimary,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Keranjang Aktif',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Pesanan Parkir (${ctrl.heldCarts.length})',
                  onPressed: _openHeldCartsSheet,
                  icon: Badge(
                    isLabelVisible: ctrl.heldCarts.isNotEmpty,
                    label: Text('${ctrl.heldCarts.length}'),
                    child: const Icon(Icons.pause_circle_outline_rounded),
                  ),
                ),
                IconButton(
                  tooltip: 'Parkir Pesanan Ini',
                  onPressed: ctrl.cart.isEmpty ? null : _openHoldCartDialog,
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
                IconButton(
                  tooltip: 'Kosongkan Keranjang',
                  onPressed: ctrl.cart.isEmpty ? null : ctrl.clearCart,
                  icon: Icon(Icons.delete_outline_rounded,
                      color: colors.statusDanger),
                ),
                if (inSheet)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          // Tipe Order & Pelanggan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: ctrl.orderType,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipe Order',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'retail', child: Text('Retail')),
                      DropdownMenuItem(
                          value: 'dine_in', child: Text('Dine-In')),
                      DropdownMenuItem(
                          value: 'takeaway', child: Text('Takeaway')),
                      DropdownMenuItem(value: 'service', child: Text('Jasa')),
                    ],
                    onChanged: (v) {
                      if (v != null) ctrl.setOrderType(v);
                    },
                  ),
                ),
                if (ctrl.orderType == 'dine_in') ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue: ctrl.tableNumber,
                      onChanged: ctrl.setTableNumber,
                      decoration: const InputDecoration(
                        labelText: 'Meja',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonFormField<int?>(
              value: ctrl.selectedCustomer?.id,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pelanggan (Opsional / Wajib Kasbon)',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Pelanggan Umum (Walk-in)'),
                ),
                ...ctrl.customers.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (cid) {
                if (cid == null) {
                  ctrl.setSelectedCustomer(null);
                } else {
                  final match = ctrl.customers.firstWhere((c) => c.id == cid);
                  ctrl.setSelectedCustomer(match);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ctrl.cart.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 46, color: colors.textMuted),
                          const SizedBox(height: 10),
                          Text(
                            'Keranjang kosong',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ketuk produk atau scan barcode untuk memulai transaksi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: ctrl.cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 14),
                    itemBuilder: (_, idx) {
                      final item = ctrl.cart[idx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      PosFormatters.currency(
                                          item.unitPrice,
                                          symbol: sym),
                                      style: AppTheme.tabular(
                                        null,
                                        fontSize: 12,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                PosFormatters.currency(item.subtotal,
                                    symbol: sym),
                                style: AppTheme.tabular(
                                  null,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              InkWell(
                                onTap: () => _openItemNotesDialog(idx, item),
                                child: Text(
                                  item.itemNotes.isEmpty
                                      ? '+ Catatan'
                                      : '📝 ${item.itemNotes}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.brandPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    ctrl.updateCartItemQty(idx, item.qty - 1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                PosFormatters.number(item.qty),
                                style: AppTheme.tabular(
                                  null,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    ctrl.updateCartItemQty(idx, item.qty + 1),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _totalRow('Subtotal',
                    PosFormatters.currency(ctrl.cartSubtotal, symbol: sym)),
                InkWell(
                  onTap: ctrl.cart.isEmpty ? null : _openDiscountDialog,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _totalRow(
                      'Diskon (ketuk ubah)',
                      '- ${PosFormatters.currency(ctrl.cartDiscountAmount, symbol: sym)}',
                      color: colors.statusWarning,
                    ),
                  ),
                ),
                if (ctrl.cartServiceCharge > 0)
                  _totalRow(
                    'Service (${ctrl.store?.serviceChargePercent ?? 0}%)',
                    PosFormatters.currency(ctrl.cartServiceCharge, symbol: sym),
                  ),
                if (ctrl.cartTaxAmount > 0)
                  _totalRow(
                    'Pajak (${ctrl.store?.taxPercent ?? 0}%)',
                    PosFormatters.currency(ctrl.cartTaxAmount, symbol: sym),
                  ),
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(
                      PosFormatters.currency(ctrl.cartGrandTotal, symbol: sym),
                      style: AppTheme.tabular(
                        null,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: ctrl.cart.isEmpty
                        ? null
                        : () {
                            if (inSheet) Navigator.of(context).pop();
                            _openCheckout();
                          },
                    icon: const Icon(Icons.payments_rounded),
                    label: Text(
                      'BAYAR • ${PosFormatters.currency(ctrl.cartGrandTotal, symbol: sym)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: color)),
        Text(
          value,
          style: AppTheme.tabular(null,
              fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
