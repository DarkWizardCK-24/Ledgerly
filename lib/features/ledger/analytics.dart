import 'package:intl/intl.dart';

import 'models.dart';

/// Pure derivations over transactions. Everything shown in charts comes from here.
int sumOf(Iterable<Txn> txns, TxnType type) => txns.where((x) => x.type == type).fold(0, (s, x) => s + x.amountMinor);

List<MapEntry<String, int>> expenseByCategory(Iterable<Txn> txns) {
  final m = <String, int>{};
  for (final x in txns.where((x) => x.type == TxnType.expense)) {
    m[x.categoryId] = (m[x.categoryId] ?? 0) + x.amountMinor;
  }
  return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

List<MapEntry<String, int>> expenseByMethod(Iterable<Txn> txns) {
  final m = <String, int>{};
  for (final x in txns.where((x) => x.type == TxnType.expense)) {
    m[x.method] = (m[x.method] ?? 0) + x.amountMinor;
  }
  return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

List<MapEntry<String, int>> topMerchants(Iterable<Txn> txns, {int n = 5}) {
  final m = <String, int>{};
  for (final x in txns.where((x) => x.type == TxnType.expense && x.merchant.trim().isNotEmpty)) {
    m[x.merchant] = (m[x.merchant] ?? 0) + x.amountMinor;
  }
  return (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(n).toList();
}

List<Txn> largestExpenses(Iterable<Txn> txns, {int n = 5}) =>
    (txns.where((x) => x.type == TxnType.expense).toList()..sort((a, b) => b.amountMinor.compareTo(a.amountMinor))).take(n).toList();

class Monthly {
  const Monthly(this.labels, this.income, this.expense);
  final List<String> labels;
  final List<int> income;
  final List<int> expense;
}

Monthly monthlySeries(Iterable<Txn> txns, DateTime now, {int months = 6}) {
  final starts = [for (var i = months - 1; i >= 0; i--) DateTime(now.year, now.month - i)];
  final list = txns.toList();
  int total(DateTime m, TxnType t) =>
      list.where((x) => x.type == t && x.date.year == m.year && x.date.month == m.month).fold(0, (s, x) => s + x.amountMinor);
  return Monthly(
    [for (final m in starts) DateFormat('MMM').format(m)],
    [for (final m in starts) total(m, TxnType.income)],
    [for (final m in starts) total(m, TxnType.expense)],
  );
}

/// (income - expense) / income, or null when there is no income to compare against.
double? savingsRate(int income, int expense) => income <= 0 ? null : (income - expense) / income;
