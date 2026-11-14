import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import '../data/db_helper.dart';
import '../models/pos_models.dart';
import 'escpos_service.dart';
import 'export_service.dart';
import 'tspl_label_service.dart';

class BluetoothDeviceItem {
  final String name;
  final String macAddress;

  const BluetoothDeviceItem({
    required this.name,
    required this.macAddress,
  });
}

class PrintResult {
  final bool success;
  final String message;

  const PrintResult({required this.success, required this.message});
}

class PrinterManager {
  PrinterManager._internal();
  static final PrinterManager instance = PrinterManager._internal();
  factory PrinterManager() => instance;

  Future<bool> ensureBluetoothPermissions() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetooth,
      ].request();
      final connectGranted =
          statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final legacyGranted =
          statuses[Permission.bluetooth]?.isGranted ?? false;
      if (connectGranted || legacyGranted) {
        return true;
      }
    }
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }
    return await PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get isBluetoothConnected async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  /// Pindai perangkat Bluetooth yang sudah dipairing
  Future<List<BluetoothDeviceItem>> scanBluetoothDevices() async {
    await ensureBluetoothPermissions();
    final paired = await PrintBluetoothThermal.pairedBluetooths;
    return paired
        .map((d) => BluetoothDeviceItem(
              name: d.name.isEmpty ? 'Thermal Printer' : d.name,
              macAddress: d.macAdress,
            ))
        .toList();
  }

  Future<bool> connectBluetooth(String macAddress) async {
    if (macAddress.trim().isEmpty) return false;
    await ensureBluetoothPermissions();
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress.trim());
  }

  Future<bool> disconnectBluetooth() async {
    return PrintBluetoothThermal.disconnect;
  }

  /// Kirim raw bytes (ESC/POS atau TSPL/CPCL) ke printer Bluetooth atau WiFi TCP :9100
  Future<PrintResult> sendRawBytes(
    PrinterConfig config,
    Uint8List bytes,
  ) async {
    try {
      if (config.connectionType == 'bluetooth') {
        if (config.addressOrIp.trim().isEmpty) {
          return const PrintResult(
            success: false,
            message: 'Alamat MAC Bluetooth printer belum diatur.',
          );
        }
        var connected = await isBluetoothConnected;
        if (!connected) {
          connected = await connectBluetooth(config.addressOrIp);
        }
        if (!connected) {
          return PrintResult(
            success: false,
            message: 'Gagal terhubung ke Bluetooth printer ${config.name}.',
          );
        }
        final ok = await PrintBluetoothThermal.writeBytes(bytes.toList());
        return PrintResult(
          success: ok,
          message: ok
              ? 'Berhasil mencetak ke ${config.name}'
              : 'Printer Bluetooth tidak merespons.',
        );
      }

      if (config.connectionType == 'wifi_tcp') {
        final ip = config.addressOrIp.trim();
        if (ip.isEmpty) {
          return const PrintResult(
            success: false,
            message: 'Alamat IP printer belum diatur.',
          );
        }
        final socket = await Socket.connect(
          ip,
          config.port > 0 ? config.port : 9100,
          timeout: const Duration(seconds: 5),
        );
        try {
          socket.add(bytes);
          await socket.flush();
        } finally {
          await socket.close();
        }
        return PrintResult(
          success: true,
          message: 'Berhasil dikirim ke $ip:${config.port}',
        );
      }

      return const PrintResult(
        success: false,
        message: 'Tipe koneksi bukan raw thermal.',
      );
    } catch (e) {
      return PrintResult(
        success: false,
        message: 'Error cetak: $e',
      );
    }
  }

  /// Routing otomatis cetak struk ke printer role 'receipt' (atau PDF fallback)
  Future<PrintResult> printReceipt({
    required StoreConfig store,
    required PosTransaction transaction,
    required List<PosTransactionItem> items,
    required List<TransactionPayment> payments,
    PrinterConfig? overrideConfig,
    String? cashierName,
    String? customerName,
  }) async {
    final config =
        overrideConfig ?? await DbHelper.instance.getDefaultPrinter('receipt');

    if (config == null || config.connectionType == 'system_pdf') {
      final pdfBytes = await ExportService.instance.buildReceiptPdf(
        store: store,
        transaction: transaction,
        items: items,
        payments: payments,
        paperWidthMm: config?.paperWidthMm ?? 58,
        cashierName: cashierName,
        customerName: customerName,
      );
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      return const PrintResult(
        success: true,
        message: 'Dialog cetak PDF struk dibuka.',
      );
    }

    final hasCashPayment = payments.any((p) => p.method == 'cash');
    final bytes = EscPosService.instance.buildReceipt58or80(
      store: store,
      transaction: transaction,
      items: items,
      payments: payments,
      paperWidthMm: config.paperWidthMm,
      cashierName: cashierName,
      customerName: customerName,
      autoCut: true,
      openDrawer: config.openDrawer && hasCashPayment,
    );
    return sendRawBytes(config, bytes);
  }

  /// Routing otomatis cetak tiket dapur (F&B) ke printer role 'kitchen'
  Future<PrintResult> printKitchenTicket({
    required StoreConfig store,
    required PosTransaction transaction,
    required List<PosTransactionItem> items,
    PrinterConfig? overrideConfig,
  }) async {
    final config =
        overrideConfig ?? await DbHelper.instance.getDefaultPrinter('kitchen');
    if (config == null) {
      return const PrintResult(
        success: false,
        message: 'Printer Dapur belum dikonfigurasi.',
      );
    }
    if (config.connectionType == 'system_pdf') {
      final pdfBytes = await ExportService.instance.buildReceiptPdf(
        store: store,
        transaction: transaction,
        items: items,
        payments: const [],
        paperWidthMm: config.paperWidthMm,
      );
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      return const PrintResult(
        success: true,
        message: 'Tiket dapur dikirim ke System Print.',
      );
    }
    final bytes = EscPosService.instance.buildKitchenTicket(
      store: store,
      transaction: transaction,
      items: items,
      paperWidthMm: config.paperWidthMm,
    );
    return sendRawBytes(config, bytes);
  }

  /// Routing cetak laporan tutup shift
  Future<PrintResult> printShiftReport({
    required StoreConfig store,
    required ShiftSession shift,
    required String cashierName,
    required Map<String, int> summary,
    PrinterConfig? overrideConfig,
  }) async {
    final config =
        overrideConfig ?? await DbHelper.instance.getDefaultPrinter('receipt');
    if (config == null || config.connectionType == 'system_pdf') {
      return const PrintResult(
        success: false,
        message: 'Hubungkan printer thermal struk untuk cetak laporan shift.',
      );
    }
    final bytes = EscPosService.instance.buildShiftReport(
      store: store,
      shift: shift,
      cashierName: cashierName,
      summary: summary,
      paperWidthMm: config.paperWidthMm,
    );
    return sendRawBytes(config, bytes);
  }

  /// Routing otomatis cetak label barcode ke printer role 'label' (TSPL / CPCL / PDF)
  Future<PrintResult> printLabels({
    required List<ProductItem> products,
    required LabelSizePreset preset,
    Map<int, int>? copiesPerProduct,
    StoreConfig? store,
    PrinterConfig? overrideConfig,
    bool showStoreName = true,
    bool showPrice = true,
    bool showSku = true,
  }) async {
    if (products.isEmpty) {
      return const PrintResult(
        success: false,
        message: 'Pilih minimal 1 produk untuk dicetak labelnya.',
      );
    }
    final config =
        overrideConfig ?? await DbHelper.instance.getDefaultPrinter('label');

    if (config == null ||
        config.connectionType == 'system_pdf' ||
        config.commandLang == 'pdf') {
      final pdfBytes = await TsplLabelService.instance.buildLabelPdfBytes(
        products: products,
        preset: preset,
        copiesPerProduct: copiesPerProduct,
        storeName: store?.name,
        currencySymbol: store?.currencySymbol ?? 'Rp',
        showStoreName: showStoreName,
        showPrice: showPrice,
        showSku: showSku,
      );
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      return const PrintResult(
        success: true,
        message: 'Label barcode PDF siap dicetak.',
      );
    }

    for (final product in products) {
      final copies = copiesPerProduct?[product.id] ?? 1;
      final Uint8List bytes = config.commandLang == 'cpcl'
          ? TsplLabelService.instance.buildCpclLabelCommands(
              product: product,
              preset: preset,
              copies: copies,
              storeName: store?.name,
              currencySymbol: store?.currencySymbol ?? 'Rp',
              showStoreName: showStoreName,
              showPrice: showPrice,
            )
          : TsplLabelService.instance.buildTsplLabelCommands(
              product: product,
              preset: preset,
              copies: copies,
              storeName: store?.name,
              currencySymbol: store?.currencySymbol ?? 'Rp',
              showStoreName: showStoreName,
              showPrice: showPrice,
              showSku: showSku,
            );

      final res = await sendRawBytes(config, bytes);
      if (!res.success) return res;
    }

    return PrintResult(
      success: true,
      message: 'Label berhasil dicetak ke ${config.name}.',
    );
  }

  /// Trigger buka laci kas (Cash Drawer Kick)
  Future<PrintResult> openCashDrawer({PrinterConfig? overrideConfig}) async {
    final config =
        overrideConfig ?? await DbHelper.instance.getDefaultPrinter('receipt');
    if (config == null || config.connectionType == 'system_pdf') {
      return const PrintResult(
        success: false,
        message: 'Printer struk thermal belum terhubung.',
      );
    }
    return sendRawBytes(
      config,
      EscPosService.instance.buildOpenDrawerCommand(),
    );
  }

  /// Test Print Struk atau Label
  Future<PrintResult> testPrint(PrinterConfig config, StoreConfig store) async {
    if (config.roleType == 'label') {
      final sampleProduct = ProductItem.create(
        name: 'Test Label Produk',
        sku: 'TEST-001',
        barcode: '8990001234567',
        sellPrice: 15000,
      );
      return printLabels(
        products: [sampleProduct],
        preset: LabelSizePreset.fromCode(config.labelSize),
        store: store,
        overrideConfig: config,
      );
    }

    if (config.connectionType == 'system_pdf') {
      final dummyTx = PosTransaction(
        invoiceNo: 'TEST-PRINT',
        subtotal: 10000,
        totalAmount: 10000,
        paidAmount: 10000,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      final pdfBytes = await ExportService.instance.buildReceiptPdf(
        store: store,
        transaction: dummyTx,
        items: const [
          PosTransactionItem(
            productName: 'Test Item Struk',
            qty: 1,
            unitPrice: 10000,
            subtotal: 10000,
          ),
        ],
        payments: [
          TransactionPayment(
            method: 'cash',
            amount: 10000,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ],
        paperWidthMm: config.paperWidthMm,
      );
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      return const PrintResult(
        success: true,
        message: 'Test Print PDF dibuka.',
      );
    }

    final bytes = EscPosService.instance.buildTestPrint(
      store: store,
      paperWidthMm: config.paperWidthMm,
    );
    return sendRawBytes(config, bytes);
  }
}
