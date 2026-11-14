# ARCHITECTURE_POS.md — Spesifikasi Arsitektur POS Universal (Production-Ready)

Dokumen ini merupakan cetak biru arsitektur produksi untuk aplikasi **POS Universal** berbasis **Flutter (iOS `.ipa` & Android `.apk`)** dengan penyimpanan lokal persisten **SQLite (`sqflite`)**, tanpa mode demo/dummy, mendukung sektor **Retail/Minimarket**, **F&B (Meja, Dine-In/Takeaway, Catatan Item, Tiket Dapur)**, dan **Jasa**, serta pencetakan **Thermal Struk (ESC/POS 58mm/80mm)** dan **Thermal Label/Barcode Sticker (TSPL/ZPL + PDF)**.

---

## 1. Tech Stack & Prinsip Arsitektur

| Komponen | Pilihan Teknologi | Keterangan |
| :--- | :--- | :--- |
| **Framework Mobile** | Flutter (Channel `stable`, Dart `>=3.3.0 <4.0.0`) | Single codebase untuk iOS & Android |
| **Database Lokal** | SQLite via `sqflite` (`PRAGMA foreign_keys = ON`, `WAL`) | 100% offline-first, persisten nyata di perangkat |
| **Keamanan PIN** | Salted SHA-256 (`crypto`) | PIN tidak pernah disimpan plaintext di SQLite |
| **Printer Struk** | Pure-Dart ESC/POS Generator (`escpos_service.dart`) | 58mm (32 char) & 80mm (48 char), Drawer Kick, Cut |
| **Printer Label** | Pure-Dart TSPL & ZPL Generator (`tspl_label_service.dart`) | 30x20mm, 40x30mm, 50x30mm + Barcode Code128 |
| **Transport Printer** | Bluetooth (`print_bluetooth_thermal`), WiFi TCP (`dart:io` Socket `:9100`), System PDF (`pdf` + `printing`) | Unified routing via `PrinterManager` |
| **CI/CD Build** | GitHub Actions (`ubuntu-latest` APK + `macos-latest` unsigned IPA) | Zero-Local-Build di server Linux |

---

## 2. Struktur Folder Modular Flutter (`pos_universal/lib/`)

```text
pos_universal/
├── .github/
│   └── workflows/
│       └── build-mobile.yml           # CI/CD Android .apk & iOS .ipa + GitHub Release
├── pubspec.yaml                       # Dependensi stabil & kompatibel iOS/Android
├── ARCHITECTURE_POS.md                # Dokumen arsitektur ini
└── lib/
    ├── main.dart                      # Entry point, init DB, routing Setup -> Login -> Home
    ├── theme/
    │   └── app_theme.dart             # Material 3 theme, color tokens, typography, spacing
    ├── models/
    │   ├── store_model.dart           # Konfigurasi toko & jenis usaha (retail/fnb/service)
    │   ├── user_model.dart            # User, role (owner/admin/cashier/kitchen), PIN hash
    │   ├── category_model.dart        # Kategori produk/menu/jasa
    │   ├── product_model.dart         # Produk, SKU, barcode, harga modal/jual, stok
    │   ├── stock_movement_model.dart  # Audit trail mutasi stok & opname
    │   ├── customer_model.dart        # Pelanggan, limit piutang, total kasbon
    │   ├── debt_payment_model.dart    # Pembayaran/cicilan kasbon pelanggan
    │   ├── supplier_model.dart        # Data pemasok
    │   ├── purchase_model.dart        # Transaksi kulakan/pembelian stok
    │   ├── shift_model.dart           # Shift kasir, modal awal, rekonsiliasi laci kas
    │   ├── cash_flow_model.dart       # Kas masuk / kas keluar manual di luar penjualan
    │   ├── transaction_model.dart     # Header transaksi, item, dan split payments
    │   ├── expense_model.dart         # Pengeluaran operasional toko
    │   ├── held_cart_model.dart       # Keranjang parkir / hold order
    │   └── printer_config_model.dart  # Konfigurasi printer struk, dapur, & label
    ├── data/
    │   └── db_helper.dart             # Singleton SQLite, DDL 17 tabel, migrasi, DAO CRUD, Backup/Restore JSON
    ├── services/
    │   ├── auth_service.dart          # Hash PIN (salt + SHA-256), session state, RBAC guard
    │   ├── escpos_service.dart        # Builder byte ESC/POS 58mm/80mm, tiket dapur, drawer kick
    │   ├── tspl_label_service.dart    # Builder raw TSPL & ZPL untuk label barcode sticker
    │   ├── printer_manager.dart       # Orkestrator Bluetooth, TCP Port 9100, & System PDF
    │   └── export_service.dart        # Generator PDF (Struk, Label, Laba Rugi), CSV, & Share/Import JSON
    ├── widgets/
    │   ├── pin_pad_widget.dart        # Keypad PIN numerik responsif & indikator titik
    │   ├── cart_panel_widget.dart     # Panel keranjang kasir, diskon, catatan item, parkir
    │   ├── payment_sheet.dart         # BottomSheet Split Payment, Tunai cepat, QRIS, Kasbon
    │   ├── barcode_scanner_sheet.dart # Modal kamera scanner + listener HID USB/BT scanner
    │   ├── receipt_preview_sheet.dart # Pratinjau struk & tombol cetak/bagikan PDF
    │   └── rbac_guard.dart            # Widget/helper proteksi aksi berbasis role
    └── screens/
        ├── setup_wizard_screen.dart   # First-Time Store Setup (Toko + Akun Owner pertama)
        ├── pin_login_screen.dart      # Login PIN Kasir/Owner & Switch User cepat
        ├── main_shell_screen.dart     # Navigasi utama (BottomNav / NavigationRail adaptif tablet)
        ├── pos_cashier_screen.dart    # Layar Kasir Universal (Retail/F&B/Jasa + Hold Cart)
        ├── shift_screen.dart          # Buka/Tutup Shift, Laci Kas, Kas Masuk/Keluar
        ├── products_screen.dart       # Katalog Produk, Stok Opname, Mutasi Stok
        ├── label_print_screen.dart    # Cetak Label Barcode Sticker (TSPL/ZPL/PDF 30x20..50x30)
        ├── customers_screen.dart      # Manajemen Pelanggan & Kasbon/Piutang + Cicilan
        ├── suppliers_screen.dart      # Supplier & Kulakan (Pembelian Stok)
        ├── expenses_screen.dart       # Pencatatan Pengeluaran Operasional
        ├── reports_screen.dart        # Laporan Penjualan, Laba Rugi, Export CSV & PDF
        └── settings_screen.dart       # Profil Toko, Kelola Staf/PIN, Printer Manager, Backup/Restore
```

---

## 3. Skema Lengkap Database SQLite (`sqflite`)

Konfigurasi wajib saat inisialisasi `db_helper.dart`:
- `onConfigure`: eksekusi `PRAGMA foreign_keys = ON;` dan `PRAGMA journal_mode = WAL;`.
- Seluruh nominal uang disimpan sebagai `INTEGER` (satuan Rupiah bulat) atau `REAL` bila mendukung desimal; rekomendasi utama untuk IDR adalah `INTEGER` agar bebas *floating-point rounding error*.
- Seluruh timestamp disimpan dalam format ISO-8601 UTC (`TEXT`, contoh: `2026-11-14T08:30:00.000Z`).

### 3.1 DDL 17 Tabel Produksi

```sql
-- 1. STORES: Identitas toko & mode operasional (tanpa dummy)
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
  setup_completed INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 2. USERS: Akun Owner, Admin, Kasir, dan Dapur dengan PIN ter-hash
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

-- 3. CATEGORIES: Kategori produk / menu F&B / layanan jasa
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon_name TEXT NOT NULL DEFAULT 'category',
  color_hex TEXT NOT NULL DEFAULT '#1E88E5',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);

-- 4. PRODUCTS: Barang retail, menu F&B, atau paket jasa
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
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_category ON products(category_id);

-- 5. STOCK_MOVEMENTS: Audit trail stok masuk, keluar, opname, penjualan, kulakan
CREATE TABLE stock_movements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL,
  movement_type TEXT NOT NULL CHECK (movement_type IN ('in', 'out', 'opname', 'sale', 'purchase', 'void')),
  qty_delta REAL NOT NULL,
  stock_before REAL NOT NULL,
  stock_after REAL NOT NULL,
  reference_type TEXT, -- 'transaction' | 'purchase' | 'opname' | 'manual'
  reference_id INTEGER,
  notes TEXT DEFAULT '',
  user_id INTEGER,
  created_at TEXT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX idx_stock_movements_product ON stock_movements(product_id, created_at);

-- 6. CUSTOMERS: Pelanggan & kontrol limit kasbon/piutang
CREATE TABLE customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT DEFAULT '',
  address TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  credit_limit INTEGER NOT NULL DEFAULT 0, -- 0 = tanpa limit / sesuai kebijakan owner
  total_debt INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 7. SHIFTS: Buka/tutup shift kasir & rekonsiliasi laci kas
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
CREATE INDEX idx_shifts_status ON shifts(status, opened_at);

-- 8. CASH_FLOWS: Kas masuk/keluar manual pada laci kas selama shift aktif
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

-- 9. TRANSACTIONS: Header penjualan (Retail, F&B Dine-In/Takeaway, Jasa)
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
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'partial_debt', 'void')),
  notes TEXT DEFAULT '',
  created_at TEXT NOT NULL,
  FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE SET NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
);
CREATE INDEX idx_transactions_date ON transactions(created_at);
CREATE INDEX idx_transactions_shift ON transactions(shift_id);

-- 10. TRANSACTION_ITEMS: Detail item transaksi + snapshot HPP & catatan dapur
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
CREATE INDEX idx_tx_items_tx ON transaction_items(transaction_id);

-- 11. TRANSACTION_PAYMENTS: Mendukung Split Payment (multi-metode dalam 1 struk)
CREATE TABLE transaction_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL,
  method TEXT NOT NULL CHECK (method IN ('cash', 'qris', 'transfer', 'debit', 'kasbon')),
  amount INTEGER NOT NULL,
  reference_no TEXT DEFAULT '',
  created_at TEXT NOT NULL,
  FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
);
CREATE INDEX idx_tx_payments_tx ON transaction_payments(transaction_id);

-- 12. DEBT_PAYMENTS: Pembayaran/pelunasan kasbon pelanggan
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

-- 13. SUPPLIERS: Data pemasok untuk kulakan
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

-- 14. PURCHASES: Transaksi kulakan / pembelian barang dari supplier
CREATE TABLE purchases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_no TEXT NOT NULL,
  supplier_id INTEGER,
  user_id INTEGER,
  items_json TEXT NOT NULL, -- Array JSON: [{product_id, name, qty, buy_price, subtotal}]
  total_amount INTEGER NOT NULL DEFAULT 0,
  payment_status TEXT NOT NULL DEFAULT 'paid' CHECK (payment_status IN ('paid', 'debt')),
  notes TEXT DEFAULT '',
  purchased_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- 15. EXPENSES: Pengeluaran operasional toko (listrik, gaji, kemasan, dll)
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

-- 16. HELD_CARTS: Parkir keranjang sementara (Hold Order / Open Table)
CREATE TABLE held_carts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cart_label TEXT NOT NULL,
  order_type TEXT NOT NULL DEFAULT 'retail' CHECK (order_type IN ('retail', 'dine_in', 'takeaway', 'service')),
  table_number TEXT DEFAULT '',
  customer_id INTEGER,
  items_json TEXT NOT NULL, -- Snapshot item keranjang beserta catatan & diskon
  discount_amount INTEGER NOT NULL DEFAULT 0,
  notes TEXT DEFAULT '',
  user_id INTEGER,
  created_at TEXT NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- 17. PRINTER_CONFIGS: Konfigurasi multi-printer (Struk, Dapur, Label Barcode)
CREATE TABLE printer_configs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  role_type TEXT NOT NULL CHECK (role_type IN ('receipt', 'kitchen', 'label')),
  connection_type TEXT NOT NULL CHECK (connection_type IN ('bluetooth', 'wifi_tcp', 'system_pdf')),
  address_or_ip TEXT DEFAULT '', -- MAC/UUID Bluetooth atau IP Address (mis. 192.168.1.200)
  port INTEGER NOT NULL DEFAULT 9100,
  paper_width_mm INTEGER NOT NULL DEFAULT 58, -- 58 atau 80 untuk struk
  label_size TEXT NOT NULL DEFAULT '40x30',  -- '30x20' | '40x30' | '50x30'
  command_lang TEXT NOT NULL DEFAULT 'escpos' CHECK (command_lang IN ('escpos', 'tspl', 'zpl', 'pdf')),
  is_default INTEGER NOT NULL DEFAULT 0,
  auto_print INTEGER NOT NULL DEFAULT 0,
  open_drawer INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
```

---

## 4. Spesifikasi `pubspec.yaml` & Konfigurasi Headless GitHub Actions

### 4.1 `pubspec.yaml` (Stabil, Bebas Konflik Dart/Gradle/Xcode)

Pemilihan package di bawah menghindari library lama yang sering gagal di Gradle 8 / AGP 8 / Xcode 16 (`flutter_blue`, `esc_pos_bluetooth`, `image ^3.x` conflicts). Generator **ESC/POS** dan **TSPL/ZPL** ditulis secara native di Dart (`Uint8List`) sehingga 0 dependensi eksternal bermasalah.

```yaml
name: pos_universal
description: Aplikasi POS Universal Production-Ready (Retail, F&B, Jasa)
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

  # Database & File System
  sqflite: ^2.3.3+1
  path: ^1.9.0
  path_provider: ^2.1.4

  # Security (Salted SHA-256 PIN Hashing)
  crypto: ^3.0.5

  # Thermal Printer Bluetooth & Permissions
  print_bluetooth_thermal: ^1.1.1
  permission_handler: ^11.3.1

  # PDF, AirPrint/System Print & Barcode Rendering
  pdf: ^3.11.1
  printing: ^5.13.4
  barcode: ^2.2.8

  # Camera Barcode Scanner (opsional fallback ke HID USB/BT Keyboard Scanner)
  mobile_scanner: ^5.2.3

  # Formatting, Export CSV/PDF & Backup/Restore JSON
  intl: ^0.19.0
  share_plus: ^10.1.2
  file_picker: ^8.1.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  flutter_launcher_icons: ^0.14.1
```

### 4.2 Kompatibilitas Build Headless CI (iOS + Android)

1. **Android (`ubuntu-latest`, Java 17)**:
   - Pastikan `minSdkVersion` disetel ke `21` (diperlukan oleh `mobile_scanner` & `printing`) pada `android/app/build.gradle` atau `build.gradle.kts` saat step CI.
   - Inject permissions ke `android/app/src/main/AndroidManifest.xml`:
     - `android.permission.INTERNET` (TCP Printer Port 9100)
     - `android.permission.BLUETOOTH`, `android.permission.BLUETOOTH_ADMIN` (Android <= 11)
     - `android.permission.BLUETOOTH_SCAN`, `android.permission.BLUETOOTH_CONNECT` (Android 12+)
     - `android.permission.CAMERA` (Scanner Barcode)
2. **iOS (`macos-latest`, Xcode 15/16, Unsigned IPA `--no-codesign`)**:
   - Set `IPHONEOS_DEPLOYMENT_TARGET` minimal `13.0` pada `ios/Podfile` (`platform :ios, '13.0'`).
   - Inject deskripsi privasi wajib ke `ios/Runner/Info.plist` agar tidak crash saat membuka Bluetooth/Kamera/WiFi Printer:
     - `NSBluetoothAlwaysUsageDescription`
     - `NSBluetoothPeripheralUsageDescription`
     - `NSCameraUsageDescription`
     - `NSLocalNetworkUsageDescription` (untuk akses printer WiFi TCP `9100`)
   - Kompilasi menggunakan `flutter build ios --config-only --no-codesign` dilanjutkan `xcodebuild ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY="" DEVELOPMENT_TEAM=""`, lalu kemas `Payload/Runner.app` menjadi `POSUniversal.ipa`.

---

## 5. Spesifikasi Alur Produksi End-to-End

### 5.1 First-Time Store Setup Wizard (Tanpa Data Dummy)
1. Saat `main.dart` berjalan, `DbHelper.isStoreInitialized()` memeriksa tabel `stores` (`setup_completed = 1`) dan keberadaan minimal 1 user `owner`.
2. Jika kosong (instalasi baru): tampilkan **`SetupWizardScreen`** (3 langkah):
   - **Langkah 1 — Profil Toko**: Nama Toko, Jenis Usaha (`Retail/Minimarket`, `F&B/Resto`, atau `Jasa`), Alamat, No. Telepon.
   - **Langkah 2 — Pajak & Biaya Layanan**: PPN (%) opsional, Service Charge (%) opsional (khusus F&B/Jasa), teks footer struk.
   - **Langkah 3 — Akun Owner**: Nama Owner + PIN 6 digit (di-hash dengan `salt` acak + `SHA-256`).
3. Setelah simpan dalam **1 SQLite Transaction**: insert `stores` + insert `users (role: 'owner')` + insert 1 kategori default sesuai jenis usaha (atau biarkan kosong/opsional), lalu arahkan langsung ke **`PinLoginScreen`**.

### 5.2 PIN Login & Multi-Role RBAC
- **`PinLoginScreen`**: menampilkan daftar user aktif (atau input PIN langsung yang mencocokkan user aktif), mendukung *Switch User* cepat di layar kasir tanpa menutup shift yang sedang berjalan jika diizinkan.
- **Matriks RBAC (`rbac_guard.dart`)**:

| Fitur / Modul | `owner` | `admin` | `cashier` | `kitchen` |
| :--- | :---: | :---: | :---: | :---: |
| Kasir POS, Hold Cart, Split Payment | ✅ | ✅ | ✅ | ❌ |
| Buka & Tutup Shift Sendiri | ✅ | ✅ | ✅ | ❌ |
| Lihat Semua Shift & Void Transaksi | ✅ | ✅ | ❌ | ❌ |
| Produk, Stok Opname, Cetak Label | ✅ | ✅ | Lihat saja | ❌ |
| Pelanggan & Bayar Kasbon | ✅ | ✅ | ✅ | ❌ |
| Supplier, Kulakan & Pengeluaran | ✅ | ✅ | ❌ | ❌ |
| Laporan Laba Rugi & Export CSV/PDF | ✅ | ✅ | ❌ | ❌ |
| Kelola Staf/PIN, Toko & Backup/Restore | ✅ | ❌ | ❌ | ❌ |
| Antrian Tiket Dapur (F&B) | ✅ | ✅ | ✅ | ✅ |

### 5.3 Siklus Shift & Laci Kas
1. Sebelum transaksi pertama di Kasir, sistem memeriksa `DbHelper.getOpenShift(userId)`. Jika belum ada shift terbuka, muncul prompt **Buka Shift** (input Modal Awal Laci Kas `opening_cash`).
2. Selama shift aktif:
   - Penjualan tunai menambah `expected_cash`.
   - Pembayaran kasbon tunai menambah `expected_cash`.
   - Kas Masuk (`cash_flows.type = 'cash_in'`) menambah `expected_cash`; Kas Keluar (`cash_out`) atau Pengeluaran dari laci (`expenses.payment_source = 'drawer'`) mengurangi `expected_cash`.
3. **Tutup Shift**: kasir menghitung uang fisik aktual (`actual_cash`), sistem menghitung selisih (`cash_difference = actual_cash - expected_cash`), menyimpan status `closed`, dan mencetak **Ringkasan Tutup Shift** via printer struk.

### 5.4 Alur Kasir Universal & Split Payment
- **Retail/Minimarket**: Scan barcode via kamera (`mobile_scanner`) atau USB/Bluetooth HID keyboard scanner -> tambah qty otomatis -> cek stok real-time.
- **F&B**: Pilih tipe order (`Dine-In` + Nomor Meja, atau `Takeaway`), tambah catatan per item (mis. *"tidak pedas, es sedikit"*), simpan ke `held_carts` (Open Bill) atau langsung bayar, serta opsional cetak **Tiket Dapur** ke printer `role_type = 'kitchen'`.
- **Jasa**: Item `item_type = 'service'` (`track_stock = 0`) dengan catatan detail layanan/pelanggan.
- **Split Payment (`payment_sheet.dart`)**: Pelanggan dapat membayar dengan kombinasi metode dalam 1 transaksi (mis. Rp 50.000 `cash` + Rp 35.000 `qris` + Rp 15.000 `kasbon` jika pelanggan dipilih). Setiap metode dicatat sebagai baris terpisah di `transaction_payments`, sedangkan `kasbon` otomatis menambah `customers.total_debt`.

### 5.5 Arsitektur Printer (`PrinterManager`, `EscPosService`, `TsplLabelService`)
1. **`PrinterManager.printReceipt(transaction, store, config)`**:
   - Jika `connection_type == 'bluetooth'`: kirim byte `EscPosService.buildReceipt(...)` via `PrintBluetoothThermal.writeBytes(bytes)`.
   - Jika `connection_type == 'wifi_tcp'`: buka `Socket.connect(config.addressOrIp, config.port)` (default `9100`), kirim bytes, lalu `socket.flush()` dan `socket.close()`.
   - Jika `connection_type == 'system_pdf'`: generate PDF 58mm/80mm via `ExportService.buildReceiptPdf(...)` dan buka dialog `Printing.layoutPdf(...)`.
   - Jika `config.openDrawer == 1` dan ada pembayaran `cash`, sisipkan perintah ESC/POS cash drawer kick (`[0x1B, 0x70, 0x00, 0x19, 0xFA]`).
2. **`TsplLabelService` (Label Barcode Sticker)**:
   - Mendukung ukuran **30x20 mm**, **40x30 mm**, dan **50x30 mm**.
   - **TSPL Mode** (Xprinter XP-365B, TSC, Gprinter): generate perintah `SIZE 40 mm,30 mm`, `GAP 2 mm,0 mm`, `CLS`, `TEXT`, `BARCODE ... "128"`, `TEXT` harga, `PRINT 1,1`.
   - **ZPL Mode** (Zebra): generate `^XA ... ^FO ... ^BC ... ^FD ... ^FS ^XZ`.
   - **PDF Label Mode**: generate halaman PDF presisi ukuran mm menggunakan `pdf` + `barcode` (`Barcode.code128()`) untuk printer A4/thermal OS driver.

### 5.6 Laporan Laba Rugi, Export, & Backup/Restore JSON
- **Laporan Laba Rugi**:
  - `Omzet Bersih` = Total Penjualan (`status != 'void'`) - Diskon.
  - `HPP (COGS)` = `SUM(transaction_items.qty * transaction_items.cost_price)`.
  - `Laba Kotor` = `Omzet Bersih - HPP`.
  - `Total Pengeluaran` = `SUM(expenses.amount)`.
  - `Laba Bersih` = `Laba Kotor - Total Pengeluaran`.
- **Export CSV & PDF**: menggunakan `export_service.dart` + `share_plus` untuk membagikan laporan penjualan, mutasi stok, atau laba rugi.
- **Backup & Restore JSON**: `DbHelper.exportDatabaseToJson()` mengekspor seluruh 17 tabel ke satu file JSON terstruktur (beserta `schema_version` dan timestamp); `DbHelper.restoreDatabaseFromJson()` memvalidasi struktur lalu melakukan `DELETE` + `INSERT` seluruh tabel di dalam satu **SQLite Transaction** agar atomik (gagal = rollback penuh, data lama aman).
