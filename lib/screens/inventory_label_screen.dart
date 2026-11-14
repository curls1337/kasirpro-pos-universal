import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/pos_models.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/barcode_scanner_sheet.dart';
import '../widgets/product_image_widget.dart';

/// Layar Inventaris: Tab Produk CRUD, Tab Stock Opname / Mutasi, Tab Cetak Label Barcode Thermal
class InventoryLabelScreen extends StatefulWidget {
  final PosController controller;

  const InventoryLabelScreen({super.key, required this.controller});

  @override
  State<InventoryLabelScreen> createState() => _InventoryLabelScreenState();
}

class _InventoryLabelScreenState extends State<InventoryLabelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String _search = '';
  String _stockFilter = 'all'; // 'all' | 'low' | 'empty'

  // Label print state
  String _labelSize = '40x30'; // '30x20' | '40x30' | '50x30' | '58x40'
  final Map<int, int> _labelCopies = {};

  PosController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<ProductItem> get _filteredProducts {
    final q = _search.trim().toLowerCase();
    return ctrl.products.where((p) {
      if (_stockFilter == 'low' &&
          !(p.trackStock && p.stockQty > 0 && p.stockQty <= p.minStock)) {
        return false;
      }
      if (_stockFilter == 'empty' && !(p.trackStock && p.stockQty <= 0)) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          (p.sku ?? '').toLowerCase().contains(q) ||
          (p.barcode ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openCategoryDialog() async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kelola Kategori'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nama Kategori Baru'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      await ctrl.saveCategory(
                        CategoryItem(
                          name: nameCtrl.text.trim(),
                          createdAt: DateTime.now().toUtc().toIso8601String(),
                        ),
                      );
                      nameCtrl.clear();
                    },
                    child: const Text('Tambah'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (ctrl.categories.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: ctrl.categories.length,
                    itemBuilder: (_, i) {
                      final c = ctrl.categories[i];
                      return ListTile(
                        dense: true,
                        title: Text(c.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () =>
                              c.id != null ? ctrl.deleteCategory(c.id!) : null,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductForm({ProductItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final sellCtrl =
        TextEditingController(text: existing?.sellPrice.toString() ?? '');
    final costCtrl =
        TextEditingController(text: existing?.costPrice.toString() ?? '0');
    final stockCtrl =
        TextEditingController(text: existing?.stockQty.toString() ?? '0');
    final minStockCtrl =
        TextEditingController(text: existing?.minStock.toString() ?? '5');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'pcs');
    final imageUrlCtrl =
        TextEditingController(text: existing?.imageUrl ?? '');
    int? catId = existing?.categoryId;
    String itemType = existing?.itemType ?? 'goods';
    bool trackStock = existing?.trackStock ?? true;
    bool isLookingUp = false;

    Future<String> saveProductImagePermanently({
      File? sourceFile,
      Uint8List? bytes,
      required String originalName,
    }) async {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      var ext = path.extension(originalName).toLowerCase();
      if (ext.isEmpty) ext = '.jpg';
      final destPath = path.join(
        imagesDir.path,
        'prod_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      if (sourceFile != null) {
        await sourceFile.copy(destPath);
      } else if (bytes != null) {
        await File(destPath).writeAsBytes(bytes, flush: true);
      }
      return destPath;
    }

    Future<void> pickImageFromSource(
      BuildContext modalCtx,
      StateSetter setModalState,
      ImageSource source,
    ) async {
      try {
        final picked = await ImagePicker().pickImage(
          source: source,
          maxWidth: 900,
          imageQuality: 85,
        );
        if (picked == null) return;
        final savedPath = await saveProductImagePermanently(
          sourceFile: File(picked.path),
          originalName: picked.path,
        );
        if (!modalCtx.mounted) return;
        setModalState(() {
          imageUrlCtrl.text = savedPath;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    }

    Future<void> pickImageFromFile(
      BuildContext modalCtx,
      StateSetter setModalState,
    ) async {
      try {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (res == null || res.files.isEmpty) return;
        final file = res.files.single;
        final filePath = file.path;
        final savedPath = await saveProductImagePermanently(
          sourceFile: (filePath != null && filePath.isNotEmpty)
              ? File(filePath)
              : null,
          bytes: file.bytes,
          originalName: filePath ?? file.name,
        );
        if (!modalCtx.mounted) return;
        setModalState(() {
          imageUrlCtrl.text = savedPath;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih file gambar: $e')),
        );
      }
    }

    Future<void> runBarcodeLookup(
      BuildContext modalCtx,
      StateSetter setModalState,
      String rawCode,
    ) async {
      final code = rawCode.trim();
      if (code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Masukkan atau scan kode barcode terlebih dahulu'),
          ),
        );
        return;
      }
      setModalState(() => isLookingUp = true);
      try {
        final result = await ctrl.lookupProductByBarcode(code);
        if (!modalCtx.mounted) return;
        if (result == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data produk untuk barcode "$code" tidak ditemukan'),
            ),
          );
          return;
        }
        setModalState(() {
          if (result.name.isNotEmpty) {
            nameCtrl.text = result.name;
          }
          if (result.imageUrl.isNotEmpty) {
            imageUrlCtrl.text = result.imageUrl;
          }
          if (result.unit.isNotEmpty) {
            unitCtrl.text = result.unit;
          }
          if (result.estimatedPrice > 0 && sellCtrl.text.trim().isEmpty) {
            sellCtrl.text = result.estimatedPrice.toString();
          }
          if (result.category.isNotEmpty && catId == null) {
            final target = result.category.toLowerCase();
            for (final c in ctrl.categories) {
              final cname = c.name.toLowerCase();
              if (cname == target ||
                  cname.contains(target) ||
                  target.contains(cname)) {
                catId = c.id;
                break;
              }
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data produk diisi dari ${result.source == 'server' ? 'Server Gateway' : 'OpenFoodFacts'}',
            ),
          ),
        );
      } finally {
        if (modalCtx.mounted) {
          setModalState(() => isLookingUp = false);
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? 'Tambah Produk Baru' : 'Edit Produk',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Produk *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: catId,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Kategori'),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('Tanpa Kategori')),
                          ...ctrl.categories.map(
                            (c) => DropdownMenuItem<int?>(
                                value: c.id, child: Text(c.name)),
                          ),
                        ],
                        onChanged: (v) => setModalState(() => catId = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: itemType,
                        decoration: const InputDecoration(labelText: 'Tipe'),
                        items: const [
                          DropdownMenuItem(
                              value: 'goods', child: Text('Barang')),
                          DropdownMenuItem(
                              value: 'fnb_menu', child: Text('Menu F&B')),
                          DropdownMenuItem(
                              value: 'service', child: Text('Jasa')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() {
                              itemType = v;
                              if (v == 'service') trackStock = false;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: skuCtrl,
                        decoration: const InputDecoration(labelText: 'SKU'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: barcodeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Barcode',
                          suffixIcon: IconButton(
                            tooltip: 'Scan Barcode Kamera',
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            onPressed: () async {
                              final scanned =
                                  await BarcodeScannerSheet.show(ctx);
                              if (scanned != null) {
                                barcodeCtrl.text = scanned;
                                if (ctx.mounted) {
                                  await runBarcodeLookup(
                                    ctx,
                                    setModalState,
                                    scanned,
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: isLookingUp
                        ? null
                        : () => runBarcodeLookup(
                              ctx,
                              setModalState,
                              barcodeCtrl.text,
                            ),
                    icon: isLookingUp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined, size: 18),
                    label: Text(
                      isLookingUp ? 'Mencari Data...' : 'Auto-Isi dari Server',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: imageUrlCtrl,
                  onChanged: (_) => setModalState(() {}),
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'URL / Path Gambar Produk (Opsional)',
                    prefixIcon: const Icon(Icons.image_outlined),
                    suffixIcon: imageUrlCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () =>
                                setModalState(() => imageUrlCtrl.clear()),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                        ),
                        onPressed: () => pickImageFromSource(
                          ctx,
                          setModalState,
                          ImageSource.camera,
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('📷 Kamera'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                        ),
                        onPressed: () => pickImageFromSource(
                          ctx,
                          setModalState,
                          ImageSource.gallery,
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('🖼️ Galeri'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                        ),
                        onPressed: () => pickImageFromFile(ctx, setModalState),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('📁 File'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (imageUrlCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ProductImageWidget(
                        imageUrl: imageUrlCtrl.text.trim(),
                        itemType: itemType,
                        width: 64,
                        height: 64,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Preview Gambar Produk',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              ProductImageWidget.isRemoteUrl(imageUrlCtrl.text)
                                  ? 'Sumber: URL Eksternal'
                                  : 'Sumber: File Lokal Perangkat',
                              style: TextStyle(
                                fontSize: 11,
                                color: ctx.posColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                            labelText: 'Harga Modal / HPP (${ctrl.currencySymbol})'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: sellCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                            labelText: 'Harga Jual (${ctrl.currencySymbol}) *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lacak Stok Inventaris'),
                  value: trackStock,
                  onChanged: (v) => setModalState(() => trackStock = v),
                ),
                if (trackStock)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Stok Saat Ini'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: minStockCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Min. Stok'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unitCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Satuan'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final now = DateTime.now().toUtc().toIso8601String();
                    await ctrl.saveProduct(
                      ProductItem(
                        id: existing?.id,
                        categoryId: catId,
                        sku: skuCtrl.text.trim().isEmpty
                            ? null
                            : skuCtrl.text.trim(),
                        barcode: barcodeCtrl.text.trim().isEmpty
                            ? null
                            : barcodeCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        itemType: itemType,
                        sellPrice: int.tryParse(sellCtrl.text) ?? 0,
                        costPrice: int.tryParse(costCtrl.text) ?? 0,
                        stockQty: double.tryParse(stockCtrl.text) ?? 0,
                        minStock: double.tryParse(minStockCtrl.text) ?? 5,
                        unit: unitCtrl.text.trim().isEmpty
                            ? 'pcs'
                            : unitCtrl.text.trim(),
                        imageUrl: imageUrlCtrl.text.trim(),
                        trackStock: trackStock,
                        isActive: existing?.isActive ?? true,
                        createdAt: existing?.createdAt ?? now,
                        updatedAt: now,
                      ),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Simpan Produk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStockOpnameDialog(ProductItem product) async {
    String moveType = 'opname';
    final qtyCtrl = TextEditingController(text: product.stockQty.toString());
    final notesCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Penyesuaian Stok: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: moveType,
                decoration: const InputDecoration(labelText: 'Jenis Mutasi'),
                items: const [
                  DropdownMenuItem(
                      value: 'opname', child: Text('Opname (Set Fisik Baru)')),
                  DropdownMenuItem(
                      value: 'in', child: Text('Stok Masuk (+ Tambah)')),
                  DropdownMenuItem(
                      value: 'out', child: Text('Stok Keluar / Rusak (- Kurang)')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => moveType = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: moveType == 'opname'
                      ? 'Stok Fisik Aktual (${product.unit})'
                      : 'Jumlah (${product.unit})',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Alasan / Catatan'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final val = double.tryParse(qtyCtrl.text) ?? 0;
                await ctrl.adjustStock(
                  product: product,
                  movementType: moveType,
                  qtyInput: val,
                  notes: notesCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Simpan Mutasi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ctrl.canAccess('inventory_edit');
    final colors = context.posColors;

    return Column(
      children: [
        Container(
          color: colors.surfacePrimary,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Inventaris & Label Barcode',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (canEdit) ...[
                    OutlinedButton.icon(
                      onPressed: _openCategoryDialog,
                      icon: const Icon(Icons.category_outlined, size: 18),
                      label: const Text('Kategori'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _openProductForm(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Produk'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Katalog Produk'),
                  Tab(text: 'Opname & Mutasi'),
                  Tab(text: 'Cetak Label Barcode'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildProductsTab(colors, canEdit),
              _buildMovementsTab(colors, canEdit),
              _buildLabelPrintTab(colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTab(PosColors colors, bool canEdit) {
    final list = _filteredProducts;
    final sym = ctrl.currencySymbol;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Cari produk, SKU, barcode...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _stockFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Semua')),
                  DropdownMenuItem(value: 'low', child: Text('Menipis')),
                  DropdownMenuItem(value: 'empty', child: Text('Habis')),
                ],
                onChanged: (v) => setState(() => _stockFilter = v ?? 'all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Belum ada produk terdaftar.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final low = p.trackStock && p.stockQty <= p.minStock;
                    return Card(
                      child: ListTile(
                        leading: _buildProductThumbnail(p, colors, size: 48),
                        title: Text(p.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          'SKU: ${p.sku ?? "-"} • Barcode: ${p.barcode ?? "-"}\nHPP: ${PosFormatters.currency(p.costPrice, symbol: sym)} • Jual: ${PosFormatters.currency(p.sellPrice, symbol: sym)}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p.trackStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (low
                                          ? colors.statusWarning
                                          : colors.statusSuccess)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${PosFormatters.number(p.stockQty)} ${p.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: low
                                        ? colors.statusWarning
                                        : colors.statusSuccess,
                                  ),
                                ),
                              ),
                            if (canEdit)
                              PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _openProductForm(existing: p);
                                  } else if (action == 'opname') {
                                    _openStockOpnameDialog(p);
                                  } else if (action == 'delete' &&
                                      p.id != null) {
                                    ctrl.deleteProduct(p.id!);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'opname',
                                      child: Text('Opname / Mutasi Stok')),
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Edit Produk')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Hapus')),
                                ],
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

  Widget _buildProductThumbnail(
    ProductItem p,
    PosColors colors, {
    double size = 48,
  }) {
    return ProductImageWidget(
      imageUrl: p.imageUrl,
      itemType: p.itemType,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(10),
      iconSize: size * 0.5,
      backgroundColor: colors.surfaceElevated,
      iconColor: colors.textMuted,
    );
  }

  Widget _buildMovementsTab(PosColors colors, bool canEdit) {
    if (ctrl.stockMovements.isEmpty) {
      return const Center(child: Text('Belum ada riwayat mutasi stok.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: ctrl.stockMovements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final m = ctrl.stockMovements[i];
        final isPlus = m.qtyDelta >= 0;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  (isPlus ? colors.statusSuccess : colors.statusDanger)
                      .withValues(alpha: 0.12),
              child: Icon(
                isPlus ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: isPlus ? colors.statusSuccess : colors.statusDanger,
              ),
            ),
            title: Text(
              'Produk #${m.productId} • ${m.movementType.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${PosFormatters.dateTime(m.createdAt)} • ${m.notes.isEmpty ? "-" : m.notes}\nStok: ${PosFormatters.number(m.stockBefore)} → ${PosFormatters.number(m.stockAfter)}',
            ),
            isThreeLine: true,
            trailing: Text(
              '${isPlus ? "+" : ""}${PosFormatters.number(m.qtyDelta)}',
              style: AppTheme.tabular(
                null,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isPlus ? colors.statusSuccess : colors.statusDanger,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabelPrintTab(PosColors colors) {
    final sym = ctrl.currencySymbol;
    final selectedProducts = ctrl.products
        .where((p) => p.id != null && (_labelCopies[p.id!] ?? 0) > 0)
        .toList();
    final previewProduct = selectedProducts.isNotEmpty
        ? selectedProducts.first
        : (ctrl.products.isNotEmpty ? ctrl.products.first : null);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ukuran Stiker Label Thermal',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['30x20', '40x30', '50x30', '58x40'].map((sz) {
                    return ChoiceChip(
                      label: Text('$sz mm'),
                      selected: _labelSize == sz,
                      onSelected: (_) => setState(() => _labelSize = sz),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                if (previewProduct != null)
                  Center(
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black54),
                      ),
                      child: Column(
                        children: [
                          Text(
                            ctrl.store?.name ?? 'TOKO',
                            style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            previewProduct.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 36,
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: Text(
                              previewProduct.barcode ??
                                  previewProduct.sku ??
                                  '123456789012',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            PosFormatters.currency(previewProduct.sellPrice,
                                symbol: sym),
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...ctrl.products.where((p) => p.id != null).map((p) {
          final qty = _labelCopies[p.id!] ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${p.barcode ?? p.sku ?? "-"} • ${PosFormatters.currency(p.sellPrice, symbol: sym)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: qty > 0
                        ? () => setState(() => _labelCopies[p.id!] = qty - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$qty',
                      style: AppTheme.tabular(null,
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: () =>
                        setState(() => _labelCopies[p.id!] = qty + 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: selectedProducts.isEmpty
                ? null
                : () async {
                    final msg = await ctrl.printProductLabels(
                      products: selectedProducts,
                      copiesPerProduct: _labelCopies,
                      labelSize: _labelSize,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
            icon: const Icon(Icons.print_rounded),
            label: Text(
              'Cetak Massal (${selectedProducts.fold<int>(0, (s, p) => s + (_labelCopies[p.id!] ?? 0))} Label)',
            ),
          ),
        ),
      ],
    );
  }
}
