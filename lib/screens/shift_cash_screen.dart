import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';

/// Layar Shift & Laci Kas: Buka Shift, Kas Masuk/Keluar, Blind Close Shift + Z-Report Thermal
class ShiftCashScreen extends StatefulWidget {
  final PosController controller;

  const ShiftCashScreen({super.key, required this.controller});

  @override
  State<ShiftCashScreen> createState() => _ShiftCashScreenState();
}

class _ShiftCashScreenState extends State<ShiftCashScreen> {
  final _openingCashCtrl = TextEditingController(text: '0');
  final _openingNotesCtrl = TextEditingController();

  PosController get ctrl => widget.controller;

  @override
  void dispose() {
    _openingCashCtrl.dispose();
    _openingNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCashFlowDialog(String type) async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final isCashIn = type == 'cash_in';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCashIn ? 'Catat Kas Masuk' : 'Catat Kas Keluar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Nominal (${ctrl.currencySymbol})',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Keterangan (mis. Beli es batu / Setor brankas)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final amt = int.tryParse(amountCtrl.text) ?? 0;
              if (amt <= 0) return;
              await ctrl.addCashFlow(
                type: type,
                amount: amt,
                category: isCashIn ? 'manual_in' : 'manual_out',
                notes: notesCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCloseShiftDialog() async {
    final shift = ctrl.activeShift;
    if (shift == null) return;
    final actualCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final sym = ctrl.currencySymbol;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final actual = int.tryParse(actualCtrl.text) ?? 0;
          final diff = actual - shift.expectedCash;
          return AlertDialog(
            title: const Text('Tutup Shift (Blind Close)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Hitung uang fisik aktual di laci kas sebelum melihat selisih.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: actualCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Uang Fisik Aktual di Laci ($sym)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (actualCtrl.text.isNotEmpty) ...[
                    Text(
                      'Ekspektasi Sistem: ${PosFormatters.currency(shift.expectedCash, symbol: sym)}',
                      style: AppTheme.tabular(null, fontSize: 13),
                    ),
                    Text(
                      'Selisih: ${PosFormatters.currency(diff, symbol: sym)}',
                      style: AppTheme.tabular(
                        null,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: diff == 0
                            ? context.posColors.statusSuccess
                            : context.posColors.statusWarning,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Catatan Penutupan'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  if (actualCtrl.text.isEmpty) return;
                  await ctrl.closeShift(actual, notes: notesCtrl.text.trim());
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Shift ditutup & Z-Report dicetak bila printer siap'),
                      ),
                    );
                  }
                },
                child: const Text('Sahkan & Tutup Shift'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.posColors;
    final sym = ctrl.currencySymbol;
    final shift = ctrl.activeShift;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Shift Kasir & Laci Kas',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        if (shift == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_open_rounded,
                          color: colors.brandPrimary, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Belum Ada Shift Aktif',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan modal awal uang tunai di laci kas untuk memulai shift (${ctrl.activeUser?.name ?? "-"}).',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _openingCashCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Modal Awal Laci Kas ($sym)',
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _openingNotesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Awal (opsional)',
                      prefixIcon: Icon(Icons.note_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final openCash =
                            int.tryParse(_openingCashCtrl.text) ?? 0;
                        await ctrl.openShift(openCash,
                            notes: _openingNotesCtrl.text.trim());
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Buka Shift Sekarang'),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.statusSuccess.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'SHIFT AKTIF',
                          style: TextStyle(
                            color: colors.statusSuccess,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mulai: ${PosFormatters.dateTime(shift.openedAt)}',
                          style: TextStyle(
                              fontSize: 12, color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _metricTile(
                          colors,
                          'Modal Awal',
                          PosFormatters.currency(shift.openingCash, symbol: sym),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _metricTile(
                          colors,
                          'Ekspektasi Laci Kas',
                          PosFormatters.currency(shift.expectedCash,
                              symbol: sym),
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openCashFlowDialog('cash_in'),
                          icon: Icon(Icons.add_circle_outline,
                              color: colors.statusSuccess),
                          label: const Text('Kas Masuk'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openCashFlowDialog('cash_out'),
                          icon: Icon(Icons.remove_circle_outline,
                              color: colors.statusDanger),
                          label: const Text('Kas Keluar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.statusWarning,
                      ),
                      onPressed: _openCloseShiftDialog,
                      icon: const Icon(Icons.lock_clock_rounded),
                      label: const Text('Tutup Shift & Cetak Z-Report'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mutasi Kas Laci Shift Ini',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (ctrl.activeShiftCashFlows.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada kas masuk/keluar manual pada shift ini.'),
              ),
            )
          else
            ...ctrl.activeShiftCashFlows.map((cf) {
              final isIn = cf.type == 'cash_in';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    isIn ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIn ? colors.statusSuccess : colors.statusDanger,
                  ),
                  title: Text(cf.notes.isEmpty ? cf.category : cf.notes,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(PosFormatters.dateTime(cf.createdAt)),
                  trailing: Text(
                    '${isIn ? "+" : "-"}${PosFormatters.currency(cf.amount, symbol: sym)}',
                    style: AppTheme.tabular(
                      null,
                      fontWeight: FontWeight.w700,
                      color: isIn ? colors.statusSuccess : colors.statusDanger,
                    ),
                  ),
                ),
              );
            }),
        ],
        const SizedBox(height: 20),
        const Text(
          'Riwayat Shift Terakhir',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (ctrl.shiftHistory.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada riwayat shift.'),
            ),
          )
        else
          ...ctrl.shiftHistory.map((s) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  'Shift #${s.id} • ${s.status.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Buka: ${PosFormatters.dateTime(s.openedAt)}\nTutup: ${PosFormatters.dateTime(s.closedAt)}',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      PosFormatters.currency(s.actualCash ?? s.expectedCash,
                          symbol: sym),
                      style: AppTheme.tabular(null, fontWeight: FontWeight.w700),
                    ),
                    if (s.status == 'closed')
                      Text(
                        'Selisih: ${PosFormatters.currency(s.cashDifference, symbol: sym)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: s.cashDifference == 0
                              ? colors.statusSuccess
                              : colors.statusWarning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _metricTile(PosColors colors, String label, String value,
      {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? colors.surfaceHighlight : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.tabular(
              null,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: highlight ? colors.brandPrimary : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
