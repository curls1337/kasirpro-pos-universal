import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../data/db_helper.dart';
import '../models/pos_models.dart';

class ExportService {
  ExportService._internal();
  static final ExportService instance = ExportService._internal();
  factory ExportService() => instance;

  static final NumberFormat _idrFormat = NumberFormat.decimalPattern('id_ID');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  String _fmtMoney(int amount, [String symbol = 'Rp']) {
    final neg = amount < 0 ? '-' : '';
    return '$neg$symbol ${_idrFormat.format(amount.abs())}';
  }

  String _csvEscape(String value) {
    final v = value.replaceAll('"', '""');
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"$v"';
    }
    return v;
  }

  // =========================================================================
  // CSV GENERATORS
  // =========================================================================

  String generateTransactionsCsv(
    List<PosTransaction> transactions, {
    String currencySymbol = 'Rp',
  }) {
    final sb = StringBuffer();
    sb.writeln(
        'Invoice,Tanggal,Tipe Order,Meja,Subtotal,Diskon,Pajak,Service Charge,Total,Dibayar,Kembalian,Kasbon,Status,Catatan');
    for (final tx in transactions) {
      final dt =
          DateTime.tryParse(tx.createdAt)?.toLocal() ?? DateTime.now();
      sb.writeln([
        _csvEscape(tx.invoiceNo),
        _csvEscape(_dateTimeFormat.format(dt)),
        _csvEscape(tx.orderType),
        _csvEscape(tx.tableNumber),
        tx.subtotal,
        tx.discountAmount,
        tx.taxAmount,
        tx.serviceCharge,
        tx.totalAmount,
        tx.paidAmount,
        tx.changeAmount,
        tx.debtAmount,
        _csvEscape(tx.status),
        _csvEscape(tx.notes),
      ].join(','));
    }
    return sb.toString();
  }

  String generateProfitLossCsv(
    ProfitLossSummary summary, {
    required String storeName,
  }) {
    final sb = StringBuffer();
    sb.writeln('Laporan Laba Rugi,${_csvEscape(storeName)}');
    sb.writeln(
        'Periode,${_dateFormat.format(summary.periodStart)} - ${_dateFormat.format(summary.periodEnd)}');
    sb.writeln('');
    sb.writeln('Komponen,Nilai (IDR)');
    sb.writeln('Jumlah Transaksi,${summary.transactionCount}');
    sb.writeln('Penjualan Kotor (Gross Sales),${summary.grossSales}');
    sb.writeln('Total Diskon,${summary.discountTotal}');
    sb.writeln('Total Pajak,${summary.taxTotal}');
    sb.writeln('Total Biaya Layanan,${summary.serviceChargeTotal}');
    sb.writeln('Omzet Bersih (Net Sales),${summary.netSales}');
    sb.writeln('Total HPP (COGS),${summary.totalCogs}');
    sb.writeln('Laba Kotor (Gross Profit),${summary.grossProfit}');
    sb.writeln('Total Pengeluaran Operasional,${summary.totalExpenses}');
    sb.writeln('Laba Bersih (Net Profit),${summary.netProfit}');
    sb.writeln('');
    sb.writeln('Komposisi Pembayaran,Nominal');
    summary.paymentBreakdown.forEach((method, amount) {
      sb.writeln('${_csvEscape(method.toUpperCase())},$amount');
    });
    sb.writeln('');
    sb.writeln('Produk Terlaris,Qty,Omzet,Margin');
    for (final prod in summary.topProducts) {
      sb.writeln([
        _csvEscape((prod['product_name'] ?? '').toString()),
        prod['total_qty'] ?? 0,
        prod['total_revenue'] ?? 0,
        prod['total_margin'] ?? 0,
      ].join(','));
    }
    return sb.toString();
  }

  // =========================================================================
  // PDF GENERATORS (RECEIPT & PROFIT/LOSS REPORT)
  // =========================================================================

  Future<Uint8List> buildReceiptPdf({
    required StoreConfig store,
    required PosTransaction transaction,
    required List<PosTransactionItem> items,
    required List<TransactionPayment> payments,
    int paperWidthMm = 58,
    String? cashierName,
    String? customerName,
  }) async {
    final doc = pw.Document();
    final sym = store.currencySymbol;
    final dt =
        DateTime.tryParse(transaction.createdAt)?.toLocal() ?? DateTime.now();

    final pageWidth = paperWidthMm >= 80 ? 80.0 : 58.0;
    final pageFormat = PdfPageFormat(
      pageWidth * PdfPageFormat.mm,
      double.infinity,
      marginAll: 3 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  store.name,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (store.address.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    store.address,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                ),
              if (store.phone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Telp: ${store.phone}',
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                ),
              pw.Divider(thickness: 0.5),
              _pdfRow('No', transaction.invoiceNo, fontSize: 7.5),
              _pdfRow('Tanggal', _dateTimeFormat.format(dt), fontSize: 7.5),
              if (cashierName != null && cashierName.isNotEmpty)
                _pdfRow('Kasir', cashierName, fontSize: 7.5),
              if (customerName != null && customerName.isNotEmpty)
                _pdfRow('Pelanggan', customerName, fontSize: 7.5),
              pw.Divider(thickness: 0.5),
              ...items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item.productName,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        _pdfRow(
                          '${item.qty == item.qty.roundToDouble() ? item.qty.toInt() : item.qty} x ${_fmtMoney(item.unitPrice, sym)}',
                          _fmtMoney(item.subtotal, sym),
                          fontSize: 7.5,
                        ),
                        if (item.itemNotes.isNotEmpty)
                          pw.Text(
                            'Catatan: ${item.itemNotes}',
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                      ],
                    ),
                  )),
              pw.Divider(thickness: 0.5),
              _pdfRow('Subtotal', _fmtMoney(transaction.subtotal, sym),
                  fontSize: 8),
              if (transaction.discountAmount > 0)
                _pdfRow(
                    'Diskon', '-${_fmtMoney(transaction.discountAmount, sym)}',
                    fontSize: 8),
              if (transaction.serviceCharge > 0)
                _pdfRow('Layanan', _fmtMoney(transaction.serviceCharge, sym),
                    fontSize: 8),
              if (transaction.taxAmount > 0)
                _pdfRow('Pajak', _fmtMoney(transaction.taxAmount, sym),
                    fontSize: 8),
              pw.SizedBox(height: 2),
              _pdfRow(
                'TOTAL',
                _fmtMoney(transaction.totalAmount, sym),
                fontSize: 9.5,
                bold: true,
              ),
              pw.Divider(thickness: 0.5),
              ...payments.map((pay) => _pdfRow(
                    pay.methodLabel,
                    _fmtMoney(pay.amount, sym),
                    fontSize: 7.5,
                  )),
              if (transaction.changeAmount > 0)
                _pdfRow(
                  'Kembali',
                  _fmtMoney(transaction.changeAmount, sym),
                  fontSize: 8,
                  bold: true,
                ),
              if (transaction.debtAmount > 0)
                _pdfRow(
                  'Sisa Kasbon',
                  _fmtMoney(transaction.debtAmount, sym),
                  fontSize: 8,
                  bold: true,
                ),
              pw.Divider(thickness: 0.5),
              if (store.receiptFooter.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    store.receiptFooter,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildProfitLossPdf({
    required StoreConfig store,
    required ProfitLossSummary summary,
  }) async {
    final doc = pw.Document();
    final sym = store.currencySymbol;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'LAPORAN LABA RUGI',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${store.name} • ${_dateFormat.format(summary.periodStart)} s/d ${_dateFormat.format(summary.periodEnd)}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Komponen Keuangan', 'Nominal'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            data: [
              ['Jumlah Transaksi', '${summary.transactionCount} transaksi'],
              ['Penjualan Kotor', _fmtMoney(summary.grossSales, sym)],
              ['Total Diskon', '-${_fmtMoney(summary.discountTotal, sym)}'],
              [
                'Pajak & Layanan',
                _fmtMoney(summary.taxTotal + summary.serviceChargeTotal, sym)
              ],
              ['Omzet Bersih (Net Sales)', _fmtMoney(summary.netSales, sym)],
              ['Total HPP (COGS)', '-${_fmtMoney(summary.totalCogs, sym)}'],
              [
                'Laba Kotor (${summary.grossMarginPercent.toStringAsFixed(1)}%)',
                _fmtMoney(summary.grossProfit, sym)
              ],
              [
                'Beban Operasional',
                '-${_fmtMoney(summary.totalExpenses, sym)}'
              ],
              [
                'LABA BERSIH (${summary.netMarginPercent.toStringAsFixed(1)}%)',
                _fmtMoney(summary.netProfit, sym)
              ],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Komposisi Metode Pembayaran',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Metode', 'Nominal'],
            data: summary.paymentBreakdown.entries
                .map((e) => [e.key.toUpperCase(), _fmtMoney(e.value, sym)])
                .toList(),
          ),
          if (summary.topProducts.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Top 5 Produk Terlaris',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Produk', 'Qty', 'Omzet', 'Margin'],
              data: summary.topProducts
                  .map((prod) => [
                        (prod['product_name'] ?? '').toString(),
                        '${prod['total_qty'] ?? 0}',
                        _fmtMoney(
                            (prod['total_revenue'] as num?)?.toInt() ?? 0, sym),
                        _fmtMoney(
                            (prod['total_margin'] as num?)?.toInt() ?? 0, sym),
                      ])
                  .toList(),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfRow(
    String left,
    String right, {
    double fontSize = 8,
    bool bold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(left, style: style)),
        pw.Text(right, style: style),
      ],
    );
  }

  // =========================================================================
  // SHARE FILES & BACKUP / RESTORE JSON
  // =========================================================================

  Future<File> writeTempFile(String fileName, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> shareBytesFile({
    required String fileName,
    required List<int> bytes,
    String? subject,
    String? text,
  }) async {
    final file = await writeTempFile(fileName, bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text: text,
    );
  }

  Future<void> shareTextFile({
    required String fileName,
    required String content,
    String? subject,
    String? text,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content, flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text: text,
    );
  }

  Future<void> shareTransactionsCsv(
    List<PosTransaction> transactions, {
    String currencySymbol = 'Rp',
  }) async {
    final csv = generateTransactionsCsv(
      transactions,
      currencySymbol: currencySymbol,
    );
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    await shareTextFile(
      fileName: 'transaksi_pos_$stamp.csv',
      content: csv,
      subject: 'Ekspor Transaksi POS',
    );
  }

  Future<void> shareProfitLossCsv(
    ProfitLossSummary summary, {
    required String storeName,
  }) async {
    final csv = generateProfitLossCsv(summary, storeName: storeName);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    await shareTextFile(
      fileName: 'laba_rugi_$stamp.csv',
      content: csv,
      subject: 'Laporan Laba Rugi $storeName',
    );
  }

  Future<void> shareProfitLossPdf({
    required StoreConfig store,
    required ProfitLossSummary summary,
  }) async {
    final bytes = await buildProfitLossPdf(store: store, summary: summary);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    await shareBytesFile(
      fileName: 'laporan_laba_rugi_$stamp.pdf',
      bytes: bytes,
      subject: 'Laporan Laba Rugi ${store.name}',
    );
  }

  /// Ekspor seluruh database SQLite (17 tabel) menjadi file JSON dan bagikan
  Future<File> exportBackupJsonAndShare() async {
    final jsonString = await DbHelper.instance.exportFullBackupJson();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'kasirpro_backup_$stamp.json';
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(jsonString, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Backup Database KasirPro POS',
      text: 'Backup lengkap data toko ($fileName)',
    );
    return file;
  }

  /// Pilih file JSON via FilePicker lalu restore atomik ke SQLite
  Future<bool> pickAndRestoreBackupJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return false;
    }
    final picked = result.files.first;
    String jsonContent;
    if (picked.bytes != null) {
      jsonContent = String.fromCharCodes(picked.bytes!);
    } else if (picked.path != null) {
      jsonContent = await File(picked.path!).readAsString();
    } else {
      throw StateError('File backup tidak dapat dibaca');
    }
    await DbHelper.instance.importFullBackupJson(jsonContent);
    return true;
  }
}
