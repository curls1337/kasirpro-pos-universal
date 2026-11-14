import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db_helper.dart';
import '../models/pos_models.dart';
import '../services/auth_service.dart';
import '../services/bca_gateway_service.dart';
import '../services/export_service.dart';
import '../services/printer_manager.dart';

/// Entri pembayaran sementara di sheet kasir untuk mendukung Split Payment
class PaymentEntry {
  final String method; // 'cash' | 'qris' | 'transfer' | 'debit' | 'kasbon'
  final int amount;
  final String referenceNo;

  const PaymentEntry({
    required this.method,
    required this.amount,
    this.referenceNo = '',
  });
}

class PosController extends ChangeNotifier {
  static const String _prefDarkThemeKey = 'pos_dark_theme';

  final DbHelper _db = DbHelper.instance;
  final AuthService _auth = AuthService.instance;
  final PrinterManager _printerManager = PrinterManager.instance;
  final ExportService _export = ExportService.instance;
  final BcaGatewayService _bcaGateway = BcaGatewayService();

  bool isLoading = true;
  bool isInitialized = false;
  String? errorMessage;
  ThemeMode themeMode = ThemeMode.light;

  StoreConfig? store;
  AppUser? activeUser;
  List<AppUser> users = [];

  ShiftSession? activeShift;
  List<ShiftSession> shiftHistory = [];
  List<CashFlowItem> activeShiftCashFlows = [];

  List<CategoryItem> categories = [];
  List<ProductItem> products = [];
  List<StockMovement> stockMovements = [];
  List<CustomerItem> customers = [];
  List<SupplierItem> suppliers = [];
  List<PurchaseOrder> purchases = [];
  List<ExpenseItem> expenses = [];
  List<HeldCart> heldCarts = [];
  List<PrinterConfig> printerConfigs = [];
  List<PosTransaction> recentTransactions = [];

  // Cart state
  final List<CartItem> cart = [];
  String orderType = 'retail'; // 'retail' | 'dine_in' | 'takeaway' | 'service'
  String tableNumber = '';
  CustomerItem? selectedCustomer;
  int cartDiscountAmount = 0;
  String cartNotes = '';
  int? loadedHeldCartId;

  String get currencySymbol => store?.currencySymbol ?? 'Rp';

  PrinterConfig? get defaultReceiptPrinter {
    for (final p in printerConfigs) {
      if (p.roleType == 'receipt' && p.isDefault) return p;
    }
    for (final p in printerConfigs) {
      if (p.roleType == 'receipt') return p;
    }
    return null;
  }

  PrinterConfig? get defaultLabelPrinter {
    for (final p in printerConfigs) {
      if (p.roleType == 'label' && p.isDefault) return p;
    }
    for (final p in printerConfigs) {
      if (p.roleType == 'label') return p;
    }
    return null;
  }

  PrinterConfig? get defaultKitchenPrinter {
    for (final p in printerConfigs) {
      if (p.roleType == 'kitchen' && p.isDefault) return p;
    }
    for (final p in printerConfigs) {
      if (p.roleType == 'kitchen') return p;
    }
    return null;
  }

  /// Inisialisasi root saat aplikasi dibuka
  Future<void> initApp() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_prefDarkThemeKey) ?? false;
      themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

      isInitialized = await _db.isStoreInitialized();
      if (isInitialized) {
        store = await _db.getStoreConfig();
        users = await _db.getUsers(activeOnly: false);
        printerConfigs = await _db.getPrinterConfigs();
        if (store?.businessType == 'fnb') {
          orderType = 'dine_in';
        } else if (store?.businessType == 'service') {
          orderType = 'service';
        } else {
          orderType = 'retail';
        }
      }
    } catch (e) {
      errorMessage = 'Gagal memuat database: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Setup pertama kali toko + akun owner
  Future<bool> completeSetup({
    required String storeName,
    required String businessType,
    required String address,
    required String phone,
    required double taxPercent,
    required double serviceChargePercent,
    required String currencySymbol,
    required String receiptFooter,
    required String ownerName,
    required String ownerPin,
    String gatewayUrl = '',
    String gatewayApiKey = '',
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final salt = _auth.generateSalt();
      final hash = _auth.hashPin(ownerPin, salt);
      final newStore = StoreConfig.create(
        name: storeName.trim(),
        businessType: businessType,
        address: address.trim(),
        phone: phone.trim(),
        taxPercent: taxPercent,
        serviceChargePercent: serviceChargePercent,
        currencySymbol:
            currencySymbol.trim().isEmpty ? 'Rp' : currencySymbol.trim(),
        receiptFooter: receiptFooter.trim(),
        gatewayUrl: gatewayUrl.trim(),
        gatewayApiKey: gatewayApiKey.trim(),
      );
      final ownerUser = AppUser(
        name: ownerName.trim(),
        role: 'owner',
        pinHash: hash,
        pinSalt: salt,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await _db.initializeStoreAndOwner(
        store: newStore,
        owner: ownerUser,
      );
      await initApp();
      return true;
    } catch (e) {
      errorMessage = 'Gagal menyimpan setup toko: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verifikasi PIN login staff/owner
  Future<bool> loginWithPin(AppUser user, String pin) async {
    final result = _auth.authenticate(user, pin);
    if (!result.success) {
      errorMessage = result.message;
      return false;
    }
    activeUser = user;
    await refreshOperationalData();
    notifyListeners();
    return true;
  }

  /// Kunci layar kembali ke PIN Lock Screen
  void lockTerminal() {
    _auth.logout();
    activeUser = null;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefDarkThemeKey, themeMode == ThemeMode.dark);
    } catch (_) {}
  }

  /// RBAC Guard melalui AuthService
  bool canAccess(String permission) {
    final user = activeUser;
    switch (permission) {
      case 'pos':
        return _auth.canAccessPos(user);
      case 'shift_self':
        return _auth.canManageShift(user);
      case 'customers':
        return _auth.canManageCustomersAndDebt(user);
      case 'kitchen':
        return _auth.canAccessKitchen(user);
      case 'inventory_edit':
        return _auth.canManageInventory(user);
      case 'inventory_view':
        return _auth.canViewInventory(user);
      case 'suppliers':
      case 'expenses':
        return _auth.canManageSuppliersAndExpenses(user);
      case 'reports':
        return _auth.canViewReports(user);
      case 'void_tx':
        return _auth.canViewAllShiftsAndVoid(user);
      case 'settings_admin':
      case 'staff_manage':
      case 'backup_restore':
        return _auth.canManageSettingsAndStaff(user);
      default:
        return false;
    }
  }

  /// Muat seluruh data operasional dari SQLite
  Future<void> refreshOperationalData() async {
    try {
      store = await _db.getStoreConfig();
      users = await _db.getUsers(activeOnly: false);
      categories = await _db.getCategories();
      products = await _db.getProducts(activeOnly: false);
      stockMovements = await _db.getStockMovements(limit: 100);
      customers = await _db.getCustomers();
      suppliers = await _db.getSuppliers();
      purchases = await _db.getPurchaseOrders();
      expenses = await _db.getExpenses();
      heldCarts = await _db.getHeldCarts();
      printerConfigs = await _db.getPrinterConfigs();
      recentTransactions = await _db.getTransactions(limit: 150);
      shiftHistory = await _db.getShifts(limit: 50);

      if (activeUser != null) {
        activeShift = await _db.getOpenShift(userId: activeUser!.id);
        activeShift ??= await _db.getOpenShift();
        if (activeShift != null && activeShift!.id != null) {
          activeShiftCashFlows = await _db.getCashFlows(activeShift!.id!);
        } else {
          activeShiftCashFlows = [];
        }
      }
    } catch (e) {
      errorMessage = 'Gagal memuat data operasional: $e';
    }
    notifyListeners();
  }

  // =========================================================================
  // CART & CHECKOUT
  // =========================================================================

  int get cartSubtotal =>
      cart.fold<int>(0, (sum, item) => sum + item.subtotal);

  int get cartAfterDiscount =>
      (cartSubtotal - cartDiscountAmount).clamp(0, 1 << 62);

  int get cartServiceCharge {
    final pct = store?.serviceChargePercent ?? 0.0;
    if (pct <= 0) return 0;
    return ((cartAfterDiscount * pct) / 100.0).round();
  }

  int get cartTaxAmount {
    final pct = store?.taxPercent ?? 0.0;
    if (pct <= 0) return 0;
    return (((cartAfterDiscount + cartServiceCharge) * pct) / 100.0).round();
  }

  int get cartGrandTotal =>
      cartAfterDiscount + cartServiceCharge + cartTaxAmount;

  double get cartTotalItems =>
      cart.fold<double>(0, (sum, item) => sum + item.qty);

  void addToCart(ProductItem product, {double qty = 1, String notes = ''}) {
    final idx = cart.indexWhere(
      (c) =>
          c.productId == product.id &&
          c.productName == product.name &&
          c.itemNotes == notes,
    );
    if (idx >= 0) {
      cart[idx] = cart[idx].copyWith(qty: cart[idx].qty + qty);
    } else {
      cart.add(
        CartItem(
          productId: product.id,
          productName: product.name,
          sku: product.sku ?? '',
          unit: product.unit,
          qty: qty,
          unitPrice: product.sellPrice,
          costPrice: product.costPrice,
          itemNotes: notes,
          itemType: product.itemType,
        ),
      );
    }
    notifyListeners();
  }

  ProductItem? findProductByBarcodeOrSku(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final p in products) {
      if (!p.isActive) continue;
      if ((p.barcode ?? '').toLowerCase() == normalized ||
          (p.sku ?? '').toLowerCase() == normalized) {
        return p;
      }
    }
    return null;
  }

  void updateCartItemQty(int index, double qty) {
    if (index < 0 || index >= cart.length) return;
    if (qty <= 0) {
      cart.removeAt(index);
    } else {
      cart[index] = cart[index].copyWith(qty: qty);
    }
    notifyListeners();
  }

  void updateCartItemNotes(int index, String notes) {
    if (index < 0 || index >= cart.length) return;
    cart[index] = cart[index].copyWith(itemNotes: notes);
    notifyListeners();
  }

  void removeCartItem(int index) {
    if (index < 0 || index >= cart.length) return;
    cart.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    selectedCustomer = null;
    cartDiscountAmount = 0;
    cartNotes = '';
    tableNumber = '';
    loadedHeldCartId = null;
    notifyListeners();
  }

  void setOrderType(String type) {
    orderType = type;
    notifyListeners();
  }

  void setTableNumber(String table) {
    tableNumber = table;
    notifyListeners();
  }

  void setSelectedCustomer(CustomerItem? customer) {
    selectedCustomer = customer;
    notifyListeners();
  }

  void setCartDiscount(int amount) {
    cartDiscountAmount = amount.clamp(0, cartSubtotal);
    notifyListeners();
  }

  Future<void> holdCurrentCart(String label) async {
    if (cart.isEmpty) return;
    await _db.saveHeldCart(
      HeldCart(
        cartLabel: label.trim().isEmpty ? 'Pesanan Parkir' : label.trim(),
        orderType: orderType,
        tableNumber: tableNumber,
        customerId: selectedCustomer?.id,
        items: List<CartItem>.from(cart),
        discountAmount: cartDiscountAmount,
        notes: cartNotes,
        userId: activeUser?.id,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    clearCart();
    heldCarts = await _db.getHeldCarts();
    notifyListeners();
  }

  Future<void> resumeHeldCart(HeldCart held) async {
    clearCart();
    orderType = held.orderType;
    tableNumber = held.tableNumber;
    cartDiscountAmount = held.discountAmount;
    cartNotes = held.notes;
    loadedHeldCartId = held.id;

    if (held.customerId != null) {
      for (final c in customers) {
        if (c.id == held.customerId) {
          selectedCustomer = c;
          break;
        }
      }
    }

    cart.addAll(held.items);

    if (held.id != null) {
      await _db.deleteHeldCart(held.id!);
      heldCarts = await _db.getHeldCarts();
    }
    notifyListeners();
  }

  Future<void> deleteHeldCart(int id) async {
    await _db.deleteHeldCart(id);
    heldCarts = await _db.getHeldCarts();
    notifyListeners();
  }

  /// Proses Checkout transaksi + Split Payment + Update Stok + Update Shift + Auto Print
  Future<PosTransaction?> processCheckout({
    required List<PaymentEntry> payments,
    required int paidAmount,
    required int changeAmount,
    required int debtAmount,
    String notes = '',
  }) async {
    if (cart.isEmpty) return null;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final invoiceNo =
          'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final kitchenStatus =
          (orderType == 'dine_in' || orderType == 'takeaway')
              ? 'queued'
              : 'none';
      final items = cart
          .map(
            (c) => PosTransactionItem.fromCartItem(
              c,
              kitchenStatus: kitchenStatus,
            ),
          )
          .toList();

      final txPayments = payments
          .map(
            (p) => TransactionPayment(
              method: p.method,
              amount: p.amount,
              referenceNo: p.referenceNo,
              createdAt: now,
            ),
          )
          .toList();

      final tx = PosTransaction(
        invoiceNo: invoiceNo,
        shiftId: activeShift?.id,
        userId: activeUser?.id,
        customerId: selectedCustomer?.id,
        orderType: orderType,
        tableNumber: tableNumber,
        subtotal: cartSubtotal,
        discountAmount: cartDiscountAmount,
        taxAmount: cartTaxAmount,
        serviceCharge: cartServiceCharge,
        totalAmount: cartGrandTotal,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
        debtAmount: debtAmount,
        status: debtAmount > 0 ? 'partial_debt' : 'completed',
        notes: notes.isEmpty ? cartNotes : notes,
        createdAt: now,
        items: items,
        payments: txPayments,
      );

      final savedTx = await _db.checkoutTransaction(
        transaction: tx,
        items: items,
        payments: txPayments,
      );

      // Auto-print & cash drawer kick jika printer dikonfigurasi
      final receiptCfg = defaultReceiptPrinter;
      if (receiptCfg != null && receiptCfg.autoPrint && store != null) {
        try {
          await _printerManager.printReceipt(
            store: store!,
            transaction: savedTx,
            items: savedTx.items,
            payments: savedTx.payments,
            overrideConfig: receiptCfg,
            cashierName: activeUser?.name ?? 'Kasir',
            customerName: selectedCustomer?.name,
          );
        } catch (_) {
          // Error printer tidak boleh menggagalkan transaksi yang sudah tersimpan
        }
      }

      clearCart();
      await refreshOperationalData();
      return savedTx;
    } catch (e) {
      errorMessage = 'Gagal memproses transaksi: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> voidTransaction(int txId) async {
    if (!canAccess('void_tx')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk membatalkan transaksi.',
      );
    }
    await _db.voidTransaction(txId, userId: activeUser?.id);
    await refreshOperationalData();
  }

  // =========================================================================
  // SHIFT & LACI KAS
  // =========================================================================

  Future<void> openShift(int openingCash, {String notes = ''}) async {
    if (activeUser?.id == null) return;
    await _db.openShift(
      userId: activeUser!.id!,
      openingCash: openingCash,
      notes: notes,
    );
    await refreshOperationalData();
  }

  Future<void> addCashFlow({
    required String type,
    required int amount,
    required String category,
    String notes = '',
  }) async {
    if (activeShift?.id == null) return;
    await _db.addCashFlow(
      CashFlowItem(
        shiftId: activeShift!.id!,
        type: type,
        amount: amount,
        category: category,
        notes: notes,
        userId: activeUser?.id,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    await refreshOperationalData();
  }

  Future<ShiftSession?> closeShift(int actualCash, {String notes = ''}) async {
    if (activeShift?.id == null) return null;
    final shiftId = activeShift!.id!;
    final summary = await _db.getShiftCashSummary(shiftId);
    final closed = await _db.closeShift(
      shiftId: shiftId,
      actualCash: actualCash,
      notes: notes,
    );
    final receiptCfg = defaultReceiptPrinter;
    if (receiptCfg != null && store != null) {
      try {
        await _printerManager.printShiftReport(
          store: store!,
          shift: closed,
          cashierName: activeUser?.name ?? 'Kasir',
          summary: summary,
          overrideConfig: receiptCfg,
        );
      } catch (_) {}
    }
    await refreshOperationalData();
    return closed;
  }

  // =========================================================================
  // PRODUK, KATEGORI & STOK OPNAME
  // =========================================================================

  Future<void> saveCategory(CategoryItem category) async {
    if (category.id == null) {
      await _db.insertCategory(category);
    } else {
      await _db.updateCategory(category);
    }
    await refreshOperationalData();
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
    await refreshOperationalData();
  }

  Future<void> saveProduct(ProductItem product) async {
    if (product.id == null) {
      await _db.insertProduct(product, userId: activeUser?.id);
    } else {
      await _db.updateProduct(product);
    }
    await refreshOperationalData();
  }

  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
    await refreshOperationalData();
  }

  Future<void> adjustStock({
    required ProductItem product,
    required String movementType, // 'in' | 'out' | 'opname'
    required double qtyInput,
    String notes = '',
  }) async {
    if (!canAccess('inventory_edit')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk mengubah stok.',
      );
    }
    if (product.id == null) return;
    if (movementType == 'opname') {
      await _db.adjustStock(
        productId: product.id!,
        movementType: 'opname',
        qtyDelta: 0,
        exactNewStock: qtyInput,
        notes: notes,
        userId: activeUser?.id,
        referenceType: 'opname',
      );
    } else if (movementType == 'out') {
      await _db.adjustStock(
        productId: product.id!,
        movementType: 'out',
        qtyDelta: -qtyInput.abs(),
        notes: notes,
        userId: activeUser?.id,
        referenceType: 'manual_out',
      );
    } else {
      await _db.adjustStock(
        productId: product.id!,
        movementType: 'in',
        qtyDelta: qtyInput.abs(),
        notes: notes,
        userId: activeUser?.id,
        referenceType: 'manual_in',
      );
    }
    await refreshOperationalData();
  }

  // =========================================================================
  // PELANGGAN, KASBON, SUPPLIER, KULAKAN & PENGELUARAN
  // =========================================================================

  Future<void> saveCustomer(CustomerItem customer) async {
    if (customer.id == null) {
      await _db.insertCustomer(customer);
    } else {
      await _db.updateCustomer(customer);
    }
    await refreshOperationalData();
  }

  Future<void> payCustomerDebt({
    required CustomerItem customer,
    required int amount,
    required String paymentMethod,
    String notes = '',
  }) async {
    if (customer.id == null) return;
    await _db.payDebt(
      customerId: customer.id!,
      amount: amount,
      paymentMethod: paymentMethod,
      shiftId: activeShift?.id,
      userId: activeUser?.id,
      notes: notes,
    );
    await refreshOperationalData();
  }

  Future<void> saveSupplier(SupplierItem supplier) async {
    if (supplier.id == null) {
      await _db.insertSupplier(supplier);
    } else {
      await _db.updateSupplier(supplier);
    }
    await refreshOperationalData();
  }

  Future<void> createPurchase({
    required int supplierId,
    required String invoiceNo,
    required List<PurchaseOrderItem> items,
    required int totalAmount,
    required String paymentStatus,
    String notes = '',
  }) async {
    if (!canAccess('suppliers')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk membuat purchase order.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.createPurchaseOrder(
      PurchaseOrder(
        invoiceNo: invoiceNo,
        supplierId: supplierId,
        userId: activeUser?.id,
        items: items,
        totalAmount: totalAmount,
        paymentStatus: paymentStatus,
        notes: notes,
        purchasedAt: now,
        createdAt: now,
      ),
    );
    await refreshOperationalData();
  }

  Future<void> addExpense({
    required String category,
    required String title,
    required int amount,
    required String paymentSource,
    String notes = '',
  }) async {
    if (!canAccess('expenses')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk mencatat pengeluaran.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insertExpense(
      ExpenseItem(
        category: category,
        title: title,
        amount: amount,
        paymentSource: paymentSource,
        shiftId: paymentSource == 'drawer' ? activeShift?.id : null,
        userId: activeUser?.id,
        notes: notes,
        expenseDate: now,
        createdAt: now,
      ),
    );
    await refreshOperationalData();
  }

  Future<void> deleteExpense(int id) async {
    if (!canAccess('expenses')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk menghapus pengeluaran.',
      );
    }
    await _db.deleteExpense(id);
    await refreshOperationalData();
  }

  // =========================================================================
  // BCA PAYMENT GATEWAY (QRIS NOMINAL PAS)
  // =========================================================================

  bool get hasBcaGatewayConfigured =>
      (store?.gatewayUrl.trim().isNotEmpty ?? false) &&
      (store?.gatewayApiKey.trim().isNotEmpty ?? false);

  Future<BcaChargeResult> createBcaQrisCharge(
    String externalId,
    double amount, {
    bool exactAmount = true,
  }) {
    return _bcaGateway.createQrisCharge(
      baseUrl: store?.gatewayUrl ?? '',
      apiKey: store?.gatewayApiKey ?? '',
      externalId: externalId,
      amount: amount,
      exactAmount: exactAmount,
    );
  }

  Future<BcaStatusResult> checkBcaQrisStatus(String externalId) {
    return _bcaGateway.checkPaymentStatus(
      baseUrl: store?.gatewayUrl ?? '',
      apiKey: store?.gatewayApiKey ?? '',
      externalId: externalId,
    );
  }

  Future<BcaConnectionResult> testBcaGatewayConnection(
    String url,
    String apiKey,
  ) {
    return _bcaGateway.testConnection(
      baseUrl: url,
      apiKey: apiKey,
    );
  }

  // =========================================================================
  // PENGATURAN TOKO, STAFF, PRINTER, BACKUP & EXPORT
  // =========================================================================

  Future<void> updateStore(
    StoreConfig updated, {
    String? gatewayUrl,
    String? gatewayApiKey,
  }) async {
    if (!canAccess('settings_admin')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk mengubah pengaturan toko.',
      );
    }
    final toSave = updated.copyWith(
      gatewayUrl: gatewayUrl?.trim() ?? updated.gatewayUrl.trim(),
      gatewayApiKey: gatewayApiKey?.trim() ?? updated.gatewayApiKey.trim(),
    );
    await _db.saveStoreConfig(toSave);
    await refreshOperationalData();
  }

  Future<void> saveStaffUser({
    int? id,
    required String name,
    required String role,
    String? pin,
    bool isActive = true,
  }) async {
    if (!canAccess('staff_manage')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk mengelola data staf.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    if (id == null) {
      final trimmedPin = pin?.trim() ?? '';
      if (trimmedPin.length < 4 ||
          trimmedPin.length > 6 ||
          !RegExp(r'^\d+$').hasMatch(trimmedPin)) {
        throw ArgumentError(
          'PIN staf baru wajib diisi dengan 4–6 digit angka.',
        );
      }
      final salt = _auth.generateSalt();
      final hash = _auth.hashPin(trimmedPin, salt);
      await _db.insertUser(
        AppUser(
          name: name.trim(),
          role: role,
          pinHash: hash,
          pinSalt: salt,
          isActive: isActive,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      final existing = users.firstWhere((u) => u.id == id);
      String salt = existing.pinSalt;
      String hash = existing.pinHash;
      if (pin != null && pin.isNotEmpty) {
        final trimmedPin = pin.trim();
        if (trimmedPin.length < 4 ||
            trimmedPin.length > 6 ||
            !RegExp(r'^\d+$').hasMatch(trimmedPin)) {
          throw ArgumentError(
            'PIN staf wajib terdiri dari 4–6 digit angka.',
          );
        }
        salt = _auth.generateSalt();
        hash = _auth.hashPin(trimmedPin, salt);
      }
      await _db.updateUser(
        existing.copyWith(
          name: name.trim(),
          role: role,
          pinHash: hash,
          pinSalt: salt,
          isActive: isActive,
          updatedAt: now,
        ),
      );
    }
    await refreshOperationalData();
  }

  Future<void> savePrinterConfig(PrinterConfig config) async {
    await _db.savePrinterConfig(config);
    printerConfigs = await _db.getPrinterConfigs();
    notifyListeners();
  }

  Future<void> deletePrinterConfig(int id) async {
    await _db.deletePrinterConfig(id);
    printerConfigs = await _db.getPrinterConfigs();
    notifyListeners();
  }

  Future<String> printTransactionReceipt(
    PosTransaction tx, {
    PrinterConfig? overrideConfig,
  }) async {
    if (store == null) return 'Profil toko belum tersedia';
    PosTransaction fullTx = tx;
    if (tx.id != null && tx.items.isEmpty) {
      fullTx = (await _db.getTransactionDetail(tx.id!)) ?? tx;
    }
    final res = await _printerManager.printReceipt(
      store: store!,
      transaction: fullTx,
      items: fullTx.items,
      payments: fullTx.payments,
      overrideConfig: overrideConfig,
      cashierName: activeUser?.name ?? 'Kasir',
      customerName: selectedCustomer?.name,
    );
    return res.message;
  }

  Future<String> printQrisSlip({
    required String externalId,
    required double amount,
    required String qrisString,
    Uint8List? qrisImageBytes,
    PrinterConfig? overrideConfig,
  }) async {
    if (store == null) return 'Profil toko belum tersedia';
    final res = await _printerManager.printQrisSlip(
      store: store!,
      externalId: externalId,
      amount: amount,
      qrisString: qrisString,
      qrisImageBytes: qrisImageBytes,
      overrideConfig: overrideConfig,
    );
    return res.message;
  }

  Future<String> testPrintReceipt(PrinterConfig config) async {
    if (store == null) return 'Profil toko belum tersedia';
    final res = await _printerManager.testPrint(config, store!);
    return res.message;
  }

  Future<String> testPrintLabel(PrinterConfig config) async {
    if (store == null) return 'Profil toko belum tersedia';
    final res = await _printerManager.testPrint(config, store!);
    return res.message;
  }

  Future<String> printProductLabels({
    required List<ProductItem> products,
    required Map<int, int> copiesPerProduct,
    required String labelSize,
    PrinterConfig? overrideConfig,
  }) async {
    final res = await _printerManager.printLabels(
      products: products,
      preset: LabelSizePreset.fromCode(labelSize),
      copiesPerProduct: copiesPerProduct,
      store: store,
      overrideConfig: overrideConfig,
    );
    return res.message;
  }

  Future<void> kickCashDrawer(PrinterConfig config) async {
    await _printerManager.openCashDrawer(overrideConfig: config);
  }

  // =========================================================================
  // LAPORAN LABA RUGI, EXPORT & BACKUP/RESTORE JSON
  // =========================================================================

  Future<ProfitLossSummary> getProfitLossSummary(
    DateTime start,
    DateTime end,
  ) {
    final startLocal = DateTime(start.year, start.month, start.day);
    final endLocal = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return _db.getProfitLossSummary(from: startLocal, to: endLocal);
  }

  Future<void> exportSalesCsv(DateTime start, DateTime end) async {
    if (!canAccess('reports')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk mengekspor laporan.',
      );
    }
    final startUtc = DateTime(start.year, start.month, start.day).toUtc();
    final endUtc =
        DateTime(end.year, end.month, end.day, 23, 59, 59).toUtc();
    final filtered = recentTransactions.where((tx) {
      final dt = DateTime.tryParse(tx.createdAt)?.toUtc();
      return dt != null && !dt.isBefore(startUtc) && !dt.isAfter(endUtc);
    }).toList();
    await _export.shareTransactionsCsv(
      filtered,
      currencySymbol: currencySymbol,
    );
  }

  Future<void> exportProfitLossPdf(DateTime start, DateTime end) async {
    if (!canAccess('reports')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk mengekspor laporan.',
      );
    }
    if (store == null) return;
    final summary = await getProfitLossSummary(start, end);
    await _export.shareProfitLossPdf(
      store: store!,
      summary: summary,
    );
  }

  Future<void> backupDatabaseJson() async {
    if (!canAccess('backup_restore')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk mencadangkan database.',
      );
    }
    await _export.exportBackupJsonAndShare();
  }

  Future<bool> restoreDatabaseJson() async {
    if (!canAccess('backup_restore')) {
      throw StateError(
        'Akses ditolak: Anda tidak memiliki izin untuk me-restore database.',
      );
    }
    final ok = await _export.pickAndRestoreBackupJson();
    if (!ok) return false;
    await initApp();
    if (isInitialized) {
      _auth.logout();
      activeUser = null;
    }
    notifyListeners();
    return true;
  }
}
