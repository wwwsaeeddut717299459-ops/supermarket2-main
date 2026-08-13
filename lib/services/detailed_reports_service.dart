import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'finance_service.dart';

enum ReportPeriod { daily, weekly, monthly, yearly }

class PeriodicReportRow {
  final String label;
  final DateTime start;
  final double sales;
  final double saleReturns;
  final double purchases;
  final double purchaseReturns;
  final double expenses;
  final double cogs;

  const PeriodicReportRow({
    required this.label,
    required this.start,
    required this.sales,
    required this.saleReturns,
    required this.purchases,
    required this.purchaseReturns,
    required this.expenses,
    required this.cogs,
  });

  double get netSales => sales - saleReturns;
  double get netPurchases => purchases - purchaseReturns;
  double get grossProfit => netSales - cogs;
  double get netProfit => grossProfit - expenses;
}

class DetailedReport {
  final DateTime from;
  final DateTime to;
  final FinanceSummary summary;
  final List<PeriodicReportRow> rows;
  final Map<String, double> expensesByCategory;

  const DetailedReport({
    required this.from,
    required this.to,
    required this.summary,
    required this.rows,
    required this.expensesByCategory,
  });
}

class DetailedReportsService {
  final AppDatabase db;

  DetailedReportsService(this.db);

  String _format(ReportPeriod period) => switch (period) {
    ReportPeriod.daily => '%Y-%m-%d',
    ReportPeriod.weekly => '%Y-W%W',
    ReportPeriod.monthly => '%Y-%m',
    ReportPeriod.yearly => '%Y',
  };

  DateTime _startOf(DateTime value, ReportPeriod period) {
    final day = DateTime(value.year, value.month, value.day);
    return switch (period) {
      ReportPeriod.daily => day,
      ReportPeriod.weekly => day.subtract(Duration(days: day.weekday - 1)),
      ReportPeriod.monthly => DateTime(day.year, day.month),
      ReportPeriod.yearly => DateTime(day.year),
    };
  }

  DateTime _next(DateTime value, ReportPeriod period) => switch (period) {
    ReportPeriod.daily => value.add(const Duration(days: 1)),
    ReportPeriod.weekly => value.add(const Duration(days: 7)),
    ReportPeriod.monthly => DateTime(value.year, value.month + 1),
    ReportPeriod.yearly => DateTime(value.year + 1),
  };

  String _sqliteWeekKey(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDay).inDays + 1;
    final daysBeforeFirstMonday = firstDay.weekday - 1;
    final week = dayOfYear <= daysBeforeFirstMonday
        ? 0
        : ((dayOfYear - 1 - daysBeforeFirstMonday) ~/ 7) + 1;
    return '${date.year}-W${week.toString().padLeft(2, '0')}';
  }

  Future<Map<String, double>> _group(
    String table,
    String dateColumn,
    String amountColumn,
    DateTime from,
    DateTime to,
    ReportPeriod period, {
    String? where,
  }) async {
    final condition = where == null ? '' : 'AND $where';
    final rows = await db
        .customSelect(
          "SELECT strftime('${_format(period)}', $dateColumn) AS label, COALESCE(SUM($amountColumn), 0) AS value FROM $table WHERE $dateColumn >= ? AND $dateColumn < ? $condition GROUP BY label",
          variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
          readsFrom: {
            if (table == 'sales')
              db.sales
            else if (table == 'purchases')
              db.purchases
            else if (table == 'expenses')
              db.expenses
            else
              db.returns,
          },
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('label'): row.read<double>('value'),
    };
  }

  Future<Map<String, double>> _cogs(
    DateTime from,
    DateTime to,
    ReportPeriod period,
  ) async {
    final rows = await db
        .customSelect(
          "SELECT strftime('${_format(period)}', s.sale_date) AS label, COALESCE(SUM(si.purchase_price_at_sale * si.quantity), 0) AS value FROM sale_items si JOIN sales s ON s.id = si.sale_id WHERE s.status = 'completed' AND s.sale_date >= ? AND s.sale_date < ? GROUP BY label",
          variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
          readsFrom: {db.sales, db.saleItems},
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('label'): row.read<double>('value'),
    };
  }

  Future<DetailedReport> build({
    required DateTime from,
    required DateTime to,
    required ReportPeriod period,
  }) async {
    final normalizedFrom = _startOf(from, period);
    final normalizedTo = to.isAfter(normalizedFrom)
        ? to
        : _next(normalizedFrom, period);
    final summary = await FinanceService(
      db,
    ).summary(normalizedFrom, normalizedTo);
    final sales = await _group(
      'sales',
      'sale_date',
      'total',
      normalizedFrom,
      normalizedTo,
      period,
      where: "status = 'completed'",
    );
    final saleReturns = await _group(
      'returns',
      'return_date',
      'total',
      normalizedFrom,
      normalizedTo,
      period,
      where: "type = 'sale_return' AND status = 'completed'",
    );
    final purchases = await _group(
      'purchases',
      'purchase_date',
      'total',
      normalizedFrom,
      normalizedTo,
      period,
      where: "status != 'cancelled'",
    );
    final purchaseReturns = await _group(
      'returns',
      'return_date',
      'total',
      normalizedFrom,
      normalizedTo,
      period,
      where: "type = 'purchase_return' AND status = 'completed'",
    );
    final expenses = await _group(
      'expenses',
      'expense_date',
      'amount',
      normalizedFrom,
      normalizedTo,
      period,
    );
    final cogs = await _cogs(normalizedFrom, normalizedTo, period);
    final categoryRows = await db
        .customSelect(
          'SELECT ec.name AS name, COALESCE(SUM(e.amount), 0) AS value FROM expenses e JOIN expense_categories ec ON ec.id = e.category_id WHERE e.expense_date >= ? AND e.expense_date < ? GROUP BY ec.id, ec.name ORDER BY value DESC',
          variables: [
            Variable.withDateTime(normalizedFrom),
            Variable.withDateTime(normalizedTo),
          ],
          readsFrom: {db.expenses, db.expenseCategories},
        )
        .get();
    final rows = <PeriodicReportRow>[];
    for (
      var cursor = _startOf(normalizedFrom, period);
      cursor.isBefore(normalizedTo);
      cursor = _next(cursor, period)
    ) {
      final label = cursor.toIso8601String().substring(
        0,
        period == ReportPeriod.yearly
            ? 4
            : period == ReportPeriod.monthly
            ? 7
            : 10,
      );
      final key = period == ReportPeriod.weekly
          ? _sqliteWeekKey(cursor)
          : label;
      rows.add(
        PeriodicReportRow(
          label: period == ReportPeriod.weekly ? key : label,
          start: cursor,
          sales: sales[key] ?? 0,
          saleReturns: saleReturns[key] ?? 0,
          purchases: purchases[key] ?? 0,
          purchaseReturns: purchaseReturns[key] ?? 0,
          expenses: expenses[key] ?? 0,
          cogs: cogs[key] ?? 0,
        ),
      );
    }
    return DetailedReport(
      from: normalizedFrom,
      to: normalizedTo,
      summary: summary,
      rows: rows.reversed.toList(),
      expensesByCategory: {
        for (final row in categoryRows)
          row.read<String>('name'): row.read<double>('value'),
      },
    );
  }
}
