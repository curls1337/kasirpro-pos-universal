import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/pos_models.dart';

class EscPosService {
  EscPosService._internal();
  static final EscPosService instance = EscPosService._internal();
  factory EscPosService() => instance;

  static final NumberFormat _idrFormat = NumberFormat.decimalPattern('id_ID');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  static const List<int> _cmdInit = [0x1B, 0x40];
  static const List<int> _cmdResetLeftMargin = [0x1D, 0x4C, 0x00, 0x00];
  static const List<int> _cmdAlignLeft = [0x1B, 0x61, 0x00];
  static const List<int> _cmdAlignCenter = [0x1B, 0x61, 0x01];
  static const List<int> _cmdBoldOn = [0x1B, 0x45, 0x01];
  static const List<int> _cmdBoldOff = [0x1B, 0x45, 0x00];
  static const List<int> _cmdTextNormal = [0x1D, 0x21, 0x00];
  static const List<int> _cmdTextDoubleHeight = [0x1D, 0x21, 0x01];
  static const List<int> _cmdTextDoubleBoth = [0x1D, 0x21, 0x11];
  static const List<int> _cmdCutPartial = [0x1D, 0x56, 0x42, 0x00];
  static const List<int> _cmdOpenDrawer = [0x1B, 0x70, 0x00, 0x19, 0xFA];

  /// Reset printer (`ESC @`), margin kiri 0 (`GS L 0 0`), dan lebar area cetak (`GS W`)
  List<int> _buildInitWithLayout(int paperWidthMm) {
    // 58mm = 384 dots (0x0180), 80mm = 576 dots (0x0240)
    final dots = paperWidthMm >= 80 ? 576 : 384;
    final nL = dots & 0xFF;
    final nH = (dots >> 8) & 0xFF;
    return [
      ..._cmdInit,
      ..._cmdResetLeftMargin,
      0x1D,
      0x57,
      nL,
      nH,
    ];
  }

  /// Native ESC/POS QR Code Model 2 (`GS ( k`)
  List<int> _buildEscPosQrCode(String data, {int moduleSize = 4}) {
    final qrBytes = utf8.encode(data);
    final pLen = qrBytes.length + 3;
    final pL = pLen & 0xFF;
    final pH = (pLen >> 8) & 0xFF;
    final safeSize = moduleSize.clamp(2, 8);
    return [
      // 1. Select QR Code Model 2 (cn=49, fn=65, n1=50, n2=0)
      0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
      // 2. Set module size (cn=49, fn=67, n=safeSize)
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, safeSize,
      // 3. Set error correction level M (cn=49, fn=69, n=49)
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31,
      // 4. Store QR data in symbol storage area (cn=49, fn=80, m=48)
      0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30,
      ...qrBytes,
      // 5. Print QR Code symbol (cn=49, fn=81, m=48)
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
    ];
  }

  /// Perintah ESC/POS membuka laci kas (RJ11 Cash Drawer Kick)
  Uint8List buildOpenDrawerCommand() => Uint8List.fromList(_cmdOpenDrawer);

  String _fmtMoney(int amount, String symbol) {
    final neg = amount < 0 ? '-' : '';
    return '$neg$symbol ${_idrFormat.format(amount.abs())}';
  }

  String _fmtQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }

  int _lineWidth(int paperWidthMm) => paperWidthMm >= 80 ? 48 : 32;

  List<int> _encodeLine(String text) {
    final safe = _sanitizeAscii(text);
    return [...latin1.encode(safe), 0x0A];
  }

  String _sanitizeAscii(String text) {
    return text
        .replaceAll('×', 'x')
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
  }

  String _twoColumn(String left, String right, int width) {
    final l = _sanitizeAscii(left);
    final r = _sanitizeAscii(right);
    if (l.length + r.length + 1 <= width) {
      final spaces = width - l.length - r.length;
      return '$l${' ' * spaces}$r';
    }
    final maxLeft = (width - r.length - 1).clamp(4, width);
    final truncatedLeft = l.length > maxLeft ? l.substring(0, maxLeft) : l;
    final spaces = (width - truncatedLeft.length - r.length).clamp(1, width);
    return '$truncatedLeft${' ' * spaces}$r';
  }

  String _divider(int width, [String char = '-']) => char * width;

  List<String> _wrapText(String text, int width) {
    final clean = _sanitizeAscii(text).trim();
    if (clean.isEmpty) return [];
    final words = clean.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = StringBuffer();
    for (final w in words) {
      if (current.isEmpty) {
        current.write(w);
      } else if (current.length + 1 + w.length <= width) {
        current.write(' $w');
      } else {
        lines.add(current.toString());
        current = StringBuffer(w);
      }
    }
    if (current.isNotEmpty) lines.add(current.toString());
    return lines;
  }

  /// Build Struk Penjualan 58mm (32 char) atau 80mm (48 char)
  Uint8List buildReceipt58or80({
    required StoreConfig store,
    required PosTransaction transaction,
    required List<PosTransactionItem> items,
    required List<TransactionPayment> payments,
    int paperWidthMm = 58,
    String? cashierName,
    String? customerName,
    bool autoCut = true,
    bool openDrawer = false,
  }) {
    final width = _lineWidth(paperWidthMm);
    final sym = store.currencySymbol;
    final out = <int>[];

    out.addAll(_buildInitWithLayout(paperWidthMm));
    if (openDrawer) {
      out.addAll(_cmdOpenDrawer);
    }

    out.addAll(_cmdAlignCenter);
    out.addAll(_cmdBoldOn);
    out.addAll(_cmdTextDoubleHeight);
    out.addAll(_encodeLine(store.name));
    out.addAll(_cmdTextNormal);
    out.addAll(_cmdBoldOff);

    if (store.address.trim().isNotEmpty) {
      for (final line in _wrapText(store.address, width)) {
        out.addAll(_encodeLine(line));
      }
    }
    if (store.phone.trim().isNotEmpty) {
      out.addAll(_encodeLine('Telp: ${store.phone}'));
    }

    out.addAll(_cmdAlignLeft);
    out.addAll(_encodeLine(_divider(width)));

    final dt =
        DateTime.tryParse(transaction.createdAt)?.toLocal() ?? DateTime.now();
    out.addAll(_encodeLine(_twoColumn('No:', transaction.invoiceNo, width)));
    out.addAll(
        _encodeLine(_twoColumn('Tgl:', _dateTimeFormat.format(dt), width)));
    if (cashierName != null && cashierName.isNotEmpty) {
      out.addAll(_encodeLine(_twoColumn('Kasir:', cashierName, width)));
    }
    if (customerName != null && customerName.isNotEmpty) {
      out.addAll(_encodeLine(_twoColumn('Pelanggan:', customerName, width)));
    }
    if (transaction.orderType != 'retail') {
      final tablePart = transaction.tableNumber.isNotEmpty
          ? ' (Meja ${transaction.tableNumber})'
          : '';
      out.addAll(_encodeLine(
          _twoColumn('Order:', '${transaction.orderType.toUpperCase()}$tablePart', width)));
    }
    out.addAll(_encodeLine(_divider(width)));

    for (final item in items) {
      out.addAll(_encodeLine(item.productName));
      final qtyLine = '  ${_fmtQty(item.qty)} x ${_fmtMoney(item.unitPrice, sym)}';
      out.addAll(
          _encodeLine(_twoColumn(qtyLine, _fmtMoney(item.subtotal, sym), width)));
      if (item.itemNotes.trim().isNotEmpty) {
        out.addAll(_encodeLine('  * ${item.itemNotes}'));
      }
    }

    out.addAll(_encodeLine(_divider(width)));
    out.addAll(_encodeLine(
        _twoColumn('Subtotal', _fmtMoney(transaction.subtotal, sym), width)));
    if (transaction.discountAmount > 0) {
      out.addAll(_encodeLine(_twoColumn(
          'Diskon', '-${_fmtMoney(transaction.discountAmount, sym)}', width)));
    }
    if (transaction.serviceCharge > 0) {
      out.addAll(_encodeLine(_twoColumn(
          'Layanan', _fmtMoney(transaction.serviceCharge, sym), width)));
    }
    if (transaction.taxAmount > 0) {
      out.addAll(_encodeLine(
          _twoColumn('Pajak', _fmtMoney(transaction.taxAmount, sym), width)));
    }
    out.addAll(_cmdBoldOn);
    out.addAll(_encodeLine(
        _twoColumn('TOTAL', _fmtMoney(transaction.totalAmount, sym), width)));
    out.addAll(_cmdBoldOff);
    out.addAll(_encodeLine(_divider(width)));

    for (final p in payments) {
      out.addAll(_encodeLine(
          _twoColumn(p.methodLabel, _fmtMoney(p.amount, sym), width)));
    }
    if (transaction.changeAmount > 0) {
      out.addAll(_encodeLine(_twoColumn(
          'Kembali', _fmtMoney(transaction.changeAmount, sym), width)));
    }
    if (transaction.debtAmount > 0) {
      out.addAll(_encodeLine(_twoColumn(
          'Sisa Kasbon', _fmtMoney(transaction.debtAmount, sym), width)));
    }

    out.addAll(_encodeLine(_divider(width)));
    out.addAll(_cmdAlignCenter);
    if (store.receiptFooter.trim().isNotEmpty) {
      for (final line in _wrapText(store.receiptFooter, width)) {
        out.addAll(_encodeLine(line));
      }
    }
    out.addAll([0x0A, 0x0A, 0x0A]);
    if (autoCut) out.addAll(_cmdCutPartial);
    return Uint8List.fromList(out);
  }

  /// Build Tiket Dapur F&B
  Uint8List buildKitchenTicket({
    required StoreConfig store,
    required PosTransaction transaction,
    required List<PosTransactionItem> items,
    int paperWidthMm = 58,
    bool autoCut = true,
  }) {
    final width = _lineWidth(paperWidthMm);
    final out = <int>[];

    out.addAll(_buildInitWithLayout(paperWidthMm));
    out.addAll(_cmdAlignCenter);
    out.addAll(_cmdBoldOn);
    out.addAll(_cmdTextDoubleBoth);
    out.addAll(_encodeLine('TIKET DAPUR'));
    out.addAll(_cmdTextNormal);
    out.addAll(_cmdBoldOff);
    out.addAll(_encodeLine(_divider(width, '=')));

    out.addAll(_cmdAlignLeft);
    out.addAll(_encodeLine('Order : ${transaction.invoiceNo}'));
    out.addAll(_encodeLine('Tipe  : ${transaction.orderType.toUpperCase()}'));
    if (transaction.tableNumber.trim().isNotEmpty) {
      out.addAll(_encodeLine('Meja  : ${transaction.tableNumber}'));
    }
    out.addAll(_encodeLine(_divider(width)));

    for (final item in items) {
      out.addAll(_cmdBoldOn);
      out.addAll(_encodeLine('${_fmtQty(item.qty)}x ${item.productName}'));
      out.addAll(_cmdBoldOff);
      if (item.itemNotes.trim().isNotEmpty) {
        out.addAll(_encodeLine('   Catatan: ${item.itemNotes}'));
      }
    }

    out.addAll(_encodeLine(_divider(width)));
    out.addAll([0x0A, 0x0A, 0x0A]);
    if (autoCut) out.addAll(_cmdCutPartial);
    return Uint8List.fromList(out);
  }

  /// Build Laporan Tutup Shift (Z-Report)
  Uint8List buildShiftReport({
    required StoreConfig store,
    required ShiftSession shift,
    required String cashierName,
    required Map<String, int> summary,
    int paperWidthMm = 58,
    bool autoCut = true,
  }) {
    final width = _lineWidth(paperWidthMm);
    final sym = store.currencySymbol;
    final out = <int>[];

    out.addAll(_buildInitWithLayout(paperWidthMm));
    out.addAll(_cmdAlignCenter);
    out.addAll(_cmdBoldOn);
    out.addAll(_encodeLine(store.name.toUpperCase()));
    out.addAll(_encodeLine('LAPORAN TUTUP SHIFT'));
    out.addAll(_cmdBoldOff);
    out.addAll(_encodeLine(_divider(width)));

    out.addAll(_cmdAlignLeft);
    out.addAll(_encodeLine(_twoColumn('Kasir:', cashierName, width)));
    out.addAll(_encodeLine(_twoColumn('Status:', shift.status.toUpperCase(), width)));
    out.addAll(_encodeLine(_twoColumn(
        'Modal Awal:', _fmtMoney(summary['opening_cash'] ?? shift.openingCash, sym), width)));
    out.addAll(_encodeLine(_twoColumn(
        'Jual Tunai:', _fmtMoney(summary['cash_sales'] ?? 0, sym), width)));
    out.addAll(_encodeLine(_twoColumn(
        'Non-Tunai:', _fmtMoney(summary['non_cash_sales'] ?? 0, sym), width)));
    out.addAll(_encodeLine(_twoColumn(
        'Kasbon:', _fmtMoney(summary['kasbon_sales'] ?? 0, sym), width)));
    out.addAll(_encodeLine(_twoColumn(
        'Kas Masuk:', _fmtMoney(summary['cash_in'] ?? 0, sym), width)));
    out.addAll(_encodeLine(_twoColumn(
        'Kas Keluar:', _fmtMoney(summary['cash_out'] ?? 0, sym), width)));
    out.addAll(_encodeLine(_divider(width)));
    out.addAll(_encodeLine(_twoColumn(
        'Kas Sistem:', _fmtMoney(shift.expectedCash, sym), width)));
    out.addAll(_encodeLine(_twoColumn(
        'Kas Aktual:', _fmtMoney(shift.actualCash ?? 0, sym), width)));
    out.addAll(_cmdBoldOn);
    out.addAll(_encodeLine(_twoColumn(
        'Selisih:', _fmtMoney(shift.cashDifference, sym), width)));
    out.addAll(_cmdBoldOff);

    if (shift.notes.trim().isNotEmpty) {
      out.addAll(_encodeLine('Catatan: ${shift.notes}'));
    }
    out.addAll(_encodeLine(_divider(width)));
    out.addAll([0x0A, 0x0A, 0x0A]);
    if (autoCut) out.addAll(_cmdCutPartial);
    return Uint8List.fromList(out);
  }

  /// Build Test Print Thermal
  Uint8List buildTestPrint({
    required StoreConfig store,
    int paperWidthMm = 58,
  }) {
    final width = _lineWidth(paperWidthMm);
    final out = <int>[];

    out.addAll(_buildInitWithLayout(paperWidthMm));
    out.addAll(_cmdAlignCenter);
    out.addAll(_cmdBoldOn);
    out.addAll(_encodeLine(store.name.toUpperCase()));
    out.addAll(_cmdBoldOff);
    out.addAll(_encodeLine('TEST PRINT THERMAL ${paperWidthMm}MM'));
    out.addAll(_encodeLine(_divider(width)));

    out.addAll(_cmdAlignLeft);
    out.addAll(_encodeLine(_twoColumn('Status:', 'KONEKSI OK', width)));
    out.addAll(_encodeLine(
        _twoColumn('Waktu:', _dateTimeFormat.format(DateTime.now()), width)));
    out.addAll(_encodeLine(_divider(width)));
    out.addAll(_cmdAlignCenter);
    out.addAll(_encodeLine('KasirPro Universal POS'));
    out.addAll([0x0A, 0x0A, 0x0A]);
    out.addAll(_cmdCutPartial);
    return Uint8List.fromList(out);
  }

  /// Build Slip Tagihan QRIS (Nominal Pas) 58mm atau 80mm dengan Native ESC/POS QR Code
  Uint8List buildQrisPaymentSlip({
    required StoreConfig store,
    required String externalId,
    required double amount,
    required String qrisString,
    int paperWidthMm = 58,
    bool autoCut = true,
  }) {
    final width = _lineWidth(paperWidthMm);
    final sym = store.currencySymbol;
    final out = <int>[];

    out.addAll(_buildInitWithLayout(paperWidthMm));
    out.addAll(_cmdAlignCenter);
    out.addAll(_cmdBoldOn);
    out.addAll(_cmdTextDoubleHeight);
    out.addAll(_encodeLine(store.name));
    out.addAll(_cmdTextNormal);
    out.addAll(_cmdBoldOff);

    if (store.address.trim().isNotEmpty) {
      for (final line in _wrapText(store.address, width)) {
        out.addAll(_encodeLine(line));
      }
    }
    if (store.phone.trim().isNotEmpty) {
      out.addAll(_encodeLine('Telp: ${store.phone}'));
    }

    out.addAll(_cmdAlignLeft);
    out.addAll(_encodeLine(_divider(width)));
    out.addAll(_cmdAlignCenter);
    out.addAll(_cmdBoldOn);
    out.addAll(_encodeLine('TAGIHAN QRIS (NOMINAL PAS)'));
    out.addAll(_cmdBoldOff);
    out.addAll(_cmdAlignLeft);
    out.addAll(_encodeLine(_divider(width)));

    out.addAll(_encodeLine(_twoColumn('ID:', externalId, width)));
    out.addAll(
      _encodeLine(_twoColumn('Waktu:', _dateTimeFormat.format(DateTime.now()), width)),
    );
    out.addAll(_cmdBoldOn);
    out.addAll(
      _encodeLine(_twoColumn('Nominal:', _fmtMoney(amount.round(), sym), width)),
    );
    out.addAll(_cmdBoldOff);
    out.addAll(_encodeLine(_divider(width)));

    out.addAll(_cmdAlignCenter);
    out.addAll([0x0A]);
    if (qrisString.trim().isNotEmpty) {
      final moduleSize = paperWidthMm >= 80 ? 6 : 4;
      out.addAll(_buildEscPosQrCode(qrisString.trim(), moduleSize: moduleSize));
      out.addAll([0x0A]);
    } else {
      out.addAll(_encodeLine('[QRIS STRING KOSONG]'));
    }

    out.addAll(_encodeLine('Scan QRIS di atas dengan'));
    out.addAll(_encodeLine('Mobile Banking / E-Wallet'));
    out.addAll(_cmdBoldOn);
    out.addAll(_encodeLine('Nominal sudah pas & otomatis'));
    out.addAll(_cmdBoldOff);
    out.addAll([0x0A, 0x0A, 0x0A]);
    if (autoCut) out.addAll(_cmdCutPartial);
    return Uint8List.fromList(out);
  }
}
