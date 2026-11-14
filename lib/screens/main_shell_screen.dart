import 'package:flutter/material.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';
import 'crm_supplier_screen.dart';
import 'inventory_label_screen.dart';
import 'pos_cashier_screen.dart';
import 'reports_screen.dart';
import 'settings_printer_screen.dart';
import 'shift_cash_screen.dart';

/// Adaptive Shell: NavigationRail (>=720dp Tablet) & BottomNavigationBar (<720dp HP)
class MainShellScreen extends StatefulWidget {
  final PosController controller;

  const MainShellScreen({super.key, required this.controller});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  PosController get ctrl => widget.controller;

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final colors = context.posColors;

    final destinations = [
      (
        label: 'Kasir',
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale_rounded,
        page: PosCashierScreen(controller: ctrl),
      ),
      (
        label: 'Stok & Label',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        page: InventoryLabelScreen(controller: ctrl),
      ),
      (
        label: 'Shift Kas',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        page: ShiftCashScreen(controller: ctrl),
      ),
      (
        label: 'CRM & Kulakan',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups_rounded,
        page: CrmSupplierScreen(controller: ctrl),
      ),
      (
        label: 'Laporan',
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics_rounded,
        page: ReportsScreen(controller: ctrl),
      ),
      (
        label: 'Pengaturan',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        page: SettingsPrinterScreen(controller: ctrl),
      ),
    ];

    final currentPage = destinations[_selectedIndex].page;

    if (isTablet) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (idx) =>
                    setState(() => _selectedIndex = idx),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: colors.brandPrimary,
                        child: const Icon(Icons.storefront_rounded,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      _statusDot(colors),
                    ],
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Ganti Tema Light/Dark',
                            onPressed: ctrl.toggleTheme,
                            icon: Icon(
                              ctrl.themeMode == ThemeMode.dark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                            ),
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            tooltip: 'Kunci Terminal (PIN)',
                            onPressed: ctrl.lockTerminal,
                            icon: Icon(Icons.lock_rounded,
                                color: colors.statusDanger),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                destinations: destinations
                    .map(
                      (d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: currentPage),
            ],
          ),
        ),
      );
    }

    // Mobile Layout (< 720dp): 4 Destinasi BottomNav (Kasir, Stok, Laporan, Lainnya Hub)
    final mobileNavIdx = _selectedIndex == 0
        ? 0
        : _selectedIndex == 1
            ? 1
            : _selectedIndex == 4
                ? 2
                : 3;

    return Scaffold(
      body: SafeArea(child: currentPage),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileNavIdx,
        onDestinationSelected: (idx) {
          if (idx == 0) {
            setState(() => _selectedIndex = 0);
          } else if (idx == 1) {
            setState(() => _selectedIndex = 1);
          } else if (idx == 2) {
            setState(() => _selectedIndex = 4);
          } else {
            _openMoreHub(colors);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'Kasir',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Stok',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Lainnya',
          ),
        ],
      ),
    );
  }

  Widget _statusDot(PosColors colors) {
    final shiftOpen = ctrl.activeShift != null;
    final hasPrinter = ctrl.defaultReceiptPrinter != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: shiftOpen ? 'Shift Aktif' : 'Shift Belum Buka',
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shiftOpen ? colors.statusSuccess : colors.statusWarning,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: hasPrinter ? 'Printer Terkonfigurasi' : 'Printer Belum Diset',
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasPrinter ? colors.statusInfo : colors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  void _openMoreHub(PosColors colors) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.surfaceHighlight,
                    child: Text(
                      (ctrl.activeUser?.name ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                          color: colors.brandPrimary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ctrl.activeUser?.name ?? '-',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                          '${ctrl.activeUser?.role.toUpperCase() ?? '-'} • ${ctrl.activeShift != null ? "Shift Aktif" : "Shift Tutup"}',
                          style: TextStyle(
                              fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ctrl.toggleTheme();
                    },
                    icon: Icon(ctrl.themeMode == ThemeMode.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded),
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded),
                title: const Text('Shift & Laci Kas'),
                subtitle: Text(ctrl.activeShift != null
                    ? 'Shift sedang berjalan'
                    : 'Buka shift sebelum transaksi'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _selectedIndex = 2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.groups_rounded),
                title: const Text('Pelanggan, Kasbon, Supplier & Biaya'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _selectedIndex = 3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Printer Thermal, Staff & Pengaturan'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _selectedIndex = 5);
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ctrl.lockTerminal();
                },
                icon: Icon(Icons.lock_rounded, color: colors.statusDanger),
                label: Text('Kunci Terminal (PIN)',
                    style: TextStyle(color: colors.statusDanger)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
