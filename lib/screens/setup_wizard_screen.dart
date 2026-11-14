import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';

/// First-Time Store Setup Wizard 3 Langkah (Tanpa Mode Demo)
class SetupWizardScreen extends StatefulWidget {
  final PosController controller;

  const SetupWizardScreen({super.key, required this.controller});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;

  // Step 1: Profil Toko
  final _storeNameCtrl = TextEditingController();
  String _businessType = 'retail';
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Step 2: Pajak & Mata Uang
  final _currencyCtrl = TextEditingController(text: 'Rp');
  final _taxCtrl = TextEditingController(text: '0');
  final _serviceCtrl = TextEditingController(text: '0');
  final _footerCtrl =
      TextEditingController(text: 'Terima kasih atas kunjungan Anda');

  // Step 3: Akun Owner & PIN 6-digit
  final _ownerNameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _obscurePin = true;

  String? _validationError;

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _currencyCtrl.dispose();
    _taxCtrl.dispose();
    _serviceCtrl.dispose();
    _footerCtrl.dispose();
    _ownerNameCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() => _validationError = null);
    if (_step == 0) {
      if (_storeNameCtrl.text.trim().isEmpty) {
        setState(() => _validationError = 'Nama toko wajib diisi.');
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      setState(() => _step = 2);
    }
  }

  Future<void> _submitSetup() async {
    setState(() => _validationError = null);
    final ownerName = _ownerNameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (ownerName.isEmpty) {
      setState(() => _validationError = 'Nama pemilik (Owner) wajib diisi.');
      return;
    }
    if (pin.length != 6 || int.tryParse(pin) == null) {
      setState(() => _validationError = 'PIN keamanan harus tepat 6 digit angka.');
      return;
    }
    if (pin != confirmPin) {
      setState(() => _validationError = 'Konfirmasi PIN tidak cocok.');
      return;
    }

    final ok = await widget.controller.completeSetup(
      storeName: _storeNameCtrl.text,
      businessType: _businessType,
      address: _addressCtrl.text,
      phone: _phoneCtrl.text,
      taxPercent: double.tryParse(_taxCtrl.text.replaceAll(',', '.')) ?? 0.0,
      serviceChargePercent:
          double.tryParse(_serviceCtrl.text.replaceAll(',', '.')) ?? 0.0,
      currencySymbol: _currencyCtrl.text,
      receiptFooter: _footerCtrl.text,
      ownerName: ownerName,
      ownerPin: pin,
    );

    if (!ok && mounted) {
      setState(() => _validationError = widget.controller.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.posColors;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.brandPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.storefront_rounded,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Setup Toko Pertama Kali',
                                  style: TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Langkah ${_step + 1} dari 3 • Konfigurasi Produksi',
                                  style: TextStyle(
                                      fontSize: 13, color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: (_step + 1) / 3,
                        borderRadius: BorderRadius.circular(999),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 22),
                      if (_step == 0) _buildStep1(colors),
                      if (_step == 1) _buildStep2(colors),
                      if (_step == 2) _buildStep3(colors),
                      if (_validationError != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.statusDanger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    colors.statusDanger.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _validationError!,
                            style: TextStyle(
                                color: colors.statusDanger,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          if (_step > 0) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _step--),
                                child: const Text('Kembali'),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: widget.controller.isLoading
                                  ? null
                                  : (_step < 2 ? _nextStep : _submitSetup),
                              child: Text(
                                _step < 2
                                    ? 'Lanjutkan'
                                    : 'Mulai Operasional Toko',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(PosColors colors) {
    final types = [
      ('retail', 'Retail / Minimarket', Icons.shopping_bag_outlined),
      ('fnb', 'F&B / Resto / Kafe', Icons.restaurant_rounded),
      ('service', 'Jasa / Layanan', Icons.design_services_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('1. Identitas & Jenis Usaha',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
          controller: _storeNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama Toko / Usaha *',
            hintText: 'Contoh: Toko Berkah Jaya',
            prefixIcon: Icon(Icons.store_rounded),
          ),
        ),
        const SizedBox(height: 14),
        Text('Jenis Usaha',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((t) {
            final selected = _businessType == t.$1;
            return ChoiceChip(
              selected: selected,
              avatar: Icon(t.$3, size: 18),
              label: Text(t.$2),
              onSelected: (_) => setState(() => _businessType = t.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _addressCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Alamat Toko (tampil di struk)',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'No. Telepon / WhatsApp',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(PosColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('2. Preferensi Pajak, Mata Uang & Struk',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
          controller: _currencyCtrl,
          decoration: const InputDecoration(
            labelText: 'Simbol Mata Uang',
            prefixIcon: Icon(Icons.attach_money_rounded),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _taxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Pajak / PPN (%)',
                  hintText: '0',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _serviceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Service Charge (%)',
                  hintText: '0',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _footerCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Teks Footer Struk',
            prefixIcon: Icon(Icons.receipt_long_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3(PosColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('3. Akun Pemilik (Owner) & PIN Keamanan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'PIN akan dienkripsi menggunakan salted SHA-256 secara lokal.',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ownerNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama Pemilik / Owner *',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pinCtrl,
          obscureText: _obscurePin,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'PIN Keamanan (6 Digit) *',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscurePin = !_obscurePin),
              icon: Icon(
                  _obscurePin ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmPinCtrl,
          obscureText: _obscurePin,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Konfirmasi PIN (6 Digit) *',
            prefixIcon: Icon(Icons.lock_reset_rounded),
          ),
        ),
      ],
    );
  }
}
