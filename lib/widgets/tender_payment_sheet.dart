import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pos_models.dart';
import '../services/bca_gateway_service.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';

/// Modal Pembayaran Lengkap (Tunai, QRIS, Transfer, EDC/Kartu, Kasbon, Split Payment)
/// dan Post-Payment Sheet (Cetak Thermal Struk 58/80mm, Cetak Label, WhatsApp E-Receipt)
class TenderPaymentSheet extends StatefulWidget {
  final PosController controller;

  const TenderPaymentSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, PosController controller) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TenderPaymentSheet(controller: controller),
    );
  }

  @override
  State<TenderPaymentSheet> createState() => _TenderPaymentSheetState();
}

class _TenderPaymentSheetState extends State<TenderPaymentSheet> {
  // 'cash' | 'qris' | 'transfer' | 'debit' | 'kasbon' | 'split'
  String _selectedMethod = 'cash';
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Split payment state
  final List<PaymentEntry> _splitEntries = [];
  String _splitMethod = 'cash';
  final TextEditingController _splitAmountController = TextEditingController();
  final TextEditingController _splitRefController = TextEditingController();

  bool _isProcessing = false;
  PosTransaction? _completedTx;
  String? _printFeedback;

  // BCA QRIS Gateway state
  BcaChargeResult? _bcaCharge;
  Uint8List? _qrisImageBytes;
  bool _isCreatingQris = false;
  String? _qrisError;
  String _qrisStatusText = '';
  Timer? _qrisPollTimer;
  bool _isPollingRequest = false;

  PosController get ctrl => widget.controller;
  int get totalBill => ctrl.cartGrandTotal;

  @override
  void initState() {
    super.initState();
    _cashController.text = totalBill.toString();
  }

  @override
  void dispose() {
    _qrisPollTimer?.cancel();
    _qrisPollTimer = null;
    _cashController.dispose();
    _refController.dispose();
    _notesController.dispose();
    _splitAmountController.dispose();
    _splitRefController.dispose();
    super.dispose();
  }

  List<int> _quickCashAmounts(int total) {
    final set = <int>{total};
    final round10k = ((total + 9999) ~/ 10000) * 10000;
    final round50k = ((total + 49999) ~/ 50000) * 50000;
    final round100k = ((total + 99999) ~/ 100000) * 100000;
    set.addAll([round10k, round50k, round100k]);
    for (final nominal in [20000, 50000, 100000, 200000, 500000]) {
      if (nominal >= total) set.add(nominal);
    }
    final sorted = set.toList()..sort();
    return sorted.take(4).toList();
  }

  int get _cashInput => int.tryParse(_cashController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int get _splitTotalAllocated =>
      _splitEntries.fold<int>(0, (sum, e) => sum + e.amount);

  int get _splitRemaining => (totalBill - _splitTotalAllocated).clamp(0, totalBill);

  Future<void> _submitPayment() async {
    if (_isProcessing) return;
    _qrisPollTimer?.cancel();
    _qrisPollTimer = null;
    final sym = ctrl.currencySymbol;

    List<PaymentEntry> payments = [];
    int paidAmount = 0;
    int changeAmount = 0;
    int debtAmount = 0;

    if (_selectedMethod == 'cash') {
      if (_cashInput < totalBill) {
        _showSnack('Uang tunai kurang dari total tagihan');
        return;
      }
      paidAmount = _cashInput;
      changeAmount = _cashInput - totalBill;
      payments = [PaymentEntry(method: 'cash', amount: totalBill)];
    } else if (_selectedMethod == 'qris' ||
        _selectedMethod == 'transfer' ||
        _selectedMethod == 'debit') {
      paidAmount = totalBill;
      payments = [
        PaymentEntry(
          method: _selectedMethod,
          amount: totalBill,
          referenceNo: _refController.text.trim(),
        ),
      ];
    } else if (_selectedMethod == 'kasbon') {
      if (ctrl.selectedCustomer == null) {
        _showSnack('Pilih pelanggan terlebih dahulu untuk mencatat Kasbon');
        return;
      }
      final cust = ctrl.selectedCustomer!;
      if (cust.creditLimit > 0 && (cust.totalDebt + totalBill) > cust.creditLimit) {
        _showSnack(
          'Melebihi batas piutang pelanggan (${PosFormatters.currency(cust.creditLimit, symbol: sym)})',
        );
        return;
      }
      debtAmount = totalBill;
      payments = [PaymentEntry(method: 'kasbon', amount: totalBill)];
    } else if (_selectedMethod == 'split') {
      if (_splitTotalAllocated < totalBill) {
        _showSnack('Total Split Payment belum mencukupi tagihan');
        return;
      }
      final hasKasbon = _splitEntries.any((e) => e.method == 'kasbon');
      if (hasKasbon && ctrl.selectedCustomer == null) {
        _showSnack('Pilih pelanggan terlebih dahulu karena Split memakai Kasbon');
        return;
      }
      payments = List.of(_splitEntries);
      debtAmount = _splitEntries
          .where((e) => e.method == 'kasbon')
          .fold<int>(0, (s, e) => s + e.amount);
      paidAmount = _splitTotalAllocated - debtAmount;
      changeAmount = (_splitTotalAllocated - totalBill).clamp(0, 1 << 31);
    }

    setState(() => _isProcessing = true);
    final tx = await ctrl.processCheckout(
      payments: payments,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      debtAmount: debtAmount,
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _completedTx = tx;
    });
    if (tx == null) {
      _showSnack(ctrl.errorMessage ?? 'Gagal memproses transaksi');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Uint8List? _decodeQrisImage(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final clean = raw.contains(',') ? raw.split(',').last.trim() : raw.trim();
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  Future<void> _createBcaQris() async {
    if (_isCreatingQris) return;
    _qrisPollTimer?.cancel();
    _qrisPollTimer = null;
    final externalId = 'POS-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _isCreatingQris = true;
      _qrisError = null;
      _qrisStatusText = '';
    });
    try {
      final charge = await ctrl.createBcaQrisCharge(
        externalId,
        totalBill.toDouble(),
        exactAmount: true,
      );
      if (!mounted) return;
      final bytes = _decodeQrisImage(charge.qrisImageBase64);
      setState(() {
        _bcaCharge = charge;
        _qrisImageBytes = bytes;
        _isCreatingQris = false;
        _qrisStatusText = 'Menunggu pembayaran (cek otomatis tiap 3 detik)...';
        _refController.text = charge.externalId;
      });
      _startQrisPolling(charge.externalId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreatingQris = false;
        _qrisError = e.toString();
      });
    }
  }

  void _startQrisPolling(String externalId) {
    _qrisPollTimer?.cancel();
    _qrisPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted ||
          _isPollingRequest ||
          _isProcessing ||
          _completedTx != null) {
        return;
      }
      _isPollingRequest = true;
      try {
        final res = await ctrl.checkBcaQrisStatus(externalId);
        if (!mounted) return;
        final st = res.status.toLowerCase();
        setState(() {
          _qrisStatusText = 'Status Gateway: ${res.status.toUpperCase()}';
        });
        if (res.isPaid || st == 'success') {
          _qrisPollTimer?.cancel();
          _qrisPollTimer = null;
          if (_refController.text.trim().isEmpty) {
            _refController.text = externalId;
          }
          await _submitPayment();
        }
      } catch (_) {
        // Abaikan error jaringan sementara selama polling
      } finally {
        _isPollingRequest = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.posColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: _completedTx != null
            ? _buildPostPaymentView(colors, _completedTx!)
            : _buildTenderView(colors),
      ),
    );
  }

  Widget _buildTenderView(PosColors colors) {
    final sym = ctrl.currencySymbol;
    final methods = [
      ('cash', 'Tunai', Icons.payments_rounded),
      ('qris', 'QRIS', Icons.qr_code_2_rounded),
      ('transfer', 'Transfer', Icons.account_balance_rounded),
      ('debit', 'EDC/Kartu', Icons.credit_card_rounded),
      ('kasbon', 'Kasbon', Icons.receipt_long_rounded),
      ('split', 'Split', Icons.call_split_rounded),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderSubtle,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pembayaran (Tender)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceHighlight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.brandPrimary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Tagihan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    PosFormatters.currency(totalBill, symbol: sym),
                    style: AppTheme.tabular(
                      null,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: colors.brandPrimary,
                    ),
                  ),
                ],
              ),
              if (ctrl.selectedCustomer != null)
                Chip(
                  avatar: const Icon(Icons.person_rounded, size: 16),
                  label: Text(ctrl.selectedCustomer!.name),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: methods.map((m) {
              final selected = _selectedMethod == m.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  onSelected: (_) {
                    if (m.$1 != 'qris') {
                      _qrisPollTimer?.cancel();
                      _qrisPollTimer = null;
                    }
                    setState(() => _selectedMethod = m.$1);
                  },
                  avatar: Icon(
                    m.$3,
                    size: 18,
                    color: selected ? colors.brandPrimary : colors.textSecondary,
                  ),
                  label: Text(m.$2),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedMethod == 'cash') _buildCashSection(colors, sym),
                if (_selectedMethod == 'qris') _buildQrisSection(colors, sym),
                if (_selectedMethod == 'transfer') _buildNonCashSection(colors, 'Transfer Bank', 'Pastikan mutasi rekening sudah masuk sebelum menyelesaikan pembayaran.'),
                if (_selectedMethod == 'debit') _buildNonCashSection(colors, 'Kartu Debit / Kredit (EDC)', 'Masukkan 4-6 digit Approval Code dari mesin EDC.'),
                if (_selectedMethod == 'kasbon') _buildKasbonSection(colors, sym),
                if (_selectedMethod == 'split') _buildSplitSection(colors, sym),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Transaksi (opsional)',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _submitPayment,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              _isProcessing
                  ? 'Memproses...'
                  : 'Selesaikan Pembayaran • ${PosFormatters.currency(totalBill, symbol: sym)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashSection(PosColors colors, String sym) {
    final quickList = _quickCashAmounts(totalBill);
    final diff = _cashInput - totalBill;
    final sufficient = diff >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickList.map((amt) {
            final isExact = amt == totalBill;
            return ActionChip(
              label: Text(
                isExact
                    ? 'Uang Pas (${PosFormatters.currency(amt, symbol: sym)})'
                    : PosFormatters.currency(amt, symbol: sym),
                style: AppTheme.tabular(null, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                setState(() => _cashController.text = amt.toString());
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cashController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: AppTheme.tabular(null, fontSize: 20, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'Uang Tunai Diterima ($sym)',
            prefixIcon: const Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (sufficient ? colors.statusSuccess : colors.statusDanger)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (sufficient ? colors.statusSuccess : colors.statusDanger)
                  .withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sufficient ? 'Kembalian' : 'Kurang Bayar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: sufficient ? colors.statusSuccess : colors.statusDanger,
                ),
              ),
              Text(
                PosFormatters.currency(diff.abs(), symbol: sym),
                style: AppTheme.tabular(
                  null,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: sufficient ? colors.statusSuccess : colors.statusDanger,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrisSection(PosColors colors, String sym) {
    final store = ctrl.store;
    final hasGateway = store != null &&
        store.gatewayUrl.trim().isNotEmpty &&
        store.gatewayApiKey.trim().isNotEmpty;

    if (!hasGateway) {
      return _buildNonCashSection(
        colors,
        'QRIS Dinamis / Statis',
        'Scan QRIS pada layar atau terminal EDC, lalu masukkan referensi jika ada.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: colors.brandPrimary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'QRIS BCA Otomatis (Nominal Pas)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Nominal persis: ${PosFormatters.currency(totalBill, symbol: sym)} (Tanpa Kode Unik)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.brandPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_bcaCharge == null && !_isCreatingQris)
            FilledButton.icon(
              onPressed: _createBcaQris,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Buat QRIS BCA (Nominal Pas)'),
            ),
          if (_isCreatingQris)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Membuat QRIS BCA nominal pas...'),
                ],
              ),
            ),
          if (_qrisError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.statusDanger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: colors.statusDanger.withValues(alpha: 0.35)),
              ),
              child: Text(
                _qrisError!,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.statusDanger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (_bcaCharge != null) ...[
            if (_qrisImageBytes != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Image.memory(
                    _qrisImageBytes!,
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'QRIS String:\n${_bcaCharge!.qrisString}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Tagihan: ${PosFormatters.currency(_bcaCharge!.amount, symbol: sym)} • Ref: ${_bcaCharge!.externalId}',
              textAlign: TextAlign.center,
              style: AppTheme.tabular(
                null,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_qrisStatusText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _qrisStatusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isCreatingQris ? null : _createBcaQris,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Buat Ulang QRIS'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _submitPayment,
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: const Text('Konfirmasi Lunas Manual'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _refController,
            decoration: const InputDecoration(
              labelText: 'No. Referensi / External ID (opsional)',
              prefixIcon: Icon(Icons.tag_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonCashSection(PosColors colors, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _refController,
            decoration: const InputDecoration(
              labelText: 'No. Referensi / Approval Code (opsional)',
              prefixIcon: Icon(Icons.tag_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKasbonSection(PosColors colors, String sym) {
    final cust = ctrl.selectedCustomer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Pilih Pelanggan untuk Kasbon / Piutang',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<CustomerItem>(
            value: cust,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Pelanggan',
              prefixIcon: Icon(Icons.person_search_rounded),
            ),
            items: ctrl.customers
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                      '${c.name} (Kasbon: ${PosFormatters.currency(c.totalDebt, symbol: sym)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => ctrl.setSelectedCustomer(val)),
          ),
          if (cust != null) ...[
            const SizedBox(height: 10),
            Text(
              'Kasbon saat ini: ${PosFormatters.currency(cust.totalDebt, symbol: sym)} • Setelah transaksi: ${PosFormatters.currency(cust.totalDebt + totalBill, symbol: sym)}',
              style: TextStyle(fontSize: 12, color: colors.statusWarning, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitSection(PosColors colors, String sym) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Split Payment', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'Sisa: ${PosFormatters.currency(_splitRemaining, symbol: sym)}',
                style: AppTheme.tabular(
                  null,
                  fontWeight: FontWeight.w700,
                  color: _splitRemaining == 0 ? colors.statusSuccess : colors.statusWarning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_splitEntries.isNotEmpty) ...[
            ..._splitEntries.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.method.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: item.referenceNo.isNotEmpty ? Text('Ref: ${item.referenceNo}') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      PosFormatters.currency(item.amount, symbol: sym),
                      style: AppTheme.tabular(null, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: colors.statusDanger, size: 20),
                      onPressed: () => setState(() => _splitEntries.removeAt(idx)),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
          ],
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _splitMethod,
                  decoration: const InputDecoration(labelText: 'Metode'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                    DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                    DropdownMenuItem(value: 'debit', child: Text('EDC')),
                    DropdownMenuItem(value: 'kasbon', child: Text('Kasbon')),
                  ],
                  onChanged: (v) => setState(() => _splitMethod = v ?? 'cash'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _splitAmountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Nominal ($sym)',
                    hintText: _splitRemaining.toString(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _splitRefController,
                  decoration: const InputDecoration(labelText: 'No. Ref (opsional)'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  final raw = int.tryParse(_splitAmountController.text) ?? _splitRemaining;
                  if (raw <= 0) return;
                  setState(() {
                    _splitEntries.add(
                      PaymentEntry(
                        method: _splitMethod,
                        amount: raw,
                        referenceNo: _splitRefController.text.trim(),
                      ),
                    );
                    _splitAmountController.clear();
                    _splitRefController.clear();
                  });
                },
                child: const Text('+ Tambah'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostPaymentView(PosColors colors, PosTransaction tx) {
    final sym = ctrl.currencySymbol;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderSubtle,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: CircleAvatar(
            radius: 34,
            backgroundColor: colors.statusSuccess.withValues(alpha: 0.14),
            child: Icon(Icons.check_rounded, size: 38, color: colors.statusSuccess),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pembayaran Berhasil',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${tx.invoiceNo} • ${PosFormatters.dateTime(tx.createdAt)}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            children: [
              _summaryRow('Total Tagihan', PosFormatters.currency(tx.totalAmount, symbol: sym)),
              const SizedBox(height: 6),
              _summaryRow('Dibayar', PosFormatters.currency(tx.paidAmount, symbol: sym)),
              if (tx.debtAmount > 0) ...[
                const SizedBox(height: 6),
                _summaryRow(
                  'Masuk Kasbon',
                  PosFormatters.currency(tx.debtAmount, symbol: sym),
                  valueColor: colors.statusWarning,
                ),
              ],
              const Divider(height: 18),
              _summaryRow(
                'Kembalian',
                PosFormatters.currency(tx.changeAmount, symbol: sym),
                isBold: true,
                valueColor: colors.statusSuccess,
              ),
            ],
          ),
        ),
        if (_printFeedback != null) ...[
          const SizedBox(height: 10),
          Text(
            _printFeedback!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.statusInfo, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final res = await ctrl.printTransactionReceipt(tx);
                  if (mounted) setState(() => _printFeedback = res);
                },
                icon: const Icon(Icons.print_rounded),
                label: Text(
                  ctrl.defaultReceiptPrinter != null
                      ? 'Struk ${ctrl.defaultReceiptPrinter!.paperWidthMm}mm'
                      : 'Cetak Struk PDF',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final receiptText =
                      '*${ctrl.store?.name ?? "POS Universal"}*\nNo: ${tx.invoiceNo}\nTotal: ${PosFormatters.currency(tx.totalAmount, symbol: sym)}\nBayar: ${PosFormatters.currency(tx.paidAmount, symbol: sym)}\nKembali: ${PosFormatters.currency(tx.changeAmount, symbol: sym)}';
                  Clipboard.setData(ClipboardData(text: receiptText));
                  setState(() => _printFeedback = 'Teks E-Receipt disalin untuk WhatsApp');
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Salin E-Receipt'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text(
              'Transaksi Baru',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: AppTheme.tabular(
            null,
            fontSize: isBold ? 20 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
