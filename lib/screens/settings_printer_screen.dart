import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pos_models.dart';
import '../services/bca_gateway_service.dart';
import '../services/printer_manager.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';

/// Layar Pengaturan: Profil Toko, Pajak/Service, Staff RBAC, Printer Thermal & Label Manager, Tema, Backup/Restore JSON
class SettingsPrinterScreen extends StatefulWidget {
  final PosController controller;

  const SettingsPrinterScreen({super.key, required this.controller});

  @override
  State<SettingsPrinterScreen> createState() => _SettingsPrinterScreenState();
}

class _SettingsPrinterScreenState extends State<SettingsPrinterScreen> {
  PosController get ctrl => widget.controller;

  bool _isScanningBt = false;
  bool _isConnectingBt = false;
  BluetoothScanResult? _btScanResult;
  String? _btFeedbackMessage;

  Future<void> _scanBluetoothDirect() async {
    setState(() {
      _isScanningBt = true;
      _btFeedbackMessage = null;
    });
    final res = await ctrl.scanBluetoothPrinters();
    if (!mounted) return;
    setState(() {
      _isScanningBt = false;
      _btScanResult = res;
      if (res.errorMessage != null) {
        _btFeedbackMessage = res.errorMessage;
      } else if (res.devices.isNotEmpty) {
        _btFeedbackMessage =
            'Ditemukan ${res.devices.length} printer Bluetooth yang sudah di-pairing. Ketuk chip untuk langsung Hubungkan & Simpan.';
      }
    });
  }

  Future<void> _quickConnectAndSaveBluetoothDevice(
    BluetoothDeviceItem device,
  ) async {
    if (_isConnectingBt) return;
    setState(() {
      _isConnectingBt = true;
      _btFeedbackMessage = 'Menghubungkan ke ${device.name}...';
    });

    PrinterConfig? existing;
    for (final p in ctrl.printerConfigs) {
      if (p.connectionType == 'bluetooth' &&
          p.addressOrIp.trim().toLowerCase() ==
              device.macAddress.trim().toLowerCase()) {
        existing = p;
        break;
      }
    }

    final targetConfig = existing != null
        ? existing.copyWith(
            name: device.name.isNotEmpty ? device.name : existing.name,
            isDefault: true,
          )
        : PrinterConfig(
            name: device.name.isNotEmpty ? device.name : 'Printer Thermal BT',
            roleType: 'receipt',
            connectionType: 'bluetooth',
            addressOrIp: device.macAddress,
            port: 9100,
            paperWidthMm: 58,
            commandLang: 'escpos',
            isDefault: true,
            autoPrint: true,
            openDrawer: false,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          );

    await ctrl.savePrinterConfig(targetConfig);
    final res = await ctrl.connectPrinter(targetConfig);
    if (!mounted) return;
    setState(() {
      _isConnectingBt = false;
      _btFeedbackMessage = res.message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.message)),
    );
  }

  Future<void> _openStoreEditDialog() async {
    final store = ctrl.store;
    if (store == null) return;

    final nameCtrl = TextEditingController(text: store.name);
    final addrCtrl = TextEditingController(text: store.address);
    final phoneCtrl = TextEditingController(text: store.phone);
    final taxCtrl = TextEditingController(text: store.taxPercent.toString());
    final svcCtrl =
        TextEditingController(text: store.serviceChargePercent.toString());
    final footerCtrl = TextEditingController(text: store.receiptFooter);
    String bType = store.businessType;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Profil Toko & Pajak'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Toko'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: bType,
                  decoration: const InputDecoration(labelText: 'Jenis Usaha'),
                  items: const [
                    DropdownMenuItem(value: 'retail', child: Text('Retail')),
                    DropdownMenuItem(value: 'fnb', child: Text('F&B / Resto')),
                    DropdownMenuItem(value: 'service', child: Text('Jasa')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => bType = v ?? 'retail'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(labelText: 'Alamat'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'No. Telepon'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: taxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'PPN (%)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: svcCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Service (%)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: footerCtrl,
                  decoration: const InputDecoration(labelText: 'Footer Struk'),
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
                await ctrl.updateStore(
                  store.copyWith(
                    name: nameCtrl.text.trim(),
                    businessType: bType,
                    address: addrCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    taxPercent: double.tryParse(taxCtrl.text) ?? 0.0,
                    serviceChargePercent:
                        double.tryParse(svcCtrl.text) ?? 0.0,
                    receiptFooter: footerCtrl.text.trim(),
                    updatedAt: DateTime.now().toUtc().toIso8601String(),
                  ),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBcaGatewayDialog() async {
    final store = ctrl.store;
    if (store == null) return;

    final urlCtrl = TextEditingController(text: store.gatewayUrl);
    final apiKeyCtrl = TextEditingController(text: store.gatewayApiKey);
    bool obscureKey = true;
    bool testing = false;
    BcaConnectionResult? testResult;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('BCA Payment Gateway (QRIS Nominal Pas)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL Gateway',
                    hintText: 'https://gateway.tokoanda.com',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: apiKeyCtrl,
                  obscureText: obscureKey,
                  decoration: InputDecoration(
                    labelText: 'API Key Merchant',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setDialogState(() => obscureKey = !obscureKey),
                      icon: Icon(
                          obscureKey ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: testing
                      ? null
                      : () async {
                          setDialogState(() {
                            testing = true;
                            testResult = null;
                          });
                          final res = await ctrl.testBcaGatewayConnection(
                            urlCtrl.text,
                            apiKeyCtrl.text,
                          );
                          if (ctx.mounted) {
                            setDialogState(() {
                              testing = false;
                              testResult = res;
                            });
                          }
                        },
                  icon: testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 18),
                  label: Text(testing ? 'Menguji...' : 'Tes Koneksi'),
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    testResult!.message,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: testResult!.success
                          ? ctx.posColors.statusSuccess
                          : ctx.posColors.statusDanger,
                    ),
                  ),
                ],
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
                final cleanUrl = urlCtrl.text.trim();
                final cleanKey = apiKeyCtrl.text.trim();
                await ctrl.updateStore(
                  store.copyWith(
                    gatewayUrl: cleanUrl,
                    gatewayApiKey: cleanKey,
                    updatedAt: DateTime.now().toUtc().toIso8601String(),
                  ),
                  gatewayUrl: cleanUrl,
                  gatewayApiKey: cleanKey,
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Konfigurasi BCA Payment Gateway berhasil disimpan'),
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStaffDialog({AppUser? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final pinCtrl = TextEditingController();
    String role = existing?.role ?? 'cashier';
    bool isActive = existing?.isActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Tambah Staff / Kasir' : 'Edit Staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Staff *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role / Jabatan'),
                  items: const [
                    DropdownMenuItem(value: 'owner', child: Text('Owner')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'cashier', child: Text('Kasir')),
                    DropdownMenuItem(value: 'kitchen', child: Text('Dapur')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'cashier'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  maxLength: 6,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: existing == null
                        ? 'PIN 6 Digit *'
                        : 'PIN Baru (kosongkan jika tidak ubah)',
                  ),
                ),
                if (existing != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Akun Aktif'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
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
                if (existing == null && pinCtrl.text.length != 6) return;
                if (pinCtrl.text.isNotEmpty && pinCtrl.text.length != 6) return;
                await ctrl.saveStaffUser(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  role: role,
                  pin: pinCtrl.text.isEmpty ? null : pinCtrl.text,
                  isActive: isActive,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrinterDialog({PrinterConfig? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? 'Printer Kasir');
    final addrCtrl =
        TextEditingController(text: existing?.addressOrIp ?? '');
    final portCtrl =
        TextEditingController(text: (existing?.port ?? 9100).toString());
    String roleType = existing?.roleType ?? 'receipt';
    String connType = existing?.connectionType ?? 'bluetooth';
    int paperWidth = existing?.paperWidthMm ?? 58;
    String labelSize = existing?.labelSize ?? '40x30';
    String cmdLang = existing?.commandLang ?? 'escpos';
    bool isDefault = existing?.isDefault ?? true;
    bool autoPrint = existing?.autoPrint ?? false;
    bool openDrawer = existing?.openDrawer ?? false;

    List<BluetoothDeviceItem> btDevices = [];
    bool scanningBt = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null
                      ? 'Tambah Printer Thermal / Label'
                      : 'Edit Printer',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Printer'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: roleType,
                        decoration: const InputDecoration(labelText: 'Fungsi'),
                        items: const [
                          DropdownMenuItem(
                              value: 'receipt', child: Text('Struk Kasir')),
                          DropdownMenuItem(
                              value: 'kitchen', child: Text('Tiket Dapur')),
                          DropdownMenuItem(
                              value: 'label', child: Text('Label Barcode')),
                        ],
                        onChanged: (v) {
                          setModalState(() {
                            roleType = v ?? 'receipt';
                            if (roleType == 'label' && cmdLang == 'escpos') {
                              cmdLang = 'tspl';
                            } else if (roleType != 'label' &&
                                (cmdLang == 'tspl' || cmdLang == 'cpcl')) {
                              cmdLang = 'escpos';
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: connType,
                        decoration: const InputDecoration(labelText: 'Koneksi'),
                        items: const [
                          DropdownMenuItem(
                              value: 'bluetooth', child: Text('Bluetooth')),
                          DropdownMenuItem(
                              value: 'wifi_tcp', child: Text('WiFi / LAN IP')),
                          DropdownMenuItem(
                              value: 'system_pdf', child: Text('System PDF')),
                        ],
                        onChanged: (v) =>
                            setModalState(() => connType = v ?? 'bluetooth'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (connType == 'bluetooth') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addrCtrl,
                          decoration: const InputDecoration(
                            labelText: 'MAC / UUID Bluetooth',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: scanningBt
                            ? null
                            : () async {
                                setModalState(() => scanningBt = true);
                                try {
                                  btDevices = await PrinterManager.instance
                                      .scanBluetoothDevices();
                                } catch (_) {
                                  btDevices = [];
                                }
                                if (ctx.mounted) {
                                  setModalState(() => scanningBt = false);
                                }
                              },
                        icon: const Icon(Icons.bluetooth_searching_rounded),
                        label: Text(scanningBt ? 'Scan...' : 'Scan BT'),
                      ),
                    ],
                  ),
                  if (btDevices.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: btDevices.map((d) {
                        return ActionChip(
                          label: Text('${d.name} (${d.macAddress})'),
                          onPressed: () {
                            addrCtrl.text = d.macAddress;
                            if (nameCtrl.text == 'Printer Kasir' &&
                                d.name.isNotEmpty) {
                              nameCtrl.text = d.name;
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
                if (connType == 'wifi_tcp')
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: addrCtrl,
                          decoration: const InputDecoration(
                            labelText: 'IP Address (mis. 192.168.1.200)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Port'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (roleType == 'label')
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: labelSize,
                          decoration:
                              const InputDecoration(labelText: 'Ukuran Label'),
                          items: const [
                            DropdownMenuItem(
                                value: '30x20', child: Text('30x20 mm')),
                            DropdownMenuItem(
                                value: '40x30', child: Text('40x30 mm')),
                            DropdownMenuItem(
                                value: '50x30', child: Text('50x30 mm')),
                            DropdownMenuItem(
                                value: '58x40', child: Text('58x40 mm')),
                          ],
                          onChanged: (v) =>
                              setModalState(() => labelSize = v ?? '40x30'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: cmdLang,
                          decoration:
                              const InputDecoration(labelText: 'Bahasa'),
                          items: const [
                            DropdownMenuItem(
                                value: 'tspl', child: Text('TSPL (Xprinter)')),
                            DropdownMenuItem(
                                value: 'cpcl', child: Text('CPCL (Portable)')),
                            DropdownMenuItem(
                                value: 'pdf', child: Text('PDF Label')),
                          ],
                          onChanged: (v) =>
                              setModalState(() => cmdLang = v ?? 'tspl'),
                        ),
                      ),
                    ],
                  )
                else
                  DropdownButtonFormField<int>(
                    value: paperWidth,
                    decoration:
                        const InputDecoration(labelText: 'Lebar Kertas Struk'),
                    items: const [
                      DropdownMenuItem(value: 58, child: Text('58 mm (32 char)')),
                      DropdownMenuItem(value: 80, child: Text('80 mm (48 char)')),
                    ],
                    onChanged: (v) =>
                        setModalState(() => paperWidth = v ?? 58),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Jadikan Printer Utama (Default)'),
                  value: isDefault,
                  onChanged: (v) => setModalState(() => isDefault = v),
                ),
                if (roleType == 'receipt') ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Print setelah pembayaran'),
                    value: autoPrint,
                    onChanged: (v) => setModalState(() => autoPrint = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Buka Laci Kas (Cash Drawer) otomatis'),
                    value: openDrawer,
                    onChanged: (v) => setModalState(() => openDrawer = v),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    await ctrl.savePrinterConfig(
                      PrinterConfig(
                        id: existing?.id,
                        name: nameCtrl.text.trim(),
                        roleType: roleType,
                        connectionType: connType,
                        addressOrIp: addrCtrl.text.trim(),
                        port: int.tryParse(portCtrl.text) ?? 9100,
                        paperWidthMm: paperWidth,
                        labelSize: labelSize,
                        commandLang: connType == 'system_pdf' ? 'pdf' : cmdLang,
                        isDefault: isDefault,
                        autoPrint: autoPrint,
                        openDrawer: openDrawer,
                        createdAt: existing?.createdAt ??
                            DateTime.now().toUtc().toIso8601String(),
                      ),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Simpan Konfigurasi Printer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.posColors;
    final store = ctrl.store;
    final isOwner = ctrl.canAccess('settings_admin');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Pengaturan & Printer Thermal',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store?.name ?? '-',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          Text(
                            '${store?.businessType.toUpperCase() ?? "-"} • PPN ${store?.taxPercent ?? 0}% • Service ${store?.serviceChargePercent ?? 0}%',
                            style: TextStyle(
                                fontSize: 12, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (isOwner)
                      OutlinedButton(
                        onPressed: _openStoreEditDialog,
                        child: const Text('Edit Toko'),
                      ),
                  ],
                ),
                const Divider(height: 22),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode OLED Dark'),
                  subtitle: const Text(
                      'Tampilan gelap hemat daya untuk kafe/malam'),
                  value: ctrl.themeMode == ThemeMode.dark,
                  onChanged: (_) => ctrl.toggleTheme(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (isOwner) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, color: colors.brandPrimary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'BCA Payment Gateway (QRIS Nominal Pas)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(
                        label: Text(
                          ctrl.hasBcaGatewayConfigured
                              ? 'Terkonfigurasi'
                              : 'Belum Diatur',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ctrl.hasBcaGatewayConfigured
                                ? colors.statusSuccess
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ctrl.hasBcaGatewayConfigured
                        ? 'URL: ${store?.gatewayUrl}\nAPI Key: ••••••••'
                        : 'Hubungkan server BCA Payment Gateway untuk QRIS otomatis dengan nominal persis tanpa kode unik.',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _openBcaGatewayDialog,
                        icon: const Icon(Icons.settings_ethernet_rounded,
                            size: 18),
                        label: Text(ctrl.hasBcaGatewayConfigured
                            ? 'Edit Gateway'
                            : 'Konfigurasi Gateway'),
                      ),
                      if (ctrl.hasBcaGatewayConfigured)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final res = await ctrl.testBcaGatewayConnection(
                              store?.gatewayUrl ?? '',
                              store?.gatewayApiKey ?? '',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(res.message)),
                              );
                            }
                          },
                          icon: const Icon(Icons.wifi_tethering_rounded,
                              size: 18),
                          label: const Text('Tes Koneksi'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      ctrl.isPrinterConnected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_disabled_rounded,
                      color: ctrl.isPrinterConnected
                          ? colors.statusSuccess
                          : colors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Panel Koneksi Printer Thermal',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Chip(
                      backgroundColor: ctrl.isPrinterConnected
                          ? colors.statusSuccess.withOpacity(0.14)
                          : null,
                      label: Text(
                        ctrl.isPrinterConnected
                            ? 'Terhubung'
                            : 'Belum Terhubung',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ctrl.isPrinterConnected
                              ? colors.statusSuccess
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ctrl.isPrinterConnected
                      ? 'Printer aktif: ${ctrl.connectedPrinterName ?? "Thermal Printer"}'
                      : 'Scan perangkat Bluetooth yang sudah di-pairing di Pengaturan HP, lalu ketuk untuk langsung menghubungkan & menyimpan.',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed:
                          (_isScanningBt || _isConnectingBt)
                              ? null
                              : _scanBluetoothDirect,
                      icon: _isScanningBt
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bluetooth_searching_rounded,
                              size: 18),
                      label: Text(
                          _isScanningBt ? 'Memindai...' : 'Scan Bluetooth'),
                    ),
                  ],
                ),
                if (_btFeedbackMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_btScanResult != null &&
                              (!_btScanResult!.permissionGranted ||
                                  !_btScanResult!.bluetoothEnabled ||
                                  _btScanResult!.devices.isEmpty))
                          ? colors.statusDanger.withOpacity(0.08)
                          : colors.brandPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _btFeedbackMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (_btScanResult != null &&
                                (!_btScanResult!.permissionGranted ||
                                    !_btScanResult!.bluetoothEnabled ||
                                    _btScanResult!.devices.isEmpty))
                            ? colors.statusDanger
                            : colors.textPrimary,
                      ),
                    ),
                  ),
                ],
                if (_btScanResult != null &&
                    _btScanResult!.devices.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _btScanResult!.devices.map((d) {
                      return ActionChip(
                        avatar: const Icon(Icons.print_rounded, size: 16),
                        label: Text('${d.name} (${d.macAddress})'),
                        onPressed: _isConnectingBt
                            ? null
                            : () => _quickConnectAndSaveBluetoothDevice(d),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Printer Thermal Struk & Label',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            FilledButton.icon(
              onPressed: () => _openPrinterDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Printer'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (ctrl.printerConfigs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada printer dikonfigurasi. Tanpa printer hardware, sistem otomatis memakai System PDF.',
              ),
            ),
          )
        else
          ...ctrl.printerConfigs.map((cfg) {
            final isThisConnected = ctrl.isPrinterConnected &&
                cfg.connectionType != 'system_pdf' &&
                ((ctrl.connectedPrinterAddress != null &&
                        ctrl.connectedPrinterAddress!.trim().toLowerCase() ==
                            cfg.addressOrIp.trim().toLowerCase()) ||
                    (ctrl.connectedPrinterAddress == null &&
                        ctrl.connectedPrinterName == cfg.name));
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        cfg.roleType == 'label'
                            ? Icons.qr_code_2_rounded
                            : Icons.print_rounded,
                        color: isThisConnected
                            ? colors.statusSuccess
                            : colors.brandPrimary,
                      ),
                      title: Text(
                        '${cfg.name}${cfg.isDefault ? " (Utama)" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${cfg.roleType.toUpperCase()} • ${cfg.connectionType} • ${cfg.addressOrIp.isEmpty ? "OS Print" : cfg.addressOrIp}${isThisConnected ? " • Terhubung" : ""}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openPrinterDialog(existing: cfg),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (cfg.connectionType != 'system_pdf')
                          isThisConnected
                              ? OutlinedButton.icon(
                                  onPressed: () async {
                                    final res =
                                        await ctrl.disconnectPrinter(cfg);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(res.message)),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.link_off_rounded,
                                      size: 18),
                                  label: const Text('Putuskan'),
                                )
                              : FilledButton.tonalIcon(
                                  onPressed: () async {
                                    final res = await ctrl.connectPrinter(cfg);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(res.message)),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.link_rounded,
                                      size: 18),
                                  label: const Text('Hubungkan'),
                                ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final msg = cfg.roleType == 'label'
                                  ? await ctrl.testPrintLabel(cfg)
                                  : await ctrl.testPrintReceipt(cfg);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(msg)));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal cetak: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Test Print'),
                        ),
                        if (cfg.roleType == 'receipt' &&
                            cfg.connectionType != 'system_pdf')
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await ctrl.kickCashDrawer(cfg);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Perintah buka laci dikirim')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gagal: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.point_of_sale_rounded,
                                size: 18),
                            label: const Text('Buka Laci'),
                          ),
                        if (cfg.id != null)
                          TextButton(
                            onPressed: () => ctrl.deletePrinterConfig(cfg.id!),
                            child: Text('Hapus',
                                style: TextStyle(color: colors.statusDanger)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        if (isOwner) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manajemen Staff & PIN (RBAC)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              FilledButton.tonalIcon(
                onPressed: () => _openStaffDialog(),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Tambah Staff'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...ctrl.users.map(
            (u) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(u.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    'Role: ${u.role.toUpperCase()} • ${u.isActive ? "Aktif" : "Nonaktif"}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openStaffDialog(existing: u),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Backup & Restore Database (JSON)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ctrl.backupDatabaseJson();
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Backup JSON'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final ok = await ctrl.restoreDatabaseJson();
                        if (context.mounted && ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Database berhasil di-restore')),
                          );
                        }
                      },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Restore JSON'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
