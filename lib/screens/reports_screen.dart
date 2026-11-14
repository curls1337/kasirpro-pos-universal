import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';

/// Layar Laporan Laba Rugi (Omzet, HPP, Laba Kotor, Laba Bersih), Top Produk, Riwayat & Export CSV/PDF
class ReportsScreen extends StatefulWidget {
  final PosController controller;

  const ReportsScreen({super.key, required this.controller});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'today'; // 'today' | '7d' | '30d'
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  PosController get ctrl => widget.controller;

  void _setPeriod(String p) {
    final now = DateTime.now();
    setState(() {
      _period = p;
      _endDate = now;
      if (p == 'today') {
        _startDate = now;
      } else if (p == '7d') {
        _startDate = now.subtract(const Duration(days: 6));
      } else {
        _startDate = now.subtract(const Duration(days: 29));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.posColors;
    final sym = ctrl.currencySymbol;
    final isTablet = context.isTablet;

    if (!ctrl.canAccess('reports')) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 48, color: colors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'Akses Terbatas (Admin / Owner)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Laporan Laba Rugi hanya dapat diakses oleh Owner atau Admin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<ProfitLossSummary>(
      future: ctrl.getProfitLossSummary(_startDate, _endDate),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final report = snapshot.data!;

        return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Laporan Laba Rugi & Penjualan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => ctrl.exportSalesCsv(_startDate, _endDate),
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Export CSV'),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      ctrl.exportProfitLossPdf(_startDate, _endDate),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Export PDF'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Hari Ini'),
              selected: _period == 'today',
              onSelected: (_) => _setPeriod('today'),
            ),
            ChoiceChip(
              label: const Text('7 Hari'),
              selected: _period == '7d',
              onSelected: (_) => _setPeriod('7d'),
            ),
            ChoiceChip(
              label: const Text('30 Hari'),
              selected: _period == '30d',
              onSelected: (_) => _setPeriod('30d'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: isTablet ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: isTablet ? 1.7 : 1.5,
          children: [
            _kpiCard(
              colors,
              'Omzet Bersih',
              PosFormatters.currency(report.netSales, symbol: sym),
              '${report.transactionCount} transaksi',
              colors.brandPrimary,
            ),
            _kpiCard(
              colors,
              'Total HPP (Modal)',
              PosFormatters.currency(report.totalCogs, symbol: sym),
              'Biaya pokok barang',
              colors.textSecondary,
            ),
            _kpiCard(
              colors,
              'Laba Kotor',
              PosFormatters.currency(report.grossProfit, symbol: sym),
              'Margin ${report.grossMarginPercent.toStringAsFixed(1)}%',
              colors.statusInfo,
            ),
            _kpiCard(
              colors,
              'Laba Bersih',
              PosFormatters.currency(report.netProfit, symbol: sym),
              'Setelah biaya (${PosFormatters.currency(report.totalExpenses, symbol: sym)})',
              report.netProfit >= 0
                  ? colors.statusSuccess
                  : colors.statusDanger,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rekap Metode Pembayaran',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ...report.paymentBreakdown.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key.toUpperCase(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          PosFormatters.currency(e.value, symbol: sym),
                          style: AppTheme.tabular(null,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top 5 Produk Terlaris',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (report.topProducts.isEmpty)
                  const Text('Belum ada data penjualan pada periode ini.')
                else
                  ...report.topProducts.map(
                    (p) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text((p['product_name'] ?? '-').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Terjual: ${PosFormatters.number((p['total_qty'] as num?) ?? 0)}'),
                      trailing: Text(
                        PosFormatters.currency(
                            (p['total_revenue'] as num?)?.toInt() ?? 0,
                            symbol: sym),
                        style:
                            AppTheme.tabular(null, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Riwayat Transaksi Terakhir',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (ctrl.recentTransactions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada transaksi.'),
            ),
          )
        else
          ...ctrl.recentTransactions.take(40).map((tx) {
            final isVoid = tx.status == 'void';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${tx.invoiceNo} • ${tx.orderType.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: isVoid ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  '${PosFormatters.dateTime(tx.createdAt)} • Status: ${tx.status.toUpperCase()}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      PosFormatters.currency(tx.totalAmount, symbol: sym),
                      style: AppTheme.tabular(
                        null,
                        fontWeight: FontWeight.w800,
                        color: isVoid ? colors.statusDanger : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cetak Ulang Struk',
                      icon: const Icon(Icons.print_outlined, size: 20),
                      onPressed: () async {
                        final msg = await ctrl.printTransactionReceipt(tx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
                    ),
                    if (!isVoid && tx.id != null && ctrl.canAccess('void_tx'))
                      IconButton(
                        tooltip: 'Void Transaksi',
                        icon: Icon(Icons.cancel_outlined,
                            size: 20, color: colors.statusDanger),
                        onPressed: () => ctrl.voidTransaction(tx.id!),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
      },
    );
  }

  Widget _kpiCard(PosColors colors, String title, String value, String sub,
      Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.tabular(
                null,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.textMuted)),
          ],
        ),
      ),
    );
  }
}
