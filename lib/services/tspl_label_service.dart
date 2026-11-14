import 'dart:convert';
import 'dart:typed_data';
import 'package:barcode/barcode.dart' as bc;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pos_models.dart';

class TsplLabelService {
  TsplLabelService._internal();
  static final TsplLabelService instance = TsplLabelService._internal();
  factory TsplLabelService() => instance;

  static final NumberFormat _idrFormat = NumberFormat.decimalPattern('id_ID');

  String _cleanText(String input, {int maxLen = 24}) {
    final ascii = input
        .replaceAll('"', "'")
        .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
        .trim();
    if (ascii.length <= maxLen) return ascii;
    return ascii.substring(0, maxLen);
  }

  String _resolveBarcodeValue(ProductItem product) {
    final b = product.barcode?.trim() ?? '';
    if (b.isNotEmpty) return _cleanText(b, maxLen: 24);
    final s = product.sku?.trim() ?? '';
    if (s.isNotEmpty) return _cleanText(s, maxLen: 24);
    return 'PRD${(product.id ?? 1).toString().padLeft(6, '0')}';
  }

  /// Builder perintah raw TSPL untuk printer label thermal (Xprinter, TSC, Gprinter)
  /// Mendukung 30x20mm, 40x30mm, 50x30mm, 58x40mm.
  Uint8List buildTsplLabelCommands({
    required ProductItem product,
    required LabelSizePreset preset,
    int copies = 1,
    String? storeName,
    String currencySymbol = 'Rp',
    bool showStoreName = true,
    bool showPrice = true,
    bool showSku = true,
  }) {
    final safeCopies = copies.clamp(1, 500);
    final code = _resolveBarcodeValue(product);
    final maxChars = preset.widthMm <= 30
        ? 18
        : (preset.widthMm <= 40 ? 24 : 30);
    final prodName = _cleanText(product.name, maxLen: maxChars);
    final priceText = '$currencySymbol ${_idrFormat.format(product.sellPrice)}';

    final sb = StringBuffer();
    sb.writeln('SIZE ${preset.widthMm} mm,${preset.heightMm} mm');
    sb.writeln('GAP ${preset.gapMm} mm,0 mm');
    sb.writeln('DIRECTION 1');
    sb.writeln('CLS');

    var y = 10;
    const xMargin = 14;

    if (showStoreName && storeName != null && storeName.trim().isNotEmpty) {
      sb.writeln(
          'TEXT $xMargin,$y,"1",0,1,1,"${_cleanText(storeName, maxLen: maxChars)}"');
      y += 20;
    }

    sb.writeln('TEXT $xMargin,$y,"2",0,1,1,"$prodName"');
    y += preset.heightMm <= 20 ? 22 : 28;

    final barHeight = preset.heightMm <= 20
        ? 44
        : (preset.heightMm <= 30 ? 64 : 88);
    final narrow = preset.widthMm >= 50 ? 2 : 1;
    final wide = preset.widthMm >= 50 ? 4 : 2;
    sb.writeln(
        'BARCODE $xMargin,$y,"128",$barHeight,1,0,$narrow,$wide,"$code"');
    y += barHeight + 24;

    if (showPrice && y < preset.heightDots - 16) {
      sb.writeln('TEXT $xMargin,$y,"3",0,1,1,"$priceText"');
    } else if (showSku && y < preset.heightDots - 16) {
      sb.writeln(
          'TEXT $xMargin,$y,"1",0,1,1,"SKU: ${_cleanText(product.sku ?? code, maxLen: 18)}"');
    }

    sb.writeln('PRINT 1,$safeCopies');
    return Uint8List.fromList(latin1.encode(sb.toString()));
  }

  /// Builder perintah raw CPCL untuk printer label portabel CPCL
  Uint8List buildCpclLabelCommands({
    required ProductItem product,
    required LabelSizePreset preset,
    int copies = 1,
    String? storeName,
    String currencySymbol = 'Rp',
    bool showStoreName = true,
    bool showPrice = true,
  }) {
    final safeCopies = copies.clamp(1, 500);
    final code = _resolveBarcodeValue(product);
    final prodName = _cleanText(product.name, maxLen: 24);
    final priceText = '$currencySymbol ${_idrFormat.format(product.sellPrice)}';

    final sb = StringBuffer();
    sb.writeln('! 0 200 200 ${preset.heightDots} $safeCopies');
    sb.writeln('PAGE-WIDTH ${preset.widthDots}');

    var y = 12;
    if (showStoreName && storeName != null && storeName.trim().isNotEmpty) {
      sb.writeln('TEXT 4 0 16 $y ${_cleanText(storeName, maxLen: 24)}');
      y += 22;
    }
    sb.writeln('TEXT 4 0 16 $y $prodName');
    y += 26;
    final barHeight = preset.heightMm <= 20 ? 40 : 60;
    sb.writeln('BARCODE 128 1 1 $barHeight 16 $y $code');
    y += barHeight + 18;
    if (showPrice) {
      sb.writeln('TEXT 4 1 16 $y $priceText');
    }
    sb.writeln('FORM');
    sb.writeln('PRINT');
    return Uint8List.fromList(latin1.encode(sb.toString()));
  }

  /// Generate PDF Label Barcode presisi ukuran mm untuk cetak via System PDF / AirPrint
  Future<Uint8List> buildLabelPdfBytes({
    required List<ProductItem> products,
    required LabelSizePreset preset,
    Map<int, int>? copiesPerProduct,
    String? storeName,
    String currencySymbol = 'Rp',
    bool showStoreName = true,
    bool showPrice = true,
    bool showSku = true,
  }) async {
    final doc = pw.Document();
    final pageFormat = PdfPageFormat(
      preset.widthMm * PdfPageFormat.mm,
      preset.heightMm * PdfPageFormat.mm,
      marginAll: 1.5 * PdfPageFormat.mm,
    );

    for (final product in products) {
      final count = (copiesPerProduct?[product.id] ?? 1).clamp(1, 200);
      final code = _resolveBarcodeValue(product);
      final priceText = '$currencySymbol ${_idrFormat.format(product.sellPrice)}';

      for (var i = 0; i < count; i++) {
        doc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (showStoreName &&
                    storeName != null &&
                    storeName.trim().isNotEmpty)
                  pw.Text(
                    storeName,
                    maxLines: 1,
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                pw.Text(
                  product.name,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: preset.heightMm <= 20 ? 7 : 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 1.5),
                pw.BarcodeWidget(
                  barcode: bc.Barcode.code128(),
                  data: code,
                  width: (preset.widthMm - 5) * PdfPageFormat.mm,
                  height: (preset.heightMm * 0.42) * PdfPageFormat.mm,
                  drawText: true,
                  textStyle: const pw.TextStyle(fontSize: 5.5),
                ),
                if (showPrice) ...[
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    priceText,
                    style: pw.TextStyle(
                      fontSize: preset.heightMm <= 20 ? 7.5 : 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ] else if (showSku && (product.sku ?? '').isNotEmpty) ...[
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    'SKU: ${product.sku}',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    return doc.save();
  }
}
