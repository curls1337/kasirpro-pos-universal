import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  AudioPlayer? _audioPlayer;
  late final Uint8List _beepWavBytes = _buildBeepWavBytes();
  bool _torchOn = false;
  bool _hasPopped = false;

  static Uint8List _buildBeepWavBytes({
    double frequency = 2200,
    int durationMs = 120,
    int sampleRate = 22050,
  }) {
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final dataSize = sampleCount * 2;
    final byteData = ByteData(44 + dataSize);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        byteData.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    // RIFF header
    writeAscii(0, 'RIFF');
    byteData.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');

    // fmt chunk
    writeAscii(12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // PCM
    byteData.setUint16(20, 1, Endian.little); // Linear PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little); // 16-bit

    // data chunk
    writeAscii(36, 'data');
    byteData.setUint32(40, dataSize, Endian.little);

    final fadeSamples = (sampleRate * 0.01).round().clamp(1, sampleCount ~/ 4);
    for (var i = 0; i < sampleCount; i++) {
      var envelope = 1.0;
      if (i < fadeSamples) {
        envelope = i / fadeSamples;
      } else if (i > sampleCount - fadeSamples) {
        envelope = (sampleCount - i) / fadeSamples;
      }
      final t = i / sampleRate;
      final sample = math.sin(2 * math.pi * frequency * t) * 0.65 * envelope;
      final pcm = (sample * 32767).round().clamp(-32768, 32767);
      byteData.setInt16(44 + i * 2, pcm, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  Future<void> _playBeepAndHaptic() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.play(BytesSource(_beepWavBytes));
    } catch (_) {}
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    try {
      _audioPlayer?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _submitCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _hasPopped) return;
    _hasPopped = true;
    await _playBeepAndHaptic();
    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (mounted) {
      Navigator.of(context).pop(code);
    }
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
