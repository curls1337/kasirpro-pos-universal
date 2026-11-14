import 'dart:convert';

String _nowIso() => DateTime.now().toUtc().toIso8601String();

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

double _asDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

bool _asBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  return s == '1' || s == 'true';
}

/// 1. Konfigurasi Toko & Jenis Usaha
class StoreConfig {
  final int? id;
  final String name;
  final String businessType; // 'retail' | 'fnb' | 'service'
  final String address;
  final String phone;
  final double taxPercent;
  final double serviceChargePercent;
  final String currencySymbol;
  final String receiptFooter;
  final String gatewayUrl;
  final String gatewayApiKey;
  final bool setupCompleted;
  final String createdAt;
  final String updatedAt;

  const StoreConfig({
    this.id,
    required this.name,
    this.businessType = 'retail',
    this.address = '',
    this.phone = '',
    this.taxPercent = 0.0,
    this.serviceChargePercent = 0.0,
    this.currencySymbol = 'Rp',
    this.receiptFooter = 'Terima kasih atas kunjungan Anda',
    this.gatewayUrl = '',
    this.gatewayApiKey = '',
    this.setupCompleted = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreConfig.create({
    required String name,
    String businessType = 'retail',
    String address = '',
    String phone = '',
    double taxPercent = 0.0,
    double serviceChargePercent = 0.0,
    String currencySymbol = 'Rp',
    String receiptFooter = 'Terima kasih atas kunjungan Anda',
    String gatewayUrl = '',
    String gatewayApiKey = '',
  }) {
    final now = _nowIso();
    return StoreConfig(
      name: name,
      businessType: businessType,
      address: address,
      phone: phone,
      taxPercent: taxPercent,
      serviceChargePercent: serviceChargePercent,
      currencySymbol: currencySymbol,
      receiptFooter: receiptFooter,
      gatewayUrl: gatewayUrl,
      gatewayApiKey: gatewayApiKey,
      setupCompleted: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  StoreConfig copyWith({
    int? id,
    String? name,
    String? businessType,
    String? address,
    String? phone,
    double? taxPercent,
    double? serviceChargePercent,
    String? currencySymbol,
    String? receiptFooter,
    String? gatewayUrl,
    String? gatewayApiKey,
    bool? setupCompleted,
    String? createdAt,
    String? updatedAt,
  }) {
    return StoreConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      businessType: businessType ?? this.businessType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      taxPercent: taxPercent ?? this.taxPercent,
      serviceChargePercent: serviceChargePercent ?? this.serviceChargePercent,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      gatewayUrl: gatewayUrl ?? this.gatewayUrl,
      gatewayApiKey: gatewayApiKey ?? this.gatewayApiKey,
      setupCompleted: setupCompleted ?? this.setupCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? _nowIso(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'business_type': businessType,
        'address': address,
        'phone': phone,
        'tax_percent': taxPercent,
        'service_charge_percent': serviceChargePercent,
        'currency_symbol': currencySymbol,
        'receipt_footer': receiptFooter,
        'gateway_url': gatewayUrl,
        'gateway_api_key': gatewayApiKey,
        'setup_completed': setupCompleted ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory StoreConfig.fromMap(Map<String, dynamic> map) => StoreConfig(
        id: map['id'] as int?,
        name: (map['name'] ?? '') as String,
        businessType: (map['business_type'] ?? 'retail') as String,
        address: (map['address'] ?? '') as String,
        phone: (map['phone'] ?? '') as String,
        taxPercent: _asDouble(map['tax_percent']),
        serviceChargePercent: _asDouble(map['service_charge_percent']),
        currencySymbol: (map['currency_symbol'] ?? 'Rp') as String,
        receiptFooter: (map['receipt_footer'] ?? '') as String,
        gatewayUrl: (map['gateway_url'] ?? '') as String,
        gatewayApiKey: (map['gateway_api_key'] ?? '') as String,
        setupCompleted: _asBool(map['setup_completed'], true),
        createdAt: (map['created_at'] ?? _nowIso()) as String,
        updatedAt: (map['updated_at'] ?? _nowIso()) as String,
      );
}

/// 2. Akun Pengguna / Staf (Owner, Admin, Kasir, Dapur)
class AppUser {
  final int? id;
  final String name;
  final String role; // 'owner' | 'admin' | 'cashier' | 'kitchen'
  final String pinHash;
  final String pinSalt;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const AppUser({
    this.id,
    required this.name,
    required this.role,
    required this.pinHash,
    required this.pinSalt,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Supervisor / Admin';
      case 'cashier':
        return 'Kasir';
      case 'kitchen':
        return 'Dapur';
      default:
        return role;
    }
  }

  AppUser copyWith({
    int? id,
    String? name,
    String? role,
    String? pinHash,
    String? pinSalt,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? _nowIso(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'role': role,
        'pin_hash': pinHash,
        'pin_salt': pinSalt,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as int?,
        name: (map['name'] ?? '') as String,
        role: (map['role'] ?? 'cashier') as String,
        pinHash: (map['pin_hash'] ?? '') as String,
        pinSalt: (map['pin_salt'] ?? '') as String,
        isActive: _asBool(map['is_active'], true),
        createdAt: (map['created_at'] ?? _nowIso()) as String,
        updatedAt: (map['updated_at'] ?? _nowIso()) as String,
      );
}

/// 3. Kategori Produk / Menu / Jasa
class CategoryItem {
  final int? id;
  final String name;
  final String iconName;
  final String colorHex;
  final int sortOrder;
  final bool isActive;
  final String createdAt;

  const CategoryItem({
    this.id,
    required this.name,
    this.iconName = 'category',
    this.colorHex = '#2563EB',
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory CategoryItem.create({
    required String name,
    String iconName = 'category',
    String colorHex = '#2563EB',
    int sortOrder = 0,
  }) {
    return CategoryItem(
      name: name,
      iconName: iconName,
      colorHex: colorHex,
      sortOrder: sortOrder,
      createdAt: _nowIso(),
    );
  }

  CategoryItem copyWith({
    int? id,
    String? name,
    String? iconName,
    String? colorHex,
    int? sortOrder,
    bool? isActive,
    String? createdAt,
  }) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon_name': iconName,
        'color_hex': colorHex,
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
      };

  factory CategoryItem.fromMap(Map<String, dynamic> map) => CategoryItem(
        id: map['id'] as int?,
        name: (map['name'] ?? '') as String,
        iconName: (map['icon_name'] ?? 'category') as String,
        colorHex: (map['color_hex'] ?? '#2563EB') as String,
        sortOrder: _asInt(map['sort_order']),
        isActive: _asBool(map['is_active'], true),
        createdAt: (map['created_at'] ?? _nowIso()) as String,
      );
}

/// 4. Produk / Menu F&B / Paket Jasa
class ProductItem {
  final int? id;
  final int? categoryId;
  final String? sku;
  final String? barcode;
  final String name;
  final String itemType; // 'goods' | 'fnb_menu' | 'service'
  final int sellPrice;
  final int costPrice;
  final double stockQty;
  final double minStock;
  final String unit;
  final String imageUrl;
  final bool trackStock;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const ProductItem({
    this.id,
    this.categoryId,
    this.sku,
    this.barcode,
    required this.name,
    this.itemType = 'goods',
    required this.sellPrice,
    this.costPrice = 0,
    this.stockQty = 0,
    this.minStock = 5,
    this.unit = 'pcs',
    this.imageUrl = '',
    this.trackStock = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => trackStock && stockQty > 0 && stockQty <= minStock;
  bool get isOutOfStock => trackStock && stockQty <= 0;
  double get marginPercent =>
      sellPrice > 0 ? ((sellPrice - costPrice) / sellPrice) * 100.0 : 0.0;

  factory ProductItem.create({
    int? categoryId,
    String? sku,
    String? barcode,
    required String name,
    String itemType = 'goods',
    required int sellPrice,
    int costPrice = 0,
    double stockQty = 0,
    double minStock = 5,
    String unit = 'pcs',
    String imageUrl = '',
    bool trackStock = true,
  }) {
    final now = _nowIso();
    return ProductItem(
      categoryId: categoryId,
      sku: sku,
      barcode: barcode,
      name: name,
      itemType: itemType,
      sellPrice: sellPrice,
      costPrice: costPrice,
      stockQty: stockQty,
      minStock: minStock,
      unit: unit,
      imageUrl: imageUrl,
      trackStock: trackStock,
      createdAt: now,
      updatedAt: now,
    );
  }

  ProductItem copyWith({
    int? id,
    int? categoryId,
    String? sku,
    String? barcode,
    String? name,
    String? itemType,
    int? sellPrice,
    int? costPrice,
    double? stockQty,
    double? minStock,
    String? unit,
    String? imageUrl,
    bool? trackStock,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      itemType: itemType ?? this.itemType,
      sellPrice: sellPrice ?? this.sellPrice,
      costPrice: costPrice ?? this.costPrice,
      stockQty: stockQty ?? this.stockQty,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      trackStock: trackStock ?? this.trackStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? _nowIso(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category_id': categoryId,
        'sku': (sku != null && sku!.trim().isEmpty) ? null : sku,
        'barcode': barcode,
        'name': name,
        'item_type': itemType,
        'sell_price': sellPrice,
        'cost_price': costPrice,
        'stock_qty': stockQty,
        'min_stock': minStock,
        'unit': unit,
        'image_url': imageUrl,
        'track_stock': trackStock ? 1 : 0,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory ProductItem.fromMap(Map<String, dynamic> map) => ProductItem(
        id: map['id'] as int?,
        categoryId: map['category_id'] as int?,
        sku: map['sku'] as String?,
        barcode: map['barcode'] as String?,
        name: (map['name'] ?? '') as String,
        itemType: (map['item_type'] ?? 'goods') as String,
        sellPrice: _asInt(map['sell_price']),
        costPrice: _asInt(map['cost_price']),
        stockQty: _asDouble(map['stock_qty']),
        minStock: _asDouble(map['min_stock'], 5.0),
        unit: (map['unit'] ?? 'pcs') as String,
        imageUrl: (map['image_url'] ?? '') as String,
        trackStock: _asBool(map['track_stock'], true),
        isActive: _asBool(map['is_active'], true),
        createdAt: (map['created_at'] ?? _nowIso()) as String,
        updatedAt: (map['updated_at'] ?? _nowIso()) as String,
      );
}

/// 5. Audit Trail Mutasi Stok
class StockMovement {
  final int? id;
  final int productId;
  final String movementType; // 'in' | 'out' | 'opname' | 'sale' | 'purchase' | 'void'
  final double qtyDelta;
  final double stockBefore;
  final double stockAfter;
  final String? referenceType;
  final int? referenceId;
  final String notes;
  final int? userId;
  final String createdAt;

  const StockMovement({
    this.id,
    required this.productId,
    required this.movementType,
    required this.qtyDelta,
    required this.stockBefore,
    required this.stockAfter,
    this.referenceType,
    this.referenceId,
    this.notes = '',
    this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'movement_type': movementType,
        'qty_delta': qtyDelta,
        'stock_before': stockBefore,
        'stock_after': stockAfter,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'notes': notes,
        'user_id': userId,
        'created_at': createdAt,
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as int?,
        productId: _asInt(map['product_id']),
        movementType: (map['movement_type'] ?? 'opname') as String,
        qtyDelta: _asDouble(map['qty_delta']),
        stockBefore: _asDouble(map['stock_before']),
        stockAfter: _asDouble(map['stock_after']),
        referenceType: map['reference_type'] as String?,
        referenceId: map['reference_id'] as int?,
        notes: (map['notes'] ?? '') as String,
        userId: map['user_id'] as int?,
        createdAt: (map['created_at'] ?? _nowIso()) as String,
      );
}

/// 6. Pelanggan, Poin Loyalitas & Buku Kasbon/Piutang
class CustomerItem {
  final int? id;
  final String name;
  final String phone;
  final String address;
  final String notes;
  final int creditLimit;
  final int totalDebt;
  final int loyaltyPoints;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const CustomerItem({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
    this.creditLimit = 0,
    this.totalDebt = 0,
    this.loyaltyPoints = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasDebt => totalDebt > 0;

  factory CustomerItem.create({
    required String name,
    String phone = '',
    String address = '',
    String notes = '',
    int creditLimit = 0,
  }) {
    final now = _nowIso();
    return CustomerItem(
      name: name,
      phone: phone,
      address: address,
      notes: notes,
      creditLimit: creditLimit,
      createdAt: now,
      updatedAt: now,
    );
  }

  CustomerItem copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    int? creditLimit,
    int? totalDebt,
    int? loyaltyPoints,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return CustomerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      creditLimit: creditLimit ?? this.creditLimit,
      totalDebt: totalDebt ?? this.totalDebt,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? _nowIso(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'credit_limit': creditLimit,
        'total_debt': totalDebt,
        'loyalty_points': loyaltyPoints,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory CustomerItem.fromMap(Map<String, dynamic> map) => CustomerItem(
        id: map['id'] as int?,
        name: (map['name'] ?? '') as String,
        phone: (map['phone'] ?? '') as String,
        address: (map['address'] ?? '') as String,
        notes: (map['notes'] ?? '') as String,
        creditLimit: _asInt(map['credit_limit']),
        totalDebt: _asInt(map['total_debt']),
        loyaltyPoints: _asInt(map['loyalty_points']),
        isActive: _asBool(map['is_active'], true),
        createdAt: (map['created_at'] ?? _nowIso()) as String,
        updatedAt: (map['updated_at'] ?? _nowIso()) as String,
      );
}

/// 7. Cicilan / Pelunasan Kasbon
class DebtPayment {
  final int? id;
  final int customerId;
  final int? transactionId;
  final int? shiftId;
  final int? userId;
  final int amount;
  final String paymentMethod; // 'cash' | 'qris' | 'transfer' | 'debit'
  final String notes;
  final String createdAt;

  const DebtPayment({
    this.id,
    required this.customerId,
    this.transactionId,
    this.shiftId,
    this.userId,
    required this.amount,
    this.paymentMethod = 'cash',
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'customer_id': customerId,
        'transaction_id': transactionId,
        'shift_id': shiftId,
        'user_id': userId,
        'amount': amount,
        'payment_method': paymentMethod,
        'notes': notes,
        'created_at': createdAt,
      };

  factory DebtPayment.fromMap(Map<String, dynamic> map) => DebtPayment(
        id: map['id'] as int?,
        customerId: _asInt(map['customer_id']),
        transactionId: map['transaction_id'] as int?,
        shiftId: map['shift_id'] as int?,
        userId: map['user_id'] as int?,
        amount: _asInt(map['amount']),
        paymentMethod: (map['payment_method'] ?? 'cash') as String,
        notes: (map['notes'] ?? '') as String,
        createdAt: (map['created_at'] ?? _nowIso()) as String,
      );
}

/// 8. Data Pemasok (Supplier)
class SupplierItem {
  final int? id;
  final String name;
  final String phone;
  final String address;
  final String contactPerson;
  final String notes;
  final bool isActive;
  final String createdAt;

  const SupplierItem({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.contactPerson = '',
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
  });

  factory SupplierItem.create({
    required String name,
    String phone = '',
    String address = '',
    String contactPerson = '',
    String notes = '',
  }) {
    return SupplierItem(
      name: name,
      phone: phone,
      address: address,
      contactPerson: contactPerson,
      notes: notes,
      createdAt: _nowIso(),
    );
  }

  SupplierItem copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? contactPerson,
    String? notes,
    bool? isActive,
    String? createdAt,
  }) {
    return SupplierItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'contact_person': contactPerson,
        'notes': notes,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
      };

  factory SupplierItem.fromMap(Map<String, dynamic> map) => SupplierItem(
        id: map['id'] as int?,
        name: (map['name'] ?? '') as String,
        phone: (map['phone'] ?? '') as String,
        address: (map['address'] ?? '') as String,
        contactPerson: (map['contact_person'] ?? '') as String,
        notes: (map['notes'] ?? '') as String,
        isActive: _asBool(map['is_active'], true),
        createdAt: (map['created_at'] ?? _nowIso()) as String,
      );
}

/// Item Pembelian / Kulakan dalam PurchaseOrder
class PurchaseOrderItem {
  final int productId;
  final String name;
  final double qty;
  final int buyPrice;

  const PurchaseOrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.buyPrice,
  });

  int get subtotal => (qty * buyPrice).round();

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'name': name,
        'qty': qty,
        'buy_price': buyPrice,
        'subtotal': subtotal,
      };

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) =>
      PurchaseOrderItem(
        productId: _asInt(map['product_id']),
        name: (map['name'] ?? '') as String,
        qty: _asDouble(map['qty']),
        buyPrice: _asInt(map['buy_price']),
      );
}

/// 9. Transaksi Kulakan / Pembelian Stok dari Supplier
class PurchaseOrder {
  final int? id;
  final String invoiceNo;
  final int? supplierId;
  final int? userId;
  final List<PurchaseOrderItem> items;
  final int totalAmount;
  final String paymentStatus; // 'paid' | 'debt'
  final String notes;
  final String purchasedAt;
  final String createdAt;

  const PurchaseOrder({
    this.id,
    required this.invoiceNo,
    this.supplierId,
    this.userId,
    required this.items,
    required this.totalAmount,
    this.paymentStatus = 'paid',
    this.notes = '',
    required this.purchasedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'supplier_id': supplierId,
        'user_id': userId,
        'items_json': jsonEncode(items.map((e) => e.toMap()).toList()),
        'total_amount': totalAmount,
        'payment_status': paymentStatus,
        'notes': notes,
        'purchased_at': purchasedAt,
        'created_at': createdAt,
      };

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    final rawJson = (map['items_json'] ?? '[]') as String;
    final decoded = jsonDecode(rawJson) as List<dynamic>;
    return PurchaseOrder(
      id: map['id'] as int?,
      invoiceNo: (map['invoice_no'] ?? '') as String,
      supplierId: map['supplier_id'] as int?,
      userId: map['user_id'] as int?,
      items: decoded
          .map((e) => PurchaseOrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalAmount: _asInt(map['total_amount']),
      paymentStatus: (map['payment_status'] ?? 'paid') as String,
      notes: (map['notes'] ?? '') as String,
      purchasedAt: (map['purchased_at'] ?? _nowIso()) as String,
      createdAt: (map['created_at'] ?? _nowIso()) as String,
    );
  }
}

/// 10. Shift Kasir & Rekonsiliasi Laci Kas
class ShiftSession {
  final int? id;
  final int userId;
  final String openedAt;
  final String? closedAt;
  final int openingCash;
  final int expectedCash;
  final int? actualCash;
  final int cashDifference;
  final String status; // 'open' | 'closed'
  final String notes;

  const ShiftSession({
    this.id,
    required this.userId,
    required this.openedAt,
    this.closedAt,
    required this.openingCash,
    this.expectedCash = 0,
    this.actualCash,
    this.cashDifference = 0,
    this.status = 'open',
    this.notes = '',
  });

  bool get isOpen => status == 'open';

  ShiftSession copyWith({
    int? id,
    int? userId,
    String? openedAt,
    String? closedAt,
    int? openingCash,
    int? expectedCash,
    int? actualCash,
    int? cashDifference,
    String? status,
    String? notes,
  }) {
    return ShiftSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      openingCash: openingCash ?? this.openingCash,
      expectedCash: expectedCash ?? this.expectedCash,
      actualCash: actualCash ?? this.actualCash,
      cashDifference: cashDifference ?? this.cashDifference,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'opened_at': openedAt,
        'closed_at': closedAt,
        'opening_cash': openingCash,
        'expected_cash': expectedCash,
        'actual_cash': actualCash,
        'cash_difference': cashDifference,
        'status': status,
        'notes': notes,
      };

  factory ShiftSession.fromMap(Map<String, dynamic> map) => ShiftSession(
        id: map['id'] as int?,
        userId: _asInt(map['user_id']),
        openedAt: (map['opened_at'] ?? _nowIso()) as String,
        closedAt: map['closed_at'] as String?,
        openingCash: _asInt(map['opening_cash']),
        expectedCash: _asInt(map['expected_cash']),
        actualCash: map['actual_cash'] != null ? _asInt(map['actual_cash']) : null,
        cashDifference: _asInt(map['cash_difference']),
        status: (map['status'] ?? 'open') as String,
        notes: (map['notes'] ?? '') as String,
      );
}

/// 11. Kas Masuk / Kas Keluar Manual pada Shift
class CashFlowItem {
  final int? id;
  final int shiftId;
  final String type; // 'cash_in' | 'cash_out'
  final int amount;
  final String category;
  final String notes;
  final int? userId;
  final String createdAt;

  const CashFlowItem({
    this.id,
    required this.shiftId,
    required this.type,
    required this.amount,
    this.category = 'general',
    this.notes = '',
    this.userId,
    required this.createdAt,
  });

  bool get isCashIn => type == 'cash_in';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'shift_id': shiftId,
        'type': type,
        'amount': amount,
        'category': category,
        'notes': notes,
        'user_id': userId,
        'created_at': createdAt,
      };

  factory CashFlowItem.fromMap(Map<String, dynamic> map) => CashFlowItem(
        id: map['id'] as int?,
        shiftId: _asInt(map['shift_id']),
        type: (map['type'] ?? 'cash_in') as String,
        amount: _asInt(map['amount']),
        category: (map['category'] ?? 'general') as String,
        notes: (map['notes'] ?? '') as String,
        userId: map['user_id'] as int?,
        createdAt: (map['created_at'] ?? _nowIso()) as String,
      );
}

/// 12. Item Keranjang Aktif / Parkir
class CartItem {
  final int? productId;
  final String productName;
  final String sku;
  final String unit;
  final double qty;
  final int unitPrice;
  final int costPrice;
  final int discountAmount;
  final String itemNotes;
  final String itemType; // 'goods' | 'fnb_menu' | 'service'

  const CartItem({
    this.productId,
    required this.productName,
    this.sku = '',
    this.unit = 'pcs',
    this.qty = 1.0,
    required this.unitPrice,
    this.costPrice = 0,
    this.discountAmount = 0,
    this.itemNotes = '',
    this.itemType = 'goods',
  });

  int get grossSubtotal => (qty * unitPrice).round();
  int get subtotal => (grossSubtotal - discountAmount).clamp(0, 1 << 62);

  CartItem copyWith({
    int? productId,
    String? productName,
    String? sku,
    String? unit,
    double? qty,
    int? unitPrice,
    int? costPrice,
    int? discountAmount,
    String? itemNotes,
    String? itemType,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      itemNotes: itemNotes ?? this.itemNotes,
      itemType: itemType ?? this.itemType,
    );
  }

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'unit': unit,
        'qty': qty,
        'unit_price': unitPrice,
        'cost_price': costPrice,
        'discount_amount': discountAmount,
        'item_notes': itemNotes,
        'item_type': itemType,
      };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
        productId: map['product_id'] as int?,
        productName: (map['product_name'] ?? '') as String,
        sku: (map['sku'] ?? '') as String,
        unit: (map['unit'] ?? 'pcs') as String,
        qty: _asDouble(map['qty'], 1.0),
        unitPrice: _asInt(map['unit_price']),
        costPrice: _asInt(map['cost_price']),
        discountAmount: _asInt(map['discount_amount']),
        itemNotes: (map['item_notes'] ?? '') as String,
        itemType: (map['item_type'] ?? 'goods') as String,
      );
}

/// Detail Item Transaksi (table transaction_items)
class PosTransactionItem {
  final int? id;
  final int? transactionId;
  final int? productId;
  final String productName;
  final String sku;
  final double qty;
  final int unitPrice;
  final int costPrice;
  final int discountAmount;
  final int subtotal;
  final String itemNotes;
  final String kitchenStatus; // 'none' | 'queued' | 'preparing' | 'served'

  const PosTransactionItem({
    this.id,
    this.transactionId,
    this.productId,
    required this.productName,
    this.sku = '',
    required this.qty,
    required this.unitPrice,
    this.costPrice = 0,
    this.discountAmount = 0,
    required this.subtotal,
    this.itemNotes = '',
    this.kitchenStatus = 'none',
  });

  factory PosTransactionItem.fromCartItem(
    CartItem cart, {
    String kitchenStatus = 'none',
  }) {
    return PosTransactionItem(
      productId: cart.productId,
      productName: cart.productName,
      sku: cart.sku,
      qty: cart.qty,
      unitPrice: cart.unitPrice,
      costPrice: cart.costPrice,
      discountAmount: cart.discountAmount,
      subtotal: cart.subtotal,
      itemNotes: cart.itemNotes,
      kitchenStatus: kitchenStatus,
    );
  }

  PosTransactionItem copyWith({
    int? id,
    int? transactionId,
    String? kitchenStatus,
  }) {
    return PosTransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      productId: productId,
      productName: productName,
      sku: sku,
      qty: qty,
      unitPrice: unitPrice,
      costPrice: costPrice,
      discountAmount: discountAmount,
      subtotal: subtotal,
      itemNotes: itemNotes,
      kitchenStatus: kitchenStatus ?? this.kitchenStatus,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (transactionId != null) 'transaction_id': transactionId,
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'qty': qty,
        'unit_price': unitPrice,
        'cost_price': costPrice,
        'discount_amount': discountAmount,
        'subtotal': subtotal,
        'item_notes': itemNotes,
        'kitchen_status': kitchenStatus,
      };

  factory PosTransactionItem.fromMap(Map<String, dynamic> map) =>
      PosTransactionItem(
        id: map['id'] as int?,
        transactionId: map['transaction_id'] as int?,
        productId: map['product_id'] as int?,
        productName: (map['product_name'] ?? '') as String,
        sku: (map['sku'] ?? '') as String,
        qty: _asDouble(map['qty']),
        unitPrice: _asInt(map['unit_price']),
        costPrice: _asInt(map['cost_price']),
        discountAmount: _asInt(map['discount_amount']),
        subtotal: _asInt(map['subtotal']),
        itemNotes: (map['item_notes'] ?? '') as String,
        kitchenStatus: (map['kitchen_status'] ?? 'none') as String,
      );
}

/// 13. Header Transaksi Penjualan
class PosTransaction {
  final int? id;
  final String invoiceNo;
  final int? shiftId;
  final int? userId;
  final int? customerId;
  final String orderType; // 'retail' | 'dine_in' | 'takeaway' | 'service'
  final String tableNumber;
  final int subtotal;
  final int discountAmount;
  final int taxAmount;
  final int serviceCharge;
  final int totalAmount;
  final int paidAmount;
  final int changeAmount;
  final int debtAmount;
  final int pointsEarned;
  final String status; // 'completed' | 'partial_debt' | 'void'
  final String notes;
  final String createdAt;
  final List<PosTransactionItem> items;
  final List<TransactionPayment> payments;

  const PosTransaction({
    this.id,
    required this.invoiceNo,
    this.shiftId,
    this.userId,
    this.customerId,
    this.orderType = 'retail',
    this.tableNumber = '',
    required this.subtotal,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.serviceCharge = 0,
    required this.totalAmount,
    required this.paidAmount,
    this.changeAmount = 0,
    this.debtAmount = 0,
    this.pointsEarned = 0,
    this.status = 'completed',
    this.notes = '',
    required this.createdAt,
    this.items = const [],
    this.payments = const [],
  });

  PosTransaction copyWith({
    int? id,
    String? invoiceNo,
    int? shiftId,
    int? userId,
    int? customerId,
    String? orderType,
    String? tableNumber,
    int? subtotal,
    int? discountAmount,
    int? taxAmount,
    int? serviceCharge,
    int? totalAmount,
    int? paidAmount,
    int? changeAmount,
    int? debtAmount,
    int? pointsEarned,
    String? status,
    String? notes,
    String? createdAt,
    List<PosTransactionItem>? items,
    List<TransactionPayment>? payments,
  }) {
    return PosTransaction(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      shiftId: shiftId ?? this.shiftId,
      userId: userId ?? this.userId,
      customerId: customerId ?? this.customerId,
      orderType: orderType ?? this.orderType,
      tableNumber: tableNumber ?? this.tableNumber,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      debtAmount: debtAmount ?? this.debtAmount,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      payments: payments ?? this.payments,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'shift_id': shiftId,
        'user_id': userId,
        'customer_id': customerId,
        'order_type': orderType,
        'table_number': tableNumber,
        'subtotal': subtotal,
        'discount_amount': discountAmount,
        'tax_amount': taxAmount,
        'service_charge': serviceCharge,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'change_amount': changeAmount,
        'debt_amount': debtAmount,
        'points_earned': pointsEarned,
        'status': status,
        'notes': notes,
        'created_at': createdAt,
      };

  factory PosTransaction.fromMap(
    Map<String, dynamic> map, {
    List<PosTransactionItem> items = const [],
    List<TransactionPayment> payments = const [],
  }) =>
      PosTransaction(
        id: map['id'] as int?,
        invoiceNo: (map['invoice_no'] ?? '') as String,
        shiftId: map['shift_id'] as int?,
        userId: map['user_id'] as int?,
        customerId: map['customer_id'] as int?,
        orderType: (map['order_type'] ?? 'retail') as String,
        tableNumber: (map['table_number'] ?? '') as String,
        subtotal: _asInt(map['subtotal']),
        discountAmount: _asInt(map['discount_amount']),
        taxAmount: _asInt(map['tax_amount']),
        serviceCharge: _asInt(map['service_charge']),
        totalAmount: _asInt(map['total_amount']),
        paidAmount: _asInt(map['paid_amount']),
        changeAmount: _asInt(map['change_amount']),
        debtAmount: _asInt(map['debt_amount']),
        pointsEarned: _asInt(map['points_earned']),
        status: (map['status'] ?? 'completed') as String,
        notes: (map['notes'] ?? '') as String,
        createdAt: (map['created_at'] ?? _nowIso()) as String,
        items: items,
        payments: payments,
      );
}

/// 14. Split Payment per Transaksi
class TransactionPayment {
  final int? id;
  final int? transactionId;
  final String method; // 'cash' | 'qris' | 'transfer' | 'debit' | 'kasbon'
  final int amount;
  final String referenceNo;
  final String createdAt;

  const TransactionPayment({
    this.id,
    this.transactionId,
    required this.method,
    required this.amount,
    this.referenceNo = '',
    required this.createdAt,
  });

  String get methodLabel {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer';
      case 'debit':
        return 'Kartu/EDC';
      case 'kasbon':
        return 'Kasbon';
      default:
        return method.toUpperCase();
    }
  }

  TransactionPayment copyWith({int? id, int? transactionId}) {
    return TransactionPayment(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      method: method,
      amount: amount,
      referenceNo: referenceNo,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (transactionId != null) 'transaction_id': transactionId,
        'method': method,
        'amount': amount,
        'reference_no': referenceNo,
        'created_at': createdAt,
      };

  factory TransactionPayment.fromMap(Map<String, dynamic> map) =>
      TransactionPayment(
        id: map['id'] as int?,
        transactionId: map['transaction_id'] as int?,
        method: (map['method'] ?? 'cash') as String,
        amount: _asInt(map['amount']),
        referenceNo: (map['reference_no'] ?? '') as String,
        createdAt: (map['created_at'] ?? _nowIso()) as String,
      );
}

/// 15. Pengeluaran Operasional Toko
class ExpenseItem {
  final int? id;
  final String category;
  final String title;
  final int amount;
  final String paymentSource; // 'drawer' | 'non_drawer'
  final int? shiftId;
  final int? userId;
  final String notes;
  final String expenseDate;
  final String createdAt;

  const ExpenseItem({
    this.id,
    required this.category,
    required this.title,
    required this.amount,
    this.paymentSource = 'non_drawer',
    this.shiftId,
    this.userId,
    this.notes = '',
    required this.expenseDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category': category,
        'title': title,
        'amount': amount,
        'payment_source': paymentSource,
        'shift_id': shiftId,
        'user_id': userId,
        'notes': notes,
        'expense_date': expenseDate,
        'created_at': createdAt,
      };

  factory ExpenseItem.fromMap(Map<String, dynamic> map) => ExpenseItem(
        id: map['id'] as int?,
        category: (map['category'] ?? 'Operasional') as String,
        title: (map['title'] ?? '') as String,
        amount: _asInt(map['amount']),
        paymentSource: (map['payment_source'] ?? 'non_drawer') as String,
        shiftId: map['shift_id'] as int?,
        userId: map['user_id'] as int?,
        notes: (map['notes'] ?? '') as String,
        expenseDate: (map['expense_date'] ?? _nowIso()) as String,
        createdAt: (map['created_at'] ?? _nowIso()) as String,
      );
}

/// 16. Parkir Keranjang (Hold Order / Open Bill)
class HeldCart {
  final int? id;
  final String cartLabel;
  final String orderType;
  final String tableNumber;
  final int? customerId;
  final List<CartItem> items;
  final int discountAmount;
  final String notes;
  final int? userId;
  final String createdAt;

  const HeldCart({
    this.id,
    required this.cartLabel,
    this.orderType = 'retail',
    this.tableNumber = '',
    this.customerId,
    required this.items,
    this.discountAmount = 0,
    this.notes = '',
    this.userId,
    required this.createdAt,
  });

  int get totalEstimate {
    final sum = items.fold<int>(0, (acc, e) => acc + e.subtotal);
    return (sum - discountAmount).clamp(0, 1 << 62);
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'cart_label': cartLabel,
        'order_type': orderType,
        'table_number': tableNumber,
        'customer_id': customerId,
        'items_json': jsonEncode(items.map((e) => e.toMap()).toList()),
        'discount_amount': discountAmount,
        'notes': notes,
        'user_id': userId,
        'created_at': createdAt,
      };

  factory HeldCart.fromMap(Map<String, dynamic> map) {
    final rawJson = (map['items_json'] ?? '[]') as String;
    final decoded = jsonDecode(rawJson) as List<dynamic>;
    return HeldCart(
      id: map['id'] as int?,
      cartLabel: (map['cart_label'] ?? '') as String,
      orderType: (map['order_type'] ?? 'retail') as String,
      tableNumber: (map['table_number'] ?? '') as String,
      customerId: map['customer_id'] as int?,
      items: decoded
          .map((e) => CartItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      discountAmount: _asInt(map['discount_amount']),
      notes: (map['notes'] ?? '') as String,
      userId: map['user_id'] as int?,
      createdAt: (map['created_at'] ?? _nowIso()) as String,
    );
  }
}

/// 17. Konfigurasi Printer (Struk, Dapur, Label Barcode)
class PrinterConfig {
  final int? id;
  final String name;
  final String roleType; // 'receipt' | 'kitchen' | 'label'
  final String connectionType; // 'bluetooth' | 'wifi_tcp' | 'system_pdf'
  final String addressOrIp;
  final int port;
  final int paperWidthMm; // 58 | 80
  final String labelSize; // '30x20' | '40x30' | '50x30' | '58x40'
  final String commandLang; // 'escpos' | 'tspl' | 'cpcl' | 'pdf'
  final bool isDefault;
  final bool autoPrint;
  final bool openDrawer;
  final String createdAt;

  const PrinterConfig({
    this.id,
    required this.name,
    this.roleType = 'receipt',
    this.connectionType = 'bluetooth',
    this.addressOrIp = '',
    this.port = 9100,
    this.paperWidthMm = 58,
    this.labelSize = '40x30',
    this.commandLang = 'escpos',
    this.isDefault = false,
    this.autoPrint = false,
    this.openDrawer = false,
    required this.createdAt,
  });

  PrinterConfig copyWith({
    int? id,
    String? name,
    String? roleType,
    String? connectionType,
    String? addressOrIp,
    int? port,
    int? paperWidthMm,
    String? labelSize,
    String? commandLang,
    bool? isDefault,
    bool? autoPrint,
    bool? openDrawer,
    String? createdAt,
  }) {
    return PrinterConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      roleType: roleType ?? this.roleType,
      connectionType: connectionType ?? this.connectionType,
      addressOrIp: addressOrIp ?? this.addressOrIp,
      port: port ?? this.port,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      labelSize: labelSize ?? this.labelSize,
      commandLang: commandLang ?? this.commandLang,
      isDefault: isDefault ?? this.isDefault,
      autoPrint: autoPrint ?? this.autoPrint,
      openDrawer: openDrawer ?? this.openDrawer,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'role_type': roleType,
        'connection_type': connectionType,
        'address_or_ip': addressOrIp,
        'port': port,
        'paper_width_mm': paperWidthMm,
        'label_size': labelSize,
        'command_lang': commandLang,
        'is_default': isDefault ? 1 : 0,
        'auto_print': autoPrint ? 1 : 0,
        'open_drawer': openDrawer ? 1 : 0,
        'created_at': createdAt,
      };

  factory PrinterConfig.fromMap(Map<String, dynamic> map) => PrinterConfig(
        id: map['id'] as int?,
        name: (map['name'] ?? '') as String,
        roleType: (map['role_type'] ?? 'receipt') as String,
        connectionType: (map['connection_type'] ?? 'bluetooth') as String,
        addressOrIp: (map['address_or_ip'] ?? '') as String,
        port: _asInt(map['port'], 9100),
        paperWidthMm: _asInt(map['paper_width_mm'], 58),
        labelSize: (map['label_size'] ?? '40x30') as String,
        commandLang: (map['command_lang'] ?? 'escpos') as String,
        isDefault: _asBool(map['is_default']),
        autoPrint: _asBool(map['auto_print']),
        openDrawer: _asBool(map['open_drawer']),
        createdAt: (map['created_at'] ?? _nowIso()) as String,
      );
}

/// 18. Preset Ukuran Label Thermal Barcode
class LabelSizePreset {
  final String code;
  final String displayName;
  final int widthMm;
  final int heightMm;
  final int gapMm;
  final int dpi; // umumnya 203 dpi = 8 dots/mm

  const LabelSizePreset({
    required this.code,
    required this.displayName,
    required this.widthMm,
    required this.heightMm,
    this.gapMm = 2,
    this.dpi = 203,
  });

  int get dotsPerMm => (dpi / 25.4).round(); // ~8 dots/mm untuk 203 DPI
  int get widthDots => widthMm * dotsPerMm;
  int get heightDots => heightMm * dotsPerMm;

  static const LabelSizePreset size30x20 = LabelSizePreset(
    code: '30x20',
    displayName: '30 × 20 mm (Mini Harga)',
    widthMm: 30,
    heightMm: 20,
  );

  static const LabelSizePreset size40x30 = LabelSizePreset(
    code: '40x30',
    displayName: '40 × 30 mm (Standar Retail)',
    widthMm: 40,
    heightMm: 30,
  );

  static const LabelSizePreset size50x30 = LabelSizePreset(
    code: '50x30',
    displayName: '50 × 30 mm (Barcode Lebar)',
    widthMm: 50,
    heightMm: 30,
  );

  static const LabelSizePreset size58x40 = LabelSizePreset(
    code: '58x40',
    displayName: '58 × 40 mm (Resi / Cup Besar)',
    widthMm: 58,
    heightMm: 40,
  );

  static const List<LabelSizePreset> presets = [
    size30x20,
    size40x30,
    size50x30,
    size58x40,
  ];

  static LabelSizePreset fromCode(String code) {
    return presets.firstWhere(
      (p) => p.code == code,
      orElse: () => size40x30,
    );
  }
}

/// Ringkasan Laporan Laba Rugi (Profit & Loss)
class ProfitLossSummary {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int transactionCount;
  final int grossSales;
  final int discountTotal;
  final int taxTotal;
  final int serviceChargeTotal;
  final int netSales;
  final int totalCogs;
  final int grossProfit;
  final int totalExpenses;
  final int netProfit;
  final Map<String, int> paymentBreakdown;
  final List<Map<String, dynamic>> topProducts;

  const ProfitLossSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.transactionCount,
    required this.grossSales,
    required this.discountTotal,
    required this.taxTotal,
    required this.serviceChargeTotal,
    required this.netSales,
    required this.totalCogs,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.paymentBreakdown,
    required this.topProducts,
  });

  double get grossMarginPercent =>
      netSales > 0 ? (grossProfit / netSales) * 100.0 : 0.0;

  double get netMarginPercent =>
      netSales > 0 ? (netProfit / netSales) * 100.0 : 0.0;
}
