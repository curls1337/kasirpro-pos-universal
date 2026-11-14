import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/pos_models.dart';

class DbHelper {
  DbHelper._internal();
  static final DbHelper instance = DbHelper._internal();
  factory DbHelper() => instance;

  static const String _dbName = 'kasirpro_universal.db';
  static const int _dbVersion = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    return openDatabase(
      fullPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL;');
        } catch (_) {
          // Abaikan bila platform tidak mendukung WAL
        }
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          "ALTER TABLE stores ADD COLUMN gateway_url TEXT NOT NULL DEFAULT '';",
        );
      } catch (_) {
        // Abaikan jika kolom gateway_url sudah ada
      }
      try {
        await db.execute(
          "ALTER TABLE stores ADD COLUMN gateway_api_key TEXT NOT NULL DEFAULT '';",
        );
      } catch (_) {
        // Abaikan jika kolom gateway_api_key sudah ada
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. STORES
    await db.execute('''
      CREATE TABLE stores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        business_type TEXT NOT NULL CHECK (business_type IN ('retail', 'fnb', 'service')),
        address TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        tax_percent REAL NOT NULL DEFAULT 0.0,
        service_charge_percent REAL NOT NULL DEFAULT 0.0,
        currency_symbol TEXT NOT NULL DEFAULT 'Rp',
        receipt_footer TEXT DEFAULT 'Terima kasih atas kunjungan Anda',
        gateway_url TEXT NOT NULL DEFAULT '',
        gateway_api_key TEXT NOT NULL DEFAULT '',
        setup_completed INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 2. USERS
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'cashier', 'kitchen')),
        pin_hash TEXT NOT NULL,
        pin_salt TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 3. CATEGORIES
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_name TEXT NOT NULL DEFAULT 'category',
        color_hex TEXT NOT NULL DEFAULT '#2563EB',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');

    // 4. PRODUCTS
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        sku TEXT UNIQUE,
        barcode TEXT,
        name TEXT NOT NULL,
        item_type TEXT NOT NULL DEFAULT 'goods' CHECK (item_type IN ('goods', 'fnb_menu', 'service')),
        sell_price INTEGER NOT NULL DEFAULT 0,
        cost_price INTEGER NOT NULL DEFAULT 0,
        stock_qty REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 5,
        unit TEXT NOT NULL DEFAULT 'pcs',
        track_stock INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode);');
    await db.execute('CREATE INDEX idx_products_category ON products(category_id);');

    // 5. STOCK_MOVEMENTS
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        movement_type TEXT NOT NULL CHECK (movement_type IN ('in', 'out', 'opname', 'sale', 'purchase', 'void')),
        qty_delta REAL NOT NULL,
        stock_before REAL NOT NULL,
        stock_after REAL NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        notes TEXT DEFAULT '',
        user_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      );
    ''');
    await db.execute(
        'CREATE INDEX idx_stock_movements_product ON stock_movements(product_id, created_at);');

    // 6. CUSTOMERS
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        address TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        credit_limit INTEGER NOT NULL DEFAULT 0,
        total_debt INTEGER NOT NULL DEFAULT 0,
        loyalty_points INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 7. SHIFTS
    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_cash INTEGER NOT NULL DEFAULT 0,
        expected_cash INTEGER NOT NULL DEFAULT 0,
        actual_cash INTEGER,
        cash_difference INTEGER DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
        notes TEXT DEFAULT '',
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute(
        'CREATE INDEX idx_shifts_status ON shifts(status, opened_at);');

    // 8. CASH_FLOWS
    await db.execute('''
      CREATE TABLE cash_flows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('cash_in', 'cash_out')),
        amount INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT 'general',
        notes TEXT DEFAULT '',
        user_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      );
    ''');

    // 9. TRANSACTIONS
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL UNIQUE,
        shift_id INTEGER,
        user_id INTEGER,
        customer_id INTEGER,
        order_type TEXT NOT NULL DEFAULT 'retail' CHECK (order_type IN ('retail', 'dine_in', 'takeaway', 'service')),
        table_number TEXT DEFAULT '',
        subtotal INTEGER NOT NULL DEFAULT 0,
        discount_amount INTEGER NOT NULL DEFAULT 0,
        tax_amount INTEGER NOT NULL DEFAULT 0,
        service_charge INTEGER NOT NULL DEFAULT 0,
        total_amount INTEGER NOT NULL DEFAULT 0,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        change_amount INTEGER NOT NULL DEFAULT 0,
        debt_amount INTEGER NOT NULL DEFAULT 0,
        points_earned INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'partial_debt', 'void')),
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
      );
    ''');
    await db.execute(
        'CREATE INDEX idx_transactions_date ON transactions(created_at);');
    await db.execute(
        'CREATE INDEX idx_transactions_shift ON transactions(shift_id);');

    // 10. TRANSACTION_ITEMS
    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        sku TEXT DEFAULT '',
        qty REAL NOT NULL,
        unit_price INTEGER NOT NULL,
        cost_price INTEGER NOT NULL DEFAULT 0,
        discount_amount INTEGER NOT NULL DEFAULT 0,
        subtotal INTEGER NOT NULL,
        item_notes TEXT DEFAULT '',
        kitchen_status TEXT NOT NULL DEFAULT 'none' CHECK (kitchen_status IN ('none', 'queued', 'preparing', 'served')),
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
      );
    ''');
    await db.execute(
        'CREATE INDEX idx_tx_items_tx ON transaction_items(transaction_id);');

    // 11. TRANSACTION_PAYMENTS
    await db.execute('''
      CREATE TABLE transaction_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        method TEXT NOT NULL CHECK (method IN ('cash', 'qris', 'transfer', 'debit', 'kasbon')),
        amount INTEGER NOT NULL,
        reference_no TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
        'CREATE INDEX idx_tx_payments_tx ON transaction_payments(transaction_id);');

    // 12. DEBT_PAYMENTS
    await db.execute('''
      CREATE TABLE debt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        transaction_id INTEGER,
        shift_id INTEGER,
        user_id INTEGER,
        amount INTEGER NOT NULL,
        payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'qris', 'transfer', 'debit')),
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      );
    ''');

    // 13. SUPPLIERS
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        address TEXT DEFAULT '',
        contact_person TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');

    // 14. PURCHASES
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL,
        supplier_id INTEGER,
        user_id INTEGER,
        items_json TEXT NOT NULL,
        total_amount INTEGER NOT NULL DEFAULT 0,
        payment_status TEXT NOT NULL DEFAULT 'paid' CHECK (payment_status IN ('paid', 'debt')),
        notes TEXT DEFAULT '',
        purchased_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      );
    ''');

    // 15. EXPENSES
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        payment_source TEXT NOT NULL DEFAULT 'non_drawer' CHECK (payment_source IN ('drawer', 'non_drawer')),
        shift_id INTEGER,
        user_id INTEGER,
        notes TEXT DEFAULT '',
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      );
    ''');

    // 16. HELD_CARTS
    await db.execute('''
      CREATE TABLE held_carts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cart_label TEXT NOT NULL,
        order_type TEXT NOT NULL DEFAULT 'retail' CHECK (order_type IN ('retail', 'dine_in', 'takeaway', 'service')),
        table_number TEXT DEFAULT '',
        customer_id INTEGER,
        items_json TEXT NOT NULL,
        discount_amount INTEGER NOT NULL DEFAULT 0,
        notes TEXT DEFAULT '',
        user_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      );
    ''');

    // 17. PRINTER_CONFIGS
    await db.execute('''
      CREATE TABLE printer_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role_type TEXT NOT NULL CHECK (role_type IN ('receipt', 'kitchen', 'label')),
        connection_type TEXT NOT NULL CHECK (connection_type IN ('bluetooth', 'wifi_tcp', 'system_pdf')),
        address_or_ip TEXT DEFAULT '',
        port INTEGER NOT NULL DEFAULT 9100,
        paper_width_mm INTEGER NOT NULL DEFAULT 58,
        label_size TEXT NOT NULL DEFAULT '40x30',
        command_lang TEXT NOT NULL DEFAULT 'escpos' CHECK (command_lang IN ('escpos', 'tspl', 'cpcl', 'pdf')),
        is_default INTEGER NOT NULL DEFAULT 0,
        auto_print INTEGER NOT NULL DEFAULT 0,
        open_drawer INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');
  }

  // =========================================================================
  // SETUP & STORE CONFIG
  // =========================================================================

  Future<bool> isStoreInitialized() async {
    final db = await database;
    final storeRes = await db.query(
      'stores',
      where: 'setup_completed = 1',
      limit: 1,
    );
    if (storeRes.isEmpty) return false;

    final ownerRes = await db.query(
      'users',
      where: 'role = ? AND is_active = 1',
      whereArgs: ['owner'],
      limit: 1,
    );
    return ownerRes.isNotEmpty;
  }

  Future<void> initializeStoreAndOwner({
    required StoreConfig store,
    required AppUser owner,
    List<CategoryItem> initialCategories = const [],
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('stores', store.toMap());
      await txn.insert('users', owner.toMap());
      for (final cat in initialCategories) {
        await txn.insert('categories', cat.toMap());
      }
    });
  }

  Future<StoreConfig?> getStoreConfig() async {
    final db = await database;
    final rows = await db.query('stores', orderBy: 'id ASC', limit: 1);
    if (rows.isEmpty) return null;
    return StoreConfig.fromMap(rows.first);
  }

  Future<StoreConfig> saveStoreConfig(StoreConfig store) async {
    final db = await database;
    final updated =
        store.copyWith(updatedAt: DateTime.now().toUtc().toIso8601String());
    if (updated.id == null) {
      final id = await db.insert('stores', updated.toMap());
      return updated.copyWith(id: id);
    } else {
      await db.update(
        'stores',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
      return updated;
    }
  }

  // =========================================================================
  // USERS CRUD
  // =========================================================================

  Future<List<AppUser>> getUsers({bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'id ASC',
    );
    return rows.map(AppUser.fromMap).toList();
  }

  Future<AppUser?> getUserById(int id) async {
    final db = await database;
    final rows =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser> insertUser(AppUser user) async {
    final db = await database;
    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  Future<int> updateUser(AppUser user) async {
    final db = await database;
    final updated =
        user.copyWith(updatedAt: DateTime.now().toUtc().toIso8601String());
    return db
        .update('users', updated.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return db
        .update('users', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // =========================================================================
  // CATEGORIES CRUD
  // =========================================================================

  Future<List<CategoryItem>> getCategories({bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(CategoryItem.fromMap).toList();
  }

  Future<CategoryItem> insertCategory(CategoryItem category) async {
    final db = await database;
    final id = await db.insert('categories', category.toMap());
    return category.copyWith(id: id);
  }

  Future<int> updateCategory(CategoryItem category) async {
    final db = await database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db
        .update('categories', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // =========================================================================
  // PRODUCTS & STOCK MOVEMENTS CRUD
  // =========================================================================

  Future<List<ProductItem>> getProducts({
    int? categoryId,
    String? search,
    bool activeOnly = true,
    bool lowStockOnly = false,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final args = <dynamic>[];

    if (activeOnly) {
      whereParts.add('is_active = 1');
    }
    if (categoryId != null) {
      whereParts.add('category_id = ?');
      args.add(categoryId);
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      whereParts.add('(name LIKE ? OR sku LIKE ? OR barcode LIKE ?)');
      args.addAll([q, q, q]);
    }
    if (lowStockOnly) {
      whereParts.add('track_stock = 1 AND stock_qty <= min_stock');
    }

    final rows = await db.query(
      'products',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return rows.map(ProductItem.fromMap).toList();
  }

  Future<ProductItem?> getProductById(int id) async {
    final db = await database;
    final rows =
        await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return ProductItem.fromMap(rows.first);
  }

  Future<ProductItem?> getProductByBarcode(String code) async {
    final db = await database;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    final rows = await db.query(
      'products',
      where: 'is_active = 1 AND (barcode = ? OR sku = ?)',
      whereArgs: [trimmed, trimmed],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProductItem.fromMap(rows.first);
  }

  Future<ProductItem> insertProduct(ProductItem product, {int? userId}) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('products', product.toMap());
      final saved = product.copyWith(id: id);
      if (saved.trackStock && saved.stockQty != 0) {
        await txn.insert(
          'stock_movements',
          StockMovement(
            productId: id,
            movementType: 'in',
            qtyDelta: saved.stockQty,
            stockBefore: 0,
            stockAfter: saved.stockQty,
            referenceType: 'initial',
            notes: 'Stok awal produk',
            userId: userId,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ).toMap(),
        );
      }
      return saved;
    });
  }

  Future<int> updateProduct(ProductItem product) async {
    final db = await database;
    final updated = product.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    return db.update(
      'products',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db
        .update('products', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<ProductItem> adjustStock({
    required int productId,
    required String movementType, // 'in' | 'out' | 'opname'
    required double qtyDelta,
    double? exactNewStock,
    int? userId,
    String notes = '',
    String referenceType = 'opname',
    int? referenceId,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Produk ID $productId tidak ditemukan');
      }
      final current = ProductItem.fromMap(rows.first);
      final before = current.stockQty;
      final after = exactNewStock ?? (before + qtyDelta);
      final delta = after - before;
      final now = DateTime.now().toUtc().toIso8601String();

      await txn.update(
        'products',
        {'stock_qty': after, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );

      await txn.insert(
        'stock_movements',
        StockMovement(
          productId: productId,
          movementType: movementType,
          qtyDelta: delta,
          stockBefore: before,
          stockAfter: after,
          referenceType: referenceType,
          referenceId: referenceId,
          notes: notes,
          userId: userId,
          createdAt: now,
        ).toMap(),
      );

      return current.copyWith(stockQty: after, updatedAt: now);
    });
  }

  Future<List<StockMovement>> getStockMovements({
    int? productId,
    int limit = 100,
  }) async {
    final db = await database;
    final rows = await db.query(
      'stock_movements',
      where: productId != null ? 'product_id = ?' : null,
      whereArgs: productId != null ? [productId] : null,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  // =========================================================================
  // CUSTOMERS & KASBON / DEBT PAYMENTS
  // =========================================================================

  Future<List<CustomerItem>> getCustomers({
    String? search,
    bool withDebtOnly = false,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final args = <dynamic>[];
    if (activeOnly) whereParts.add('is_active = 1');
    if (withDebtOnly) whereParts.add('total_debt > 0');
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      whereParts.add('(name LIKE ? OR phone LIKE ?)');
      args.addAll([q, q]);
    }
    final rows = await db.query(
      'customers',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return rows.map(CustomerItem.fromMap).toList();
  }

  Future<CustomerItem?> getCustomerById(int id) async {
    final db = await database;
    final rows =
        await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return CustomerItem.fromMap(rows.first);
  }

  Future<CustomerItem> insertCustomer(CustomerItem customer) async {
    final db = await database;
    final id = await db.insert('customers', customer.toMap());
    return customer.copyWith(id: id);
  }

  Future<int> updateCustomer(CustomerItem customer) async {
    final db = await database;
    final updated = customer.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    return db.update(
      'customers',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return db
        .update('customers', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DebtPayment>> getDebtPayments({int? customerId}) async {
    final db = await database;
    final rows = await db.query(
      'debt_payments',
      where: customerId != null ? 'customer_id = ?' : null,
      whereArgs: customerId != null ? [customerId] : null,
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(DebtPayment.fromMap).toList();
  }

  /// Pembayaran / cicilan kasbon atomik
  Future<DebtPayment> payDebt({
    required int customerId,
    required int amount,
    required String paymentMethod, // 'cash' | 'qris' | 'transfer' | 'debit'
    int? transactionId,
    int? shiftId,
    int? userId,
    String notes = '',
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Nominal cicilan harus lebih besar dari 0');
    }
    final db = await database;
    return db.transaction((txn) async {
      final custRows = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (custRows.isEmpty) {
        throw StateError('Pelanggan tidak ditemukan');
      }
      final customer = CustomerItem.fromMap(custRows.first);
      final newDebt = (customer.totalDebt - amount).clamp(0, 1 << 62);
      final now = DateTime.now().toUtc().toIso8601String();

      await txn.update(
        'customers',
        {'total_debt': newDebt, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [customerId],
      );

      final payment = DebtPayment(
        customerId: customerId,
        transactionId: transactionId,
        shiftId: shiftId,
        userId: userId,
        amount: amount,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: now,
      );
      final id = await txn.insert('debt_payments', payment.toMap());

      if (paymentMethod == 'cash' && shiftId != null) {
        await txn.rawUpdate(
          'UPDATE shifts SET expected_cash = expected_cash + ? WHERE id = ?',
          [amount, shiftId],
        );
      }

      return DebtPayment(
        id: id,
        customerId: customerId,
        transactionId: transactionId,
        shiftId: shiftId,
        userId: userId,
        amount: amount,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: now,
      );
    });
  }

  // =========================================================================
  // SUPPLIERS & PURCHASE ORDERS
  // =========================================================================

  Future<List<SupplierItem>> getSuppliers({bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      'suppliers',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(SupplierItem.fromMap).toList();
  }

  Future<SupplierItem> insertSupplier(SupplierItem supplier) async {
    final db = await database;
    final id = await db.insert('suppliers', supplier.toMap());
    return supplier.copyWith(id: id);
  }

  Future<int> updateSupplier(SupplierItem supplier) async {
    final db = await database;
    return db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;
    return db
        .update('suppliers', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PurchaseOrder>> getPurchaseOrders({int? supplierId}) async {
    final db = await database;
    final rows = await db.query(
      'purchases',
      where: supplierId != null ? 'supplier_id = ?' : null,
      whereArgs: supplierId != null ? [supplierId] : null,
      orderBy: 'purchased_at DESC, id DESC',
    );
    return rows.map(PurchaseOrder.fromMap).toList();
  }

  /// Kulakan atomik: simpan PO + tambah stok produk + update HPP + catat stock_movements
  Future<PurchaseOrder> createPurchaseOrder(PurchaseOrder order) async {
    final db = await database;
    return db.transaction((txn) async {
      final purchaseId = await txn.insert('purchases', order.toMap());
      final now = DateTime.now().toUtc().toIso8601String();

      for (final item in order.items) {
        final prodRows = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
          limit: 1,
        );
        if (prodRows.isEmpty) continue;
        final prod = ProductItem.fromMap(prodRows.first);
        final before = prod.stockQty;
        final after = before + item.qty;

        await txn.update(
          'products',
          {
            'stock_qty': after,
            if (item.buyPrice > 0) 'cost_price': item.buyPrice,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        await txn.insert(
          'stock_movements',
          StockMovement(
            productId: item.productId,
            movementType: 'purchase',
            qtyDelta: item.qty,
            stockBefore: before,
            stockAfter: after,
            referenceType: 'purchase',
            referenceId: purchaseId,
            notes: 'Kulakan ${order.invoiceNo}',
            userId: order.userId,
            createdAt: now,
          ).toMap(),
        );
      }

      return PurchaseOrder(
        id: purchaseId,
        invoiceNo: order.invoiceNo,
        supplierId: order.supplierId,
        userId: order.userId,
        items: order.items,
        totalAmount: order.totalAmount,
        paymentStatus: order.paymentStatus,
        notes: order.notes,
        purchasedAt: order.purchasedAt,
        createdAt: order.createdAt,
      );
    });
  }

  // =========================================================================
  // SHIFTS & CASH FLOWS
  // =========================================================================

  Future<ShiftSession?> getOpenShift({int? userId}) async {
    final db = await database;
    final rows = await db.query(
      'shifts',
      where:
          userId != null ? "status = 'open' AND user_id = ?" : "status = 'open'",
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ShiftSession.fromMap(rows.first);
  }

  Future<List<ShiftSession>> getShifts({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'shifts',
      orderBy: 'opened_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(ShiftSession.fromMap).toList();
  }

  Future<ShiftSession> openShift({
    required int userId,
    required int openingCash,
    String notes = '',
  }) async {
    final db = await database;
    final existing = await getOpenShift(userId: userId);
    if (existing != null) {
      return existing;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final shift = ShiftSession(
      userId: userId,
      openedAt: now,
      openingCash: openingCash,
      expectedCash: openingCash,
      status: 'open',
      notes: notes,
    );
    final id = await db.insert('shifts', shift.toMap());
    return shift.copyWith(id: id);
  }

  Future<Map<String, int>> getShiftCashSummary(int shiftId) async {
    final db = await database;
    final shiftRows =
        await db.query('shifts', where: 'id = ?', whereArgs: [shiftId], limit: 1);
    if (shiftRows.isEmpty) {
      throw StateError('Shift ID $shiftId tidak ditemukan');
    }
    final shift = ShiftSession.fromMap(shiftRows.first);

    final cashPayRes = await db.rawQuery('''
      SELECT COALESCE(SUM(tp.amount), 0) AS total_cash_paid
      FROM transaction_payments tp
      INNER JOIN transactions t ON t.id = tp.transaction_id
      WHERE t.shift_id = ? AND t.status != 'void' AND tp.method = 'cash'
    ''', [shiftId]);
    final totalCashPaid =
        (cashPayRes.first['total_cash_paid'] as num?)?.toInt() ?? 0;

    final changeRes = await db.rawQuery('''
      SELECT COALESCE(SUM(change_amount), 0) AS total_change
      FROM transactions
      WHERE shift_id = ? AND status != 'void'
    ''', [shiftId]);
    final totalChange =
        (changeRes.first['total_change'] as num?)?.toInt() ?? 0;
    final netCashSales = (totalCashPaid - totalChange).clamp(0, 1 << 62);

    final nonCashRes = await db.rawQuery('''
      SELECT COALESCE(SUM(tp.amount), 0) AS total_non_cash
      FROM transaction_payments tp
      INNER JOIN transactions t ON t.id = tp.transaction_id
      WHERE t.shift_id = ? AND t.status != 'void' AND tp.method IN ('qris', 'transfer', 'debit')
    ''', [shiftId]);
    final nonCashSales =
        (nonCashRes.first['total_non_cash'] as num?)?.toInt() ?? 0;

    final kasbonRes = await db.rawQuery('''
      SELECT COALESCE(SUM(debt_amount), 0) AS total_kasbon
      FROM transactions
      WHERE shift_id = ? AND status != 'void'
    ''', [shiftId]);
    final kasbonSales =
        (kasbonRes.first['total_kasbon'] as num?)?.toInt() ?? 0;

    final debtCashRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total_debt_cash
      FROM debt_payments
      WHERE shift_id = ? AND payment_method = 'cash'
    ''', [shiftId]);
    final cashDebtPayments =
        (debtCashRes.first['total_debt_cash'] as num?)?.toInt() ?? 0;

    final cashInRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total_in
      FROM cash_flows
      WHERE shift_id = ? AND type = 'cash_in'
    ''', [shiftId]);
    final cashIn = (cashInRes.first['total_in'] as num?)?.toInt() ?? 0;

    final cashOutRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total_out
      FROM cash_flows
      WHERE shift_id = ? AND type = 'cash_out'
    ''', [shiftId]);
    final cashOut = (cashOutRes.first['total_out'] as num?)?.toInt() ?? 0;

    final drawerExpRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total_drawer_exp
      FROM expenses
      WHERE shift_id = ? AND payment_source = 'drawer'
    ''', [shiftId]);
    final drawerExpenses =
        (drawerExpRes.first['total_drawer_exp'] as num?)?.toInt() ?? 0;

    final expectedCash = shift.openingCash +
        netCashSales +
        cashDebtPayments +
        cashIn -
        cashOut -
        drawerExpenses;

    return {
      'opening_cash': shift.openingCash,
      'cash_sales': netCashSales,
      'non_cash_sales': nonCashSales,
      'kasbon_sales': kasbonSales,
      'cash_debt_payments': cashDebtPayments,
      'cash_in': cashIn,
      'cash_out': cashOut,
      'drawer_expenses': drawerExpenses,
      'expected_cash': expectedCash,
    };
  }

  Future<ShiftSession> closeShift({
    required int shiftId,
    required int actualCash,
    String notes = '',
  }) async {
    final db = await database;
    final summary = await getShiftCashSummary(shiftId);
    final expectedCash = summary['expected_cash'] ?? 0;
    final difference = actualCash - expectedCash;
    final closedAt = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'shifts',
      {
        'closed_at': closedAt,
        'expected_cash': expectedCash,
        'actual_cash': actualCash,
        'cash_difference': difference,
        'status': 'closed',
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );

    final rows =
        await db.query('shifts', where: 'id = ?', whereArgs: [shiftId], limit: 1);
    return ShiftSession.fromMap(rows.first);
  }

  Future<List<CashFlowItem>> getCashFlows(int shiftId) async {
    final db = await database;
    final rows = await db.query(
      'cash_flows',
      where: 'shift_id = ?',
      whereArgs: [shiftId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(CashFlowItem.fromMap).toList();
  }

  Future<CashFlowItem> addCashFlow(CashFlowItem item) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('cash_flows', item.toMap());
      final delta = item.type == 'cash_in' ? item.amount : -item.amount;
      await txn.rawUpdate(
        'UPDATE shifts SET expected_cash = expected_cash + ? WHERE id = ?',
        [delta, item.shiftId],
      );
      return CashFlowItem(
        id: id,
        shiftId: item.shiftId,
        type: item.type,
        amount: item.amount,
        category: item.category,
        notes: item.notes,
        userId: item.userId,
        createdAt: item.createdAt,
      );
    });
  }

  // =========================================================================
  // TRANSACTIONS (ATOMIC CHECKOUT, LIST, DETAIL, VOID)
  // =========================================================================

  Future<PosTransaction> checkoutTransaction({
    required PosTransaction transaction,
    required List<PosTransactionItem> items,
    required List<TransactionPayment> payments,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Keranjang transaksi tidak boleh kosong');
    }
    final db = await database;
    return db.transaction((txn) async {
      final txId = await txn.insert('transactions', transaction.toMap());
      final savedItems = <PosTransactionItem>[];
      final savedPayments = <TransactionPayment>[];
      final now = DateTime.now().toUtc().toIso8601String();

      for (final item in items) {
        final itemToInsert = item.copyWith(transactionId: txId);
        final itemId = await txn.insert('transaction_items', itemToInsert.toMap());
        savedItems.add(itemToInsert.copyWith(id: itemId));

        if (item.productId != null) {
          final prodRows = await txn.query(
            'products',
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );
          if (prodRows.isNotEmpty) {
            final prod = ProductItem.fromMap(prodRows.first);
            if (prod.trackStock) {
              final before = prod.stockQty;
              final after = before - item.qty;
              await txn.update(
                'products',
                {'stock_qty': after, 'updated_at': now},
                where: 'id = ?',
                whereArgs: [prod.id],
              );
              await txn.insert(
                'stock_movements',
                StockMovement(
                  productId: prod.id!,
                  movementType: 'sale',
                  qtyDelta: -item.qty,
                  stockBefore: before,
                  stockAfter: after,
                  referenceType: 'transaction',
                  referenceId: txId,
                  notes: 'Penjualan ${transaction.invoiceNo}',
                  userId: transaction.userId,
                  createdAt: now,
                ).toMap(),
              );
            }
          }
        }
      }

      int cashPaid = 0;
      for (final payment in payments) {
        final payToInsert = payment.copyWith(transactionId: txId);
        final payId =
            await txn.insert('transaction_payments', payToInsert.toMap());
        savedPayments.add(payToInsert.copyWith(id: payId));
        if (payment.method == 'cash') {
          cashPaid += payment.amount;
        }
      }

      final netCash = (cashPaid - transaction.changeAmount).clamp(0, 1 << 62);
      if (transaction.shiftId != null && netCash > 0) {
        await txn.rawUpdate(
          'UPDATE shifts SET expected_cash = expected_cash + ? WHERE id = ?',
          [netCash, transaction.shiftId],
        );
      }

      if (transaction.customerId != null) {
        final custRows = await txn.query(
          'customers',
          where: 'id = ?',
          whereArgs: [transaction.customerId],
          limit: 1,
        );
        if (custRows.isNotEmpty) {
          final customer = CustomerItem.fromMap(custRows.first);
          final pointsToAdd = transaction.pointsEarned > 0
              ? transaction.pointsEarned
              : (transaction.totalAmount ~/ 10000);
          final newPoints = customer.loyaltyPoints + pointsToAdd;
          final newDebt = customer.totalDebt + transaction.debtAmount;

          await txn.update(
            'customers',
            {
              'loyalty_points': newPoints,
              'total_debt': newDebt,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [customer.id],
          );
        }
      }

      return transaction.copyWith(
        id: txId,
        items: savedItems,
        payments: savedPayments,
      );
    });
  }

  Future<List<PosTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    int? shiftId,
    int? customerId,
    String? status,
    int limit = 100,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final args = <dynamic>[];

    if (from != null) {
      whereParts.add('created_at >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      whereParts.add('created_at <= ?');
      args.add(to.toUtc().toIso8601String());
    }
    if (shiftId != null) {
      whereParts.add('shift_id = ?');
      args.add(shiftId);
    }
    if (customerId != null) {
      whereParts.add('customer_id = ?');
      args.add(customerId);
    }
    if (status != null) {
      whereParts.add('status = ?');
      args.add(status);
    }

    final rows = await db.query(
      'transactions',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map((r) => PosTransaction.fromMap(r)).toList();
  }

  Future<PosTransaction?> getTransactionDetail(int transactionId) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final itemRows = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'id ASC',
    );
    final payRows = await db.query(
      'transaction_payments',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'id ASC',
    );

    return PosTransaction.fromMap(
      rows.first,
      items: itemRows.map(PosTransactionItem.fromMap).toList(),
      payments: payRows.map(TransactionPayment.fromMap).toList(),
    );
  }

  Future<void> voidTransaction(
    int transactionId, {
    int? userId,
    String reason = '',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final txRows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (txRows.isEmpty) throw StateError('Transaksi tidak ditemukan');
      final tx = PosTransaction.fromMap(txRows.first);
      if (tx.status == 'void') return;

      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'transactions',
        {
          'status': 'void',
          'notes':
              reason.isEmpty ? tx.notes : '${tx.notes} [VOID: $reason]'.trim(),
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      final itemRows = await txn.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      for (final r in itemRows) {
        final item = PosTransactionItem.fromMap(r);
        if (item.productId != null) {
          final prodRows = await txn.query(
            'products',
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );
          if (prodRows.isNotEmpty) {
            final prod = ProductItem.fromMap(prodRows.first);
            if (prod.trackStock) {
              final before = prod.stockQty;
              final after = before + item.qty;
              await txn.update(
                'products',
                {'stock_qty': after, 'updated_at': now},
                where: 'id = ?',
                whereArgs: [prod.id],
              );
              await txn.insert(
                'stock_movements',
                StockMovement(
                  productId: prod.id!,
                  movementType: 'void',
                  qtyDelta: item.qty,
                  stockBefore: before,
                  stockAfter: after,
                  referenceType: 'transaction',
                  referenceId: transactionId,
                  notes: 'Void ${tx.invoiceNo}',
                  userId: userId,
                  createdAt: now,
                ).toMap(),
              );
            }
          }
        }
      }

      if (tx.shiftId != null) {
        final payRows = await txn.query(
          'transaction_payments',
          where: "transaction_id = ? AND method = 'cash'",
          whereArgs: [transactionId],
        );
        int cashPaid = 0;
        for (final pr in payRows) {
          cashPaid += (pr['amount'] as num?)?.toInt() ?? 0;
        }
        final netCash = (cashPaid - tx.changeAmount).clamp(0, 1 << 62);
        if (netCash > 0) {
          await txn.rawUpdate(
            'UPDATE shifts SET expected_cash = MAX(0, expected_cash - ?) WHERE id = ?',
            [netCash, tx.shiftId],
          );
        }
      }

      if (tx.customerId != null && (tx.debtAmount > 0 || tx.pointsEarned > 0)) {
        final custRows = await txn.query(
          'customers',
          where: 'id = ?',
          whereArgs: [tx.customerId],
          limit: 1,
        );
        if (custRows.isNotEmpty) {
          final cust = CustomerItem.fromMap(custRows.first);
          await txn.update(
            'customers',
            {
              'total_debt': (cust.totalDebt - tx.debtAmount).clamp(0, 1 << 62),
              'loyalty_points':
                  (cust.loyaltyPoints - tx.pointsEarned).clamp(0, 1 << 62),
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [cust.id],
          );
        }
      }
    });
  }

  // =========================================================================
  // HELD CARTS & EXPENSES & PRINTER CONFIGS
  // =========================================================================

  Future<List<HeldCart>> getHeldCarts() async {
    final db = await database;
    final rows =
        await db.query('held_carts', orderBy: 'created_at DESC, id DESC');
    return rows.map(HeldCart.fromMap).toList();
  }

  Future<HeldCart> saveHeldCart(HeldCart cart) async {
    final db = await database;
    if (cart.id == null) {
      final id = await db.insert('held_carts', cart.toMap());
      return HeldCart(
        id: id,
        cartLabel: cart.cartLabel,
        orderType: cart.orderType,
        tableNumber: cart.tableNumber,
        customerId: cart.customerId,
        items: cart.items,
        discountAmount: cart.discountAmount,
        notes: cart.notes,
        userId: cart.userId,
        createdAt: cart.createdAt,
      );
    } else {
      await db.update(
        'held_carts',
        cart.toMap(),
        where: 'id = ?',
        whereArgs: [cart.id],
      );
      return cart;
    }
  }

  Future<int> deleteHeldCart(int id) async {
    final db = await database;
    return db.delete('held_carts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExpenseItem>> getExpenses({DateTime? from, DateTime? to}) async {
    final db = await database;
    final whereParts = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      whereParts.add('expense_date >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      whereParts.add('expense_date <= ?');
      args.add(to.toUtc().toIso8601String());
    }
    final rows = await db.query(
      'expenses',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'expense_date DESC, id DESC',
    );
    return rows.map(ExpenseItem.fromMap).toList();
  }

  Future<ExpenseItem> insertExpense(ExpenseItem expense) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('expenses', expense.toMap());
      if (expense.paymentSource == 'drawer' && expense.shiftId != null) {
        await txn.rawUpdate(
          'UPDATE shifts SET expected_cash = expected_cash - ? WHERE id = ?',
          [expense.amount, expense.shiftId],
        );
      }
      return ExpenseItem(
        id: id,
        category: expense.category,
        title: expense.title,
        amount: expense.amount,
        paymentSource: expense.paymentSource,
        shiftId: expense.shiftId,
        userId: expense.userId,
        notes: expense.notes,
        expenseDate: expense.expenseDate,
        createdAt: expense.createdAt,
      );
    });
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PrinterConfig>> getPrinterConfigs({String? roleType}) async {
    final db = await database;
    final rows = await db.query(
      'printer_configs',
      where: roleType != null ? 'role_type = ?' : null,
      whereArgs: roleType != null ? [roleType] : null,
      orderBy: 'is_default DESC, id ASC',
    );
    return rows.map(PrinterConfig.fromMap).toList();
  }

  Future<PrinterConfig?> getDefaultPrinter(String roleType) async {
    final db = await database;
    final rows = await db.query(
      'printer_configs',
      where: 'role_type = ?',
      whereArgs: [roleType],
      orderBy: 'is_default DESC, id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PrinterConfig.fromMap(rows.first);
  }

  Future<PrinterConfig> savePrinterConfig(PrinterConfig config) async {
    final db = await database;
    return db.transaction((txn) async {
      if (config.isDefault) {
        await txn.update(
          'printer_configs',
          {'is_default': 0},
          where: 'role_type = ?',
          whereArgs: [config.roleType],
        );
      }
      if (config.id == null) {
        final id = await txn.insert('printer_configs', config.toMap());
        return config.copyWith(id: id);
      } else {
        await txn.update(
          'printer_configs',
          config.toMap(),
          where: 'id = ?',
          whereArgs: [config.id],
        );
        return config;
      }
    });
  }

  Future<int> deletePrinterConfig(int id) async {
    final db = await database;
    return db.delete('printer_configs', where: 'id = ?', whereArgs: [id]);
  }

  // =========================================================================
  // PROFIT & LOSS SUMMARY
  // =========================================================================

  Future<ProfitLossSummary> getProfitLossSummary({
    required DateTime from,
    required DateTime to,
    int? userId,
  }) async {
    final db = await database;
    final fromIso = from.toUtc().toIso8601String();
    final toIso = to.toUtc().toIso8601String();

    final txWhere = StringBuffer(
        "status != 'void' AND created_at >= ? AND created_at <= ?");
    final txArgs = <dynamic>[fromIso, toIso];
    if (userId != null) {
      txWhere.write(' AND user_id = ?');
      txArgs.add(userId);
    }

    final salesRes = await db.rawQuery('''
      SELECT
        COUNT(*) AS tx_count,
        COALESCE(SUM(subtotal), 0) AS gross_sales,
        COALESCE(SUM(discount_amount), 0) AS discount_total,
        COALESCE(SUM(tax_amount), 0) AS tax_total,
        COALESCE(SUM(service_charge), 0) AS service_total,
        COALESCE(SUM(total_amount), 0) AS net_sales
      FROM transactions
      WHERE ${txWhere.toString()}
    ''', txArgs);

    final row = salesRes.first;
    final txCount = (row['tx_count'] as num?)?.toInt() ?? 0;
    final grossSales = (row['gross_sales'] as num?)?.toInt() ?? 0;
    final discountTotal = (row['discount_total'] as num?)?.toInt() ?? 0;
    final taxTotal = (row['tax_total'] as num?)?.toInt() ?? 0;
    final serviceTotal = (row['service_total'] as num?)?.toInt() ?? 0;
    final netSales = (row['net_sales'] as num?)?.toInt() ?? 0;

    final cogsRes = await db.rawQuery('''
      SELECT COALESCE(SUM(ti.qty * ti.cost_price), 0) AS total_cogs
      FROM transaction_items ti
      INNER JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.status != 'void' AND t.created_at >= ? AND t.created_at <= ?
      ${userId != null ? 'AND t.user_id = ?' : ''}
    ''', txArgs);
    final totalCogs = (cogsRes.first['total_cogs'] as num?)?.round() ?? 0;

    final expRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total_expenses
      FROM expenses
      WHERE expense_date >= ? AND expense_date <= ?
    ''', [fromIso, toIso]);
    final totalExpenses = (expRes.first['total_expenses'] as num?)?.toInt() ?? 0;

    final payRows = await db.rawQuery('''
      SELECT tp.method, COALESCE(SUM(tp.amount), 0) AS total_amount
      FROM transaction_payments tp
      INNER JOIN transactions t ON t.id = tp.transaction_id
      WHERE t.status != 'void' AND t.created_at >= ? AND t.created_at <= ?
      ${userId != null ? 'AND t.user_id = ?' : ''}
      GROUP BY tp.method
    ''', txArgs);
    final paymentBreakdown = <String, int>{};
    for (final pRow in payRows) {
      paymentBreakdown[(pRow['method'] ?? 'cash') as String] =
          (pRow['total_amount'] as num?)?.toInt() ?? 0;
    }

    final topProdRows = await db.rawQuery('''
      SELECT
        ti.product_name,
        COALESCE(SUM(ti.qty), 0) AS total_qty,
        COALESCE(SUM(ti.subtotal), 0) AS total_revenue,
        COALESCE(SUM(ti.subtotal - (ti.qty * ti.cost_price)), 0) AS total_margin
      FROM transaction_items ti
      INNER JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.status != 'void' AND t.created_at >= ? AND t.created_at <= ?
      ${userId != null ? 'AND t.user_id = ?' : ''}
      GROUP BY ti.product_name
      ORDER BY total_revenue DESC
      LIMIT 5
    ''', txArgs);

    final grossProfit = netSales - totalCogs;
    final netProfit = grossProfit - totalExpenses;

    return ProfitLossSummary(
      periodStart: from,
      periodEnd: to,
      transactionCount: txCount,
      grossSales: grossSales,
      discountTotal: discountTotal,
      taxTotal: taxTotal,
      serviceChargeTotal: serviceTotal,
      netSales: netSales,
      totalCogs: totalCogs,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      paymentBreakdown: paymentBreakdown,
      topProducts:
          topProdRows.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  // =========================================================================
  // BACKUP & RESTORE FULL JSON (17 TABEL ATOMIK)
  // =========================================================================

  static const List<String> _tableOrderParentFirst = [
    'stores',
    'users',
    'categories',
    'products',
    'customers',
    'suppliers',
    'shifts',
    'transactions',
    'transaction_items',
    'transaction_payments',
    'debt_payments',
    'stock_movements',
    'cash_flows',
    'purchases',
    'expenses',
    'held_carts',
    'printer_configs',
  ];

  Future<String> exportFullBackupJson() async {
    final db = await database;
    final tablesData = <String, List<Map<String, dynamic>>>{};
    for (final table in _tableOrderParentFirst) {
      final rows = await db.query(table);
      tablesData[table] = rows.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final payload = {
      'app': 'KasirPro Universal POS',
      'schema_version': _dbVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tablesData,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importFullBackupJson(String jsonString) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic> || decoded['tables'] is! Map) {
      throw const FormatException('Format file backup JSON tidak valid');
    }
    final tables = Map<String, dynamic>.from(decoded['tables'] as Map);
    final db = await database;

    await db.transaction((txn) async {
      for (final table in _tableOrderParentFirst.reversed) {
        await txn.delete(table);
      }
      for (final table in _tableOrderParentFirst) {
        final rawList = tables[table];
        if (rawList is List) {
          for (final row in rawList) {
            if (row is Map) {
              await txn.insert(table, Map<String, dynamic>.from(row));
            }
          }
        }
      }
    });
  }
}
