import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pos_models.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';

/// Layar CRM & Operasional: Tab Pelanggan & Kasbon, Tab Supplier & Kulakan, Tab Pengeluaran
class CrmSupplierScreen extends StatefulWidget {
  final PosController controller;

  const CrmSupplierScreen({super.key, required this.controller});

  @override
  State<CrmSupplierScreen> createState() => _CrmSupplierScreenState();
}

class _CrmSupplierScreenState extends State<CrmSupplierScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

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

  Future<void> _openCustomerDialog({CustomerItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final limitCtrl =
        TextEditingController(text: (existing?.creditLimit ?? 0).toString());

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Tambah Pelanggan' : 'Edit Pelanggan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Pelanggan *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'No. HP / WhatsApp'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText:
                      'Limit Kasbon (${ctrl.currencySymbol}, 0 = tanpa batas)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final now = DateTime.now().toUtc().toIso8601String();
              await ctrl.saveCustomer(
                CustomerItem(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  creditLimit: int.tryParse(limitCtrl.text) ?? 0,
                  totalDebt: existing?.totalDebt ?? 0,
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                ),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPayDebtDialog(CustomerItem cust) async {
    final amtCtrl = TextEditingController(text: cust.totalDebt.toString());
    final notesCtrl = TextEditingController();
    String method = 'cash';
    final sym = ctrl.currencySymbol;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Bayar Kasbon: ${cust.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sisa Kasbon: ${PosFormatters.currency(cust.totalDebt, symbol: sym)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    InputDecoration(labelText: 'Nominal Cicilan ($sym)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'Metode Bayar'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                  DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                  DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                  DropdownMenuItem(value: 'debit', child: Text('EDC / Kartu')),
                ],
                onChanged: (v) => setDialogState(() => method = v ?? 'cash'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Catatan'),
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
                final amt = int.tryParse(amtCtrl.text) ?? 0;
                if (amt <= 0) return;
                await ctrl.payCustomerDebt(
                  customer: cust,
                  amount: amt,
                  paymentMethod: method,
                  notes: notesCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Catat Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSupplierDialog({SupplierItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final contactCtrl =
        TextEditingController(text: existing?.contactPerson ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Tambah Supplier' : 'Edit Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Supplier *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Nama Kontak / PIC'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. Telepon'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ctrl.saveSupplier(
                SupplierItem(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  contactPerson: contactCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  createdAt: existing?.createdAt ??
                      DateTime.now().toUtc().toIso8601String(),
                ),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPurchaseDialog() async {
    if (ctrl.suppliers.isEmpty || ctrl.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal 1 Supplier dan 1 Produk terlebih dahulu'),
        ),
      );
      return;
    }

    SupplierItem selectedSupplier = ctrl.suppliers.first;
    ProductItem selectedProduct = ctrl.products.first;
    final qtyCtrl = TextEditingController(text: '10');
    final buyPriceCtrl =
        TextEditingController(text: selectedProduct.costPrice.toString());
    final invoiceCtrl = TextEditingController(
      text: 'PO-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
    );
    String payStatus = 'paid';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Catat Kulakan / Purchase Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: invoiceCtrl,
                  decoration: const InputDecoration(labelText: 'No. Faktur PO'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<SupplierItem>(
                  value: selectedSupplier,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: ctrl.suppliers
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedSupplier = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ProductItem>(
                  value: selectedProduct,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Produk'),
                  items: ctrl.products
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        selectedProduct = v;
                        buyPriceCtrl.text = v.costPrice.toString();
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Qty Masuk'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: buyPriceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                            labelText: 'Harga Beli (${ctrl.currencySymbol})'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: payStatus,
                  decoration:
                      const InputDecoration(labelText: 'Status Pembayaran'),
                  items: const [
                    DropdownMenuItem(value: 'paid', child: Text('Lunas')),
                    DropdownMenuItem(value: 'debt', child: Text('Tempo/Hutang')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => payStatus = v ?? 'paid'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                final buyPrice = int.tryParse(buyPriceCtrl.text) ?? 0;
                if (qty <= 0 || selectedSupplier.id == null) return;
                final subtotal = (qty * buyPrice).round();
                await ctrl.createPurchase(
                  supplierId: selectedSupplier.id!,
                  invoiceNo: invoiceCtrl.text.trim(),
                  items: [
                    PurchaseOrderItem(
                      productId: selectedProduct.id ?? 0,
                      name: selectedProduct.name,
                      qty: qty,
                      buyPrice: buyPrice,
                    ),
                  ],
                  totalAmount: subtotal,
                  paymentStatus: payStatus,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Simpan & Tambah Stok'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExpenseDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Operasional';
    String source = 'non_drawer';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Catat Pengeluaran Operasional'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nama Pengeluaran (mis. Listrik / Kemasan) *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                      labelText: 'Nominal (${ctrl.currencySymbol}) *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Operasional', child: Text('Operasional')),
                    DropdownMenuItem(value: 'Gaji', child: Text('Gaji Staff')),
                    DropdownMenuItem(
                        value: 'Utilitas', child: Text('Listrik / Air / WiFi')),
                    DropdownMenuItem(
                        value: 'Kemasan', child: Text('Kemasan / Plastik')),
                    DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? 'Operasional'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: source,
                  decoration: const InputDecoration(labelText: 'Sumber Dana'),
                  items: const [
                    DropdownMenuItem(
                        value: 'non_drawer', child: Text('Kas Luar Laci / Bank')),
                    DropdownMenuItem(
                        value: 'drawer', child: Text('Ambil dari Laci Kasir')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => source = v ?? 'non_drawer'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final amt = int.tryParse(amountCtrl.text) ?? 0;
                if (titleCtrl.text.trim().isEmpty || amt <= 0) return;
                await ctrl.addExpense(
                  category: category,
                  title: titleCtrl.text.trim(),
                  amount: amt,
                  paymentSource: source,
                  notes: notesCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Simpan Pengeluaran'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.posColors;

    return Column(
      children: [
        Container(
          color: colors.surfacePrimary,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pelanggan, Supplier & Pengeluaran',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Pelanggan & Kasbon'),
                  Tab(text: 'Supplier & Kulakan'),
                  Tab(text: 'Pengeluaran'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildCustomersTab(colors),
              _buildSuppliersTab(colors),
              _buildExpensesTab(colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersTab(PosColors colors) {
    final sym = ctrl.currencySymbol;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${ctrl.customers.length} Pelanggan',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary)),
              FilledButton.icon(
                onPressed: () => _openCustomerDialog(),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Pelanggan'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ctrl.customers.isEmpty
              ? const Center(child: Text('Belum ada data pelanggan.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: ctrl.customers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = ctrl.customers[i];
                    final hasDebt = c.totalDebt > 0;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colors.surfaceHighlight,
                          child: Text(c.name[0].toUpperCase()),
                        ),
                        title: Text(c.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${c.phone.isEmpty ? "-" : c.phone} • ${c.address.isEmpty ? "-" : c.address}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  hasDebt
                                      ? PosFormatters.currency(c.totalDebt,
                                          symbol: sym)
                                      : 'Lunas',
                                  style: AppTheme.tabular(
                                    null,
                                    fontWeight: FontWeight.w800,
                                    color: hasDebt
                                        ? colors.statusDanger
                                        : colors.statusSuccess,
                                  ),
                                ),
                                if (hasDebt)
                                  const Text('Kasbon',
                                      style: TextStyle(fontSize: 11)),
                              ],
                            ),
                            if (hasDebt) ...[
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: () => _openPayDebtDialog(c),
                                child: const Text('Cicil'),
                              ),
                            ],
                          ],
                        ),
                        onTap: () => _openCustomerDialog(existing: c),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSuppliersTab(PosColors colors) {
    final canManage = ctrl.canAccess('suppliers');
    final sym = ctrl.currencySymbol;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (canManage)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openSupplierDialog(),
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('Tambah Supplier'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openPurchaseDialog,
                  icon: const Icon(Icons.shopping_cart_checkout_rounded),
                  label: const Text('Catat Kulakan PO'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        const Text('Daftar Supplier',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (ctrl.suppliers.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada supplier terdaftar.'),
            ),
          )
        else
          ...ctrl.suppliers.map(
            (s) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(s.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    'PIC: ${s.contactPerson.isEmpty ? "-" : s.contactPerson} • ${s.phone}'),
                onTap: canManage ? () => _openSupplierDialog(existing: s) : null,
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text('Riwayat Kulakan / Purchase Order',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (ctrl.purchases.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada riwayat kulakan.'),
            ),
          )
        else
          ...ctrl.purchases.map(
            (po) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(po.invoiceNo,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${PosFormatters.dateTime(po.purchasedAt)} • ${po.paymentStatus.toUpperCase()}'),
                trailing: Text(
                  PosFormatters.currency(po.totalAmount, symbol: sym),
                  style: AppTheme.tabular(null, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpensesTab(PosColors colors) {
    final canManage = ctrl.canAccess('expenses');
    final sym = ctrl.currencySymbol;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${ctrl.expenses.length} Catatan Biaya',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary)),
              if (canManage)
                FilledButton.icon(
                  onPressed: _openExpenseDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Pengeluaran'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ctrl.expenses.isEmpty
              ? const Center(child: Text('Belum ada pengeluaran operasional.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: ctrl.expenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = ctrl.expenses[i];
                    return Card(
                      child: ListTile(
                        title: Text(e.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${e.category} • ${e.paymentSource == "drawer" ? "Laci Kas" : "Kas Luar"} • ${PosFormatters.date(e.expenseDate)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              PosFormatters.currency(e.amount, symbol: sym),
                              style: AppTheme.tabular(null,
                                  fontWeight: FontWeight.w800,
                                  color: colors.statusDanger),
                            ),
                            if (canManage && e.id != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => ctrl.deleteExpense(e.id!),
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
}
