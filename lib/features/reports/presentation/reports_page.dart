import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/database_providers.dart';
import '../../../services/detailed_reports_service.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportPeriod _period = ReportPeriod.daily;
  DateTime _from = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime _to = DateTime.now().add(const Duration(days: 1));
  late Future<DetailedReport> _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _report = ref
        .read(detailedReportsServiceProvider)
        .build(from: _from, to: _to, period: _period);
  }

  void _refresh() => setState(_load);

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _from,
        end: _to.subtract(const Duration(days: 1)),
      ),
    );
    if (picked == null) return;
    setState(() {
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day + 1);
      _load();
    });
  }

  String _periodName(ReportPeriod period) => switch (period) {
    ReportPeriod.daily => 'يومي',
    ReportPeriod.weekly => 'أسبوعي',
    ReportPeriod.monthly => 'شهري',
    ReportPeriod.yearly => 'سنوي',
  };

  Widget _metric(String title, double value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(30),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 6),
                  Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقارير التفصيلية'),
          actions: [
            IconButton(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range),
            ),
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: FutureBuilder<DetailedReport>(
          future: _report,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Center(
                child: Text('تعذر إعداد التقرير: ${snapshot.error}'),
              );
            final report = snapshot.data!;
            final summary = report.summary;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<ReportPeriod>(
                        segments: const [
                          ButtonSegment(
                            value: ReportPeriod.daily,
                            label: Text('يومي'),
                          ),
                          ButtonSegment(
                            value: ReportPeriod.weekly,
                            label: Text('أسبوعي'),
                          ),
                          ButtonSegment(
                            value: ReportPeriod.monthly,
                            label: Text('شهري'),
                          ),
                          ButtonSegment(
                            value: ReportPeriod.yearly,
                            label: Text('سنوي'),
                          ),
                        ],
                        selected: {_period},
                        onSelectionChanged: (value) => setState(() {
                          _period = value.first;
                          _load();
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تقرير ${_periodName(_period)} من ${report.from.toLocal().toString().split(' ').first} إلى ${report.to.subtract(const Duration(days: 1)).toLocal().toString().split(' ').first}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: MediaQuery.sizeOf(context).width > 1000
                        ? 4
                        : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _metric(
                        'إجمالي المبيعات',
                        summary.sales,
                        Icons.point_of_sale,
                        Colors.blue,
                      ),
                      _metric(
                        'مرتجعات المبيعات',
                        summary.saleReturns,
                        Icons.assignment_return,
                        Colors.deepOrange,
                      ),
                      _metric(
                        'صافي المبيعات',
                        summary.sales - summary.saleReturns,
                        Icons.trending_up,
                        Colors.teal,
                      ),
                      _metric(
                        'المشتريات',
                        summary.purchases,
                        Icons.shopping_cart,
                        Colors.indigo,
                      ),
                      _metric(
                        'مرتجعات المشتريات',
                        summary.purchaseReturns,
                        Icons.undo,
                        Colors.purple,
                      ),
                      _metric(
                        'تكلفة البضاعة',
                        summary.cogs,
                        Icons.inventory_2,
                        Colors.orange,
                      ),
                      _metric(
                        'المصروفات',
                        summary.expenses,
                        Icons.money_off,
                        Colors.red,
                      ),
                      _metric(
                        'صافي الربح',
                        summary.netProfit,
                        Icons.account_balance,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _trendTable(report.rows),
                  const SizedBox(height: 24),
                  _categoryCard(report.expensesByCategory),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _categoryCard(Map<String, double> values) {
    final maxValue = values.isEmpty
        ? 1.0
        : values.values.reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المصروفات حسب التصنيف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (values.isEmpty)
              const Text('لا توجد مصروفات في الفترة')
            else
              ...values.entries.map(
                (entry) => ListTile(
                  title: Text(entry.key),
                  trailing: Text(
                    entry.value.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: LinearProgressIndicator(
                    value: maxValue == 0 ? 0 : entry.value / maxValue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _trendTable(List<PeriodicReportRow> rows) {
    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد بيانات للفترة المحددة'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التفصيل حسب الفترة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('الفترة')),
                  DataColumn(label: Text('المبيعات')),
                  DataColumn(label: Text('مرتجع بيع')),
                  DataColumn(label: Text('صافي البيع')),
                  DataColumn(label: Text('المشتريات')),
                  DataColumn(label: Text('مرتجع شراء')),
                  DataColumn(label: Text('المصروفات')),
                  DataColumn(label: Text('صافي الربح')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row.label)),
                          DataCell(Text(row.sales.toStringAsFixed(2))),
                          DataCell(Text(row.saleReturns.toStringAsFixed(2))),
                          DataCell(Text(row.netSales.toStringAsFixed(2))),
                          DataCell(Text(row.purchases.toStringAsFixed(2))),
                          DataCell(
                            Text(row.purchaseReturns.toStringAsFixed(2)),
                          ),
                          DataCell(Text(row.expenses.toStringAsFixed(2))),
                          DataCell(Text(row.netProfit.toStringAsFixed(2))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
