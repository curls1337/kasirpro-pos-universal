import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet untuk scan barcode via kamera atau input manual (HID/ketik)
class BarcodeScannerSheet extends StatefulWidget {
  final String title;

  const BarcodeScannerSheet({
    super.key,
    this.title = 'Scan Barcode / SKU',
  });

  static Future<String?> show(BuildContext context, {String? title}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BarcodeScannerSheet(title: title ?? 'Scan Barcode / SKU'),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualController = TextEditingController();
  bool _torchOn = false;
  bool _hasPopped = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _submitCode(String raw) {
    final code = raw.trim();
    if (code.isEmpty || _hasPopped) return;
    _hasPopped = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.posColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
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
                Icon(Icons.qr_code_scanner_rounded, color: colors.brandPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Lampu Flash',
                  onPressed: () async {
                    await _scannerController.toggleTorch();
                    if (mounted) setState(() => _torchOn = !_torchOn);
                  },
                  icon: Icon(
                    _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _torchOn ? colors.statusWarning : colors.textSecondary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final val = barcode.rawValue;
                          if (val != null && val.trim().isNotEmpty) {
                            _submitCode(val);
                            break;
                          }
                        }
                      },
                      errorBuilder: (context, error, child) {
                        return Container(
                          color: colors.surfaceElevated,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_off_rounded,
                                  size: 40, color: colors.textMuted),
                              const SizedBox(height: 10),
                              Text(
                                'Kamera tidak tersedia atau izin ditolak.\nGunakan input kode manual di bawah.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Center(
                      child: Container(
                        width: 230,
                        height: 130,
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.brandPrimary, width: 2.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Atau ketik / scan dengan USB/Bluetooth Scanner:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _submitCode,
                    decoration: const InputDecoration(
                      hintText: 'Masukkan kode barcode atau SKU...',
                      prefixIcon: Icon(Icons.keyboard_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => _submitCode(_manualController.text),
                  child: const Text('Cari'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
