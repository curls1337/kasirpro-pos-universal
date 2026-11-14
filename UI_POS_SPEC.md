# Spesifikasi Desain UI/UX Aplikasi POS Universal (Flutter Production)

Dokumen ini adalah spesifikasi desain produksi komersial untuk **Aplikasi POS Universal** berbasis **Flutter (Material Design 3 + Adaptive Cupertino/Desktop Ergonomics)** yang mendukung perangkat **HP (`< 720dp`)** dan **Tablet POS (`>= 720dp`)** secara responsif, lengkap dengan dukungan dual-theme (**Modern Clean Light** & **OLED Dark**).

---

## 1. Design Brief (8 Unsur)

| Unsur | Spesifikasi |
| :--- | :--- |
| **Konteks** | Aplikasi Point of Sale (POS) universal lintas sektor (ritel, minimarket, F&B/kafe, toko kelontong modern, jasa) untuk operasional kasir harian offline-first maupun sinkronisasi cloud, berjalan di HP dan Tablet Android/iOS. |
| **Target Pengguna** | Kasir (kecepatan input, anti-salah pencet, alur bayar < 3 ketukan), Supervisor/Kepala Toko (kontrol shift, stok, opname), dan Pemilik Usaha/Owner (pantau laba rugi, kasbon, margin). |
| **Vibe & Karakter** | **Crisp, Tactile, High-Trust Commercial Fintech.** Bersih, presisi, responsif instan, dengan hierarki angka yang tegas agar nyaman dipakai 8–12 jam di meja kasir. |
| **Referensi Arah Visual** | Square POS (kejelasan split-pane & tender modal), Toast/Lightspeed (ergonomi tombol cepat), Apple HIG / Linear (kerapihan tipografi tabular & permukaan bertingkat). *Hanya sebagai inspirasi struktur, tanpa menyalin aset/merek.* |
| **Warna** | Dual-Theme adaptif: **Modern Clean Light** (default operasional siang/ruang terang) + **OLED Dark** (toggle untuk kafe/bar/malam/hemat daya OLED) dengan aksen utama **Cobalt Blue (`#2563EB`)** dan semantik transaksi **Emerald (`#10B981`)**, **Amber (`#F59E0B`)**, **Rose (`#EF4444`)**. |
| **Font** | **Plus Jakarta Sans** (UI & Display, geometris ramah namun profesional) + **JetBrains Mono / Tabular Figures** (`FontFeature.tabularFigures()`) untuk seluruh harga, subtotal, kembalian, SKU, dan pratinjau struk. |
| **Struktur** | **Adaptive Breakpoint `720dp`**: `< 720dp` menggunakan Bottom Navigation Bar (4 tab utama + menu lanjutan) & Sticky Cart Bar; `>= 720dp` menggunakan `NavigationRail` kiri + Split-Pane Master-Detail (Kasir 62% Katalog : 38% Keranjang). |
| **Hindari** | **Tanpa tombol Demo / Quick Demo Role** di layar produksi; hindari animasi lambat (`> 250ms`) yang menghambat kasir; hindari teks harga tanpa *tabular numerals*; hindari ikon/tombol sentuh di bawah `48dp`; hindari tabel padat tanpa jarak bernapas di mobile. |

---

## 2. Sistem Warna & Design Tokens (Dual-Theme)

Aplikasi menyediakan toggle instan **Modern Clean Light ↔ OLED Dark** di Pengaturan & Quick Header Action (tersimpan di `SharedPreferences` / local DB).

### A. Palet Warna Semantik

| Token Flutter (`AppColors`) | Modern Clean Light (Default) | OLED Dark (Toggle) | Penggunaan |
| :--- | :--- | :--- | :--- |
| `bgCanvas` | `#F8FAFC` (Cool Alabaster) | `#000000` (True OLED Black) | Latar belakang utama scaffold |
| `surfacePrimary` | `#FFFFFF` (Pure White) | `#0D1117` (Obsidian) | Kartu katalog, panel keranjang, modal |
| `surfaceElevated` | `#F1F5F9` (Slate 100) | `#161B22` (Elevated Charcoal) | Input field, chip inactive, header tabel |
| `surfaceHighlight` | `#EFF6FF` (Blue 50) | `#172554` (Deep Cobalt Tint) | Item keranjang aktif, tab terpilih |
| `borderSubtle` | `#E2E8F0` (Slate 200) | `#1F2937` (Gray 800, 1px) | Garis pemisah panel, outline kartu |
| `textPrimary` | `#0F172A` (Slate 900) | `#F8FAFC` (Slate 50) | Judul, nama produk, nominal utama |
| `textSecondary` | `#475569` (Slate 600) | `#94A3B8` (Slate 400) | SKU, sublabel, jam transaksi |
| `textMuted` | `#94A3B8` (Slate 400) | `#64748B` (Slate 500) | Placeholder, label tidak aktif |
| `brandPrimary` | `#2563EB` (Cobalt 600) | `#3B82F6` (Cobalt 500) | Tombol Bayar, CTA utama, active rail |
| `brandOnPrimary` | `#FFFFFF` | `#FFFFFF` | Teks/ikon di atas `brandPrimary` |
| `statusSuccess` | `#059669` (Emerald 600) | `#10B981` (Emerald 500) | Transaksi Lunas, Laba positif, Printer Online |
| `statusWarning` | `#D97706` (Amber 600) | `#F59E0B` (Amber 500) | Stok menipis, Kasbon jatuh tempo, Hold Order |
| `statusDanger` | `#DC2626` (Red 600) | `#EF4444` (Red 500) | Stok habis, Void/Retur, Selisih kas minus |
| `statusInfo` | `#0284C7` (Sky 600) | `#38BDF8` (Sky 400) | QRIS / Transfer / Info sinkronisasi |

> **Standar Kontras**: Seluruh kombinasi teks utama & nominal harga wajib memenuhi rasio kontras minimum **WCAG AA (>= 4.5:1)** dan **>= 7:1** untuk tombol CTA transaksi utama (`Bayar`, `Cetak`).

---

## 3. Tipografi, Skala & Ergonomi POS

### A. Skala Tipografi (`TextTheme`)
Semua gaya angka transaksi wajib mengaktifkan `fontFeatures: [FontFeature.tabularFigures()]` agar kolom digit harga rata kanan dengan presisi.

| Role | Font Family | Ukuran (HP / Tablet) | Weight | Line Height | Kegunaan |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `displayTotal` | Plus Jakarta Sans | `28sp` / `34sp` | `700 (Bold)` | `1.15` | Total Tagihan Tender Modal, KPI Laba Bersih |
| `headlineSection` | Plus Jakarta Sans | `20sp` / `22sp` | `700 (Bold)` | `1.25` | Judul Halaman, Header Modal Sheet |
| `titleCard` | Plus Jakarta Sans | `15sp` / `16sp` | `600 (SemiBold)` | `1.3` | Nama Produk di Katalog & Keranjang |
| `bodyPrimary` | Plus Jakarta Sans | `14sp` / `14sp` | `500 (Medium)` | `1.4` | Deskripsi, nama pelanggan, label form |
| `captionMeta` | Plus Jakarta Sans | `12sp` / `12sp` | `500 (Medium)` | `1.35` | SKU, jam transaksi, badge status stok |
| `monoPrice` | JetBrains Mono / Tabular | `14sp`–`24sp` | `600`–`700` | `1.2` | Harga satuan, subtotal, kembalian, pratinjau struk |

### B. Ergonomi & Ukuran Sentuh
- **Minimum Touch Target**: `48x48dp` untuk seluruh tombol aksi, chip filter, dan stepper kuantitas (`-` / `+`).
- **Tombol Utama Kasir (Bayar / Numpad)**: Tinggi minimum `56dp` (HP) dan `60dp` (Tablet).
- **Corner Radius**:
  - Kartu Katalog & Panel Split-Pane: `16dp`
  - Modal Bottom Sheet / Dialog: `24dp` (top radius di HP, all-around di Tablet)
  - Tombol CTA & Input Field: `12dp`
  - Status Chip / Filter Pill: `999dp` (capsule)

---

## 4. Arsitektur Navigasi Responsif (HP `< 720dp` vs Tablet `>= 720dp`)

Menggunakan `LayoutBuilder` pada root shell (`PosAdaptiveShell`) dengan ambang batas **`MediaQuery.sizeOf(context).width >= 720`**:

### A. Layout HP (`< 720dp` — Compact Portrait)
- **Navigasi Utama**: **Bottom Navigation Bar** (`NavigationBar` M3, tinggi `68dp` + `SafeArea` bottom) dengan 4 destinasi utama agar tidak sesak:
  1. **Kasir** (Ikon `point_of_sale`)
  2. **Stok** (Ikon `inventory_2`)
  3. **Laporan** (Ikon `analytics`)
  4. **Lainnya** (Ikon `grid_view` — membuka Hub Menu: *Shift Kasir, Pelanggan & Kasbon, Pengaturan Printer, Profil Toko, Toggle Tema*).
- **Pola Kasir HP**: Katalog memenuhi layar; saat ada item di keranjang, muncul **Sticky Floating Cart Bar** tepat di atas Bottom Bar (`[3 Item • Rp 145.000] [Bayar →]`). Mengetuk bar ini membuka **Cart Bottom Sheet** (90% tinggi layar).

### B. Layout Tablet POS (`>= 720dp` — Landscape / Wide)
- **Navigasi Utama**: **Left `NavigationRail`** (`76dp` collapsed, dapat diperluas ke `220dp` dengan tombol menu) menampilkan seluruh modul produksi tanpa tersembunyi:
  1. **Kasir** (Split-View)
  2. **Stok & Barcode**
  3. **Shift Kasir**
  4. **Pelanggan & Kasbon**
  5. **Laporan Laba Rugi**
  6. **Printer & Pengaturan**
  - *Footer Rail*: Indikator Status Printer (dot hijau/merah), Toggle **Light/OLED Dark**, dan Tombol **Kunci Layar (PIN)**.
- **Pola Kasir Tablet**: **Split-Pane Tetap** (`Row` 62% Katalog Kiri : 1px Divider : 38% Keranjang Kanan, minimum lebar panel keranjang `340dp`).

---

## 5. Alur Layar Produksi Lengkap (End-to-End Commercial Flows)

### Layar 1: First-Time Store Setup (Onboarding Produksi)
Muncul **hanya sekali** saat database lokal belum memiliki profil toko (`is_initialized == false`). **Tanpa tombol demo / skip dummy.**

- **Layout**: Centered Card (`maxWidth: 540dp` di Tablet) atau Full Stepper di HP, dengan progress bar 3 langkah di atas.
- **Langkah 1 — Identitas Toko**:
  - Upload/Pilih Logo Toko (opsional, untuk header struk thermal monochrome).
  - Nama Toko (*wajib*), Kategori Bisnis (*Ritel/Minimarket, F&B/Kafe, Apotek/Kesehatan, Jasa/Lainnya*), Alamat & Nomor Telepon/WA (tampil di struk).
- **Langkah 2 — Preferensi Kasir & Pajak**:
  - Mata Uang (default `IDR - Rp`), Format Desimal, Pajak/PPN Opsional (`0%` default atau aktifkan e.g. `11%` inklusif/eksklusif), Biaya Layanan Opsional.
- **Langkah 3 — Akun Pemilik & PIN Keamanan**:
  - Nama Pemilik (*Owner*), PIN Keamanan 6-digit + Konfirmasi PIN (langsung mengenkripsi akses owner), Opsi Hubungkan Printer Sekarang atau Nanti di Pengaturan.
- **Aksi Akhir**: Tombol `Mulai Operasional Toko` → menyimpan konfigurasi ke SQLite/Hive → langsung masuk ke **PIN Lock Screen** atau **Buka Shift Pertama**.

---

### Layar 2: PIN Lock Screen (Tanpa Tombol Demo)
Layar keamanan utama setiap kali aplikasi dibuka, berganti kasir, atau setelah timeout idle. **Dilarang keras menampilkan tombol Demo, Quick Login, atau hint PIN.**

- **Struktur Visual**:
  - *Tablet*: Split-pane ringan — Kiri menampilkan Branding Toko (Logo, Nama Toko, Jam & Tanggal real-time, Status Shift Aktif); Kanan menampilkan Panel PIN.
  - *HP*: Vertical centered layout yang ergonomis untuk satu tangan.
- **Komponen Wajib**:
  1. **User/Kasir Selector Pill**: Menampilkan avatar inisial + nama kasir terpilih + badge peran (*Owner / Supervisor / Kasir*). Tap untuk memilih daftar akun staf yang terdaftar di toko.
  2. **6-Dot PIN Indicator**: 6 lingkaran indikator; animasi *shake* horizontal (180ms) saat PIN salah.
  3. **Ergonomic Numpad (3x4 Grid)**: Tombol besar `68x68dp` (HP) / `76x76dp` (Tablet) dengan angka jelas (`24sp`), tombol `Biometrik` (FaceID/Fingerprint di kiri bawah bila aktif), dan `Backspace` di kanan bawah.
- **State Error, Keamanan & Loading**:
  - Salah 1–4x: Pesan inline merah lembut *"PIN tidak sesuai. Sisa percobaan: X"*.
  - Salah 5x: **Lockout Cooldown 30 detik** (numpad nonaktif dengan countdown timer).
  - *Loading*: Indikator spinner singkat saat verifikasi hash lokal & memuat sesi shift.

---

### Layar 3: Kasir Split-View (Katalog + Keranjang + Tender Modal + Thermal/Label Print)
Jantung operasional aplikasi. Dirancang untuk kecepatan input maksimal termasuk dukungan **Hardware Barcode Scanner (USB/Bluetooth HID)**.

#### A. Panel Kiri — Katalog Produk (62% Tablet / Full HP)
- **Top Search & Action Bar**:
  - Search Bar (`Cari nama, SKU, atau scan barcode...`) selalu siap menerima input keyboard wedge dari scanner fisik.
  - Tombol **Scan Kamera** (ikon QR/Barcode scanner), tombol **Tambah Item Manual / Harga Bebas** (untuk barang belum terdaftar/jasa).
- **Category Filter Chips**: Horizontal scrollable pills (*Semua, Favorit, Makanan, Minuman, Sembako, dll.*).
- **Product Grid / List Toggle**:
  - Grid responsif (`2 kolom` di HP, `3–4 kolom` di Tablet).
  - Setiap **Product Card** menampilkan: Thumbnail warna/foto produk (atau inisial SKU bersih), Nama Produk (maks 2 baris), Harga (`monoPrice`), dan **Stock Badge** (Hijau: `Stok 24`, Kuning: `Sisa 3`, Merah & nonaktif/peringatan: `Habis`).
  - Tap kartu = langsung `+1` ke keranjang (atau buka **Variant/Modifier Sheet** jika produk memiliki varian ukuran/rasa/catatan).

#### B. Panel Kanan — Keranjang Aktif (38% Tablet / Bottom Sheet HP)
- **Header Keranjang**: Nomor Antrean/Order (`#INV-0042`), Tombol **Pilih Pelanggan** (opsional, wajib jika bayar Kasbon), Tombol **Hold / Simpan Pesanan** & **Daftar Hold**, Tombol **Kosongkan** (ikon trash dengan konfirmasi).
- **Daftar Item Keranjang**:
  - Nama item + varian + catatan kecil.
  - Stepper kuantitas (`-` `qty` `+`) dengan ukuran sentuh `40–44dp`; tap angka qty untuk input jumlah massal via numpad; swipe kiri untuk hapus item.
  - Harga satuan & subtotal item rata kanan (`tabularFigures`).
- **Ringkasan & Footer Aksi**:
  - Baris rincian: Subtotal, Diskon (tap untuk tambah diskon % atau nominal Rp), Pajak/Service (jika aktif).
  - **Grand Total** menonjol (`24–28sp Bold`).
  - Tombol CTA utama lebar penuh: **`BAYAR • Rp XX.XXX`** (warna `brandPrimary`, tinggi `56dp`).
- **Empty State Keranjang**: Ilustrasi minimalis keranjang + teks *"Scan barcode atau pilih produk di sebelah kiri"* + tombol cepat *"Buka Pesanan Tertunda (Hold)"* jika ada.

#### C. Tender Modal / Payment Sheet
Terbuka saat kasir menekan tombol **BAYAR**.
- **Header**: Total Tagihan besar di atas (`Rp 145.000`).
- **Tab Metode Pembayaran**:
  1. **Tunai (Cash)**:
     - Tombol Nominal Cepat (*Quick Cash Pills*): `Uang Pas`, `Rp 150.000`, `Rp 200.000`, `Rp 500.000` (dinamis dibulatkan ke atas dari total tagihan).
     - Numpad input uang diterima + kalkulasi **Kembalian** real-time (hijau jika cukup, merah *"Kurang Rp..."* jika belum cukup).
  2. **QRIS**: Tampilkan QRIS Statis/Dinamis toko di layar + tombol *"Konfirmasi Pembayaran Masuk"*.
  3. **Kartu / Transfer**: Pilihan EDC Debit/Kredit atau Transfer Bank + input 4 digit/nomor referensi opsional.
  4. **Kasbon (Piutang)**: Wajib memilih/menambah Pelanggan terlebih dahulu; tampilkan batas/riwayat kasbon pelanggan + tanggal jatuh tempo; tombol *"Catat Sebagai Kasbon"*.
  5. **Split Payment**: Bagi pembayaran ke 2 metode (mis. Rp 100.000 Tunai + sisanya QRIS).
- **Tombol Eksekusi**: `Selesaikan Pembayaran` (otomatis memicu laci kas jika Tunai & auto-print jika diaktifkan).

#### D. Post-Payment & Thermal / Label Print Sheet
Muncul seketika setelah pembayaran sukses:
- Badge Centang Hijau (`Pembayaran Berhasil`) + Total Bayar + **Kembalian Besar** (agar kasir tidak salah mengambil uang kembalian).
- **Aksi Cetak & Bagikan**:
  - `Cetak Struk Thermal (58mm/80mm)` (dengan status printer real-time).
  - `Cetak Label Pesanan / Stiker` (untuk F&B/cup label atau paket).
  - `Kirim Struk WhatsApp / Bagikan PDF`.
  - Tombol Utama: **`Transaksi Baru`** (atau tekan `Enter` / `Space` di keyboard tablet).

---

### Layar 4: Manajemen Stok & Label Barcode
Dirancang untuk admin gudang/pemilik agar kontrol inventaris dan cetak stiker harga/barcode cepat dilakukan dari HP maupun Tablet.

- **Header & KPI Mini**: Total SKU Aktif, Nilai Aset Stok (HPP), Filter Cepat: `Semua`, `Stok Menipis (Amber)`, `Stok Habis (Red)`.
- **Daftar / Tabel Produk**:
  - *HP*: Card list dengan badge stok, harga modal vs harga jual (margin %), dan menu aksi (`⋮`).
  - *Tablet*: Data table bersih dengan kolom Foto, Nama/SKU/Barcode, Kategori, HPP, Harga Jual, Stok Saat Ini, dan Tombol Aksi Cepat (`+ Stok`, `Cetak Label`, `Edit`).
- **Form Tambah / Edit Produk (Sheet / Dialog)**:
  - Nama Produk, Kategori, Satuan (`pcs`, `kg`, `box`, `porsi`), SKU, Barcode (tombol `Scan` atau `Generate Barcode EAN-13/Code128`).
  - Harga Modal (HPP) & Harga Jual (otomatis menghitung & menampilkan **Margin Laba %**).
  - Stok Awal & **Batas Minimum Stok** (pemicu peringatan stok menipis).
  - Toggle **Produk Varian** (mis. Ukuran S/M/L atau Harga Grosir bertingkat).
- **Modal Penyesuaian Stok (Stock Opname / Mutasi)**:
  - Pilih tipe: *Stok Masuk (Pembelian)*, *Stok Keluar/Rusak*, *Opname (Sesuaikan Fisik)*, input jumlah & alasan/catatan → tercatat di **Log Riwayat Stok**.
- **Alur Cetak Label Barcode**:
  - Pilih satu atau beberapa produk → tentukan jumlah copy per produk → pilih ukuran stiker (`33x15mm`, `40x30mm`, `50x30mm`) → **Live Preview Label** (Nama Produk, Barcode garis tajam, Harga Rp) → tombol `Cetak ke Printer Label`.

---

### Layar 5: Shift Kasir (Buka, Monitor & Tutup Shift)
Menjamin akuntabilitas uang laci kasir (*cash drawer reconciliation*).

- **Kondisi 1 — Belum Ada Shift Aktif (Buka Shift)**:
  - Kartu terpusat: Nama Kasir aktif, Waktu Mulai, Input **Modal Awal Laci Kas (`Opening Cash`)** via numpad cepat, Catatan Awal → Tombol `Buka Shift Sekarang`.
- **Kondisi 2 — Shift Sedang Berjalan**:
  - **Banner Status Shift**: `Shift Aktif • Mulai 08:00` + nama kasir.
  - **Ringkasan Kas Real-Time**: Modal Awal, Penjualan Tunai, Penjualan Non-Tunai (QRIS/Kartu/Transfer), Kasbon Baru, Pembayaran Kasbon Tunai.
  - **Kas Masuk / Keluar (Petty Cash)**: Tombol cepat `+ Kas Masuk` atau `- Kas Keluar` (mis. beli es batu/plastik, setor ke brankas) lengkap dengan nominal & keterangan.
  - **Tombol `Tutup Shift (Rekonsiliasi)`**.
- **Kondisi 3 — Tutup Shift (*Blind Close / Reconciliation*)**:
  - Kasir memasukkan **Total Uang Fisik di Laci (`Actual Cash`)** (tersedia kalkulator pecahan uang kertas/koin opsional).
  - Sistem menampilkan perbandingan **Ekspektasi Sistem vs Fisik** dan **Selisih (`Variance`)** (Hijau `Rp 0` jika klop, Merah/Kuning jika kurang/lebih).
  - Catatan Penutupan Shift → Tombol `Sahkan & Cetak Laporan Shift (Z-Report)` → otomatis mencetak ringkasan ke printer thermal dan mengembalikan layar ke **PIN Lock Screen**.

---

### Layar 6: Pelanggan & Kasbon (Buku Piutang)
Mengelola pelanggan setia sekaligus pencatatan kasbon yang rapi tanpa buku tulis.

- **Daftar Pelanggan (Master)**:
  - Search Nama / No. HP + Filter Chip: `Semua Pelanggan`, `Memiliki Kasbon Aktif`, `Jatuh Tempo`.
  - Setiap baris menampilkan: Avatar inisial, Nama, No. WhatsApp, Jumlah Transaksi, dan **Total Sisa Kasbon** (badge merah/amber jika `> Rp 0`, hijau `Lunas` jika `0`).
  - Tombol `+ Pelanggan Baru`.
- **Detail Pelanggan & Buku Kasbon (Detail Pane di Tablet / Page di HP)**:
  - Header Profil Pelanggan + tombol cepat **Hubungi WhatsApp (Tagih/Kirim Rekap)**.
  - Ringkasan: Total Belanja Seumur Hidup vs **Sisa Piutang Kasbon Saat Ini**.
  - **Daftar Faktur Kasbon Belum Lunas**: Tanggal, No. Struk, Total Tagihan, Sudah Dibayar, Sisa, Status Jatuh Tempo.
  - **Alur Bayar / Cicil Kasbon**:
    - Tombol **`Bayar Kasbon`** → membuka modal input nominal cicilan atau `Lunasi Semua` → pilih metode bayar (*Tunai [masuk laci shift aktif] / Transfer / QRIS*) → simpan → cetak **Bukti Pembayaran Kasbon** ke printer thermal atau kirim ke WhatsApp.

---

### Layar 7: Laporan Laba Rugi (Profit & Loss)
Panel eksekutif untuk Owner/Supervisor melihat kesehatan finansial toko secara akurat.

- **Filter Atas**:
  - Segmented Period Picker: `Hari Ini`, `7 Hari`, `30 Hari`, `Bulan Ini`, `Custom Tanggal`.
  - Filter Opsional: Per Kasir / Per Kategori.
- **Bento KPI Grid (2x2 di HP, 4 Kolom di Tablet)**:
  1. **Omzet Bersih** (Penjualan Kotor dikurangi Diskon & Retur).
  2. **Total HPP (Modal)** (dihitung otomatis dari harga modal produk terjual).
  3. **Laba Kotor** (`Omzet Bersih - HPP` + persentase *Gross Margin*).
  4. **Laba Bersih** (`Laba Kotor - Pengeluaran/Kas Keluar Operasional` + badge tren).
- **Visualisasi & Rincian**:
  - **Grafik Tren Omzet vs Laba** (Bar/Line chart bersih dengan tooltip saat disentuh/hover).
  - **Komposisi Pembayaran**: Progress bar proporsi Tunai, QRIS, Kartu/Transfer, dan Kasbon.
  - **Tabel Ringkasan Laba Rugi Terstruktur** (format akuntansi ringkas: Pendapatan, Potongan, HPP, Laba Kotor, Beban Operasional, Laba Bersih).
  - **Top 5 Produk Terlaris & Top Margin**.
- **Aksi Ekspor**: Tombol `Ekspor PDF`, `Ekspor CSV/Excel`, dan `Cetak Ringkasan Thermal`.

---

### Layar 8: Pengaturan Printer Thermal & Label
Pusat kendali perangkat keras pencetakan agar kasir tidak bingung saat koneksi terputus.

- **Dua Kartu Saluran Printer Terpisah**:
  1. **Printer Struk (Thermal Receipt — ESC/POS)**
     - Pilihan Lebar Kertas: `58mm` (32 karakter) atau `80mm` (48 karakter).
     - Tipe Koneksi: `Bluetooth`, `USB OTG`, `Wi-Fi / LAN (TCP/IP Port 9100)`.
     - Pemindaian Perangkat Terdekat + Status Badge (`Terhubung`, `Menyambung...`, `Terputus`).
     - Opsi Otomatis: *Auto-Print Struk Setelah Bayar*, *Auto-Cut Kertas (80mm)*, *Buka Laci Kas (Kick Cash Drawer) pada Bayar Tunai*.
     - Tombol **`Test Print Struk`**.
  2. **Printer Label & Barcode (Stiker — TSPL / CPCL / ESC)**
     - Pilihan Ukuran Label Default: `33x15mm`, `40x30mm`, `50x30mm`, `Custom (mm)`.
     - Tipe Koneksi: `Bluetooth`, `USB`, `LAN`.
     - Pengaturan Konten Label: Toggle tampilkan *Nama Toko*, *Nama Produk*, *Harga Rp*, *Kode SKU*.
     - Tombol **`Test Print Label`**.
- **Kustomisasi Tampilan Struk (Live Preview 58mm/80mm di sebelah kanan di Tablet)**:
  - Toggle tampilkan Logo Toko (konversi monochrome dithering).
  - Input Header Tambahan & Footer Struk (mis. *"Barang yang sudah dibeli tidak dapat ditukar"*).

---

## 6. Standar State Sistem, Aksesibilitas & Offline-First

1. **Empty State**: Setiap daftar kosong (produk, pelanggan, riwayat shift, hasil pencarian) wajib menampilkan ikon lembut, judul jelas, deskripsi singkat, dan 1 tombol CTA langsung (mis. `+ Tambah Produk Pertama`).
2. **Loading State**: Gunakan **Skeleton Shimmer** yang menyerupai bentuk kartu/tabel (bukan layar putih kosong dengan spinner di tengah), kecuali saat proses enkripsi/cetak printer aktif yang memakai modal progress non-blocking.
3. **Error & Offline Resilience**:
   - Karena POS wajib tetap jalan saat internet mati, seluruh transaksi disimpan lokal (SQLite/Drift) dengan badge sinkronisasi di header (`Online • Tersinkron` vs `Offline • 3 Antrean`).
   - Error koneksi printer tidak boleh menggagalkan transaksi pembayaran: tampilkan banner non-blocking *"Pembayaran tersimpan, printer tidak merespons — [Coba Cetak Ulang]"*.
4. **Keyboard & Hardware Scanner Support**:
   - Pada Tablet/Desktop POS, fokus input pencarian tidak mencuri fokus saat modal terbuka, namun mendukung shortcut standar kasir (`F2` Cari Produk, `F4` Bayar, `Esc` Tutup Modal, `Enter` Konfirmasi).
