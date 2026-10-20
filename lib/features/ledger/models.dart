import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum TxnType { income, expense }

enum Period { today, week, month, lastMonth, year }

extension PeriodX on Period {
  String get label => switch (this) {
        Period.today => 'Today',
        Period.week => 'This week',
        Period.month => 'This month',
        Period.lastMonth => 'Last month',
        Period.year => 'This year',
      };

  /// Half-open range [start, end).
  DateTimeRange range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      Period.today => DateTimeRange(start: today, end: today.add(const Duration(days: 1))),
      Period.week => DateTimeRange(
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: today.add(const Duration(days: 1))),
      Period.month => DateTimeRange(start: DateTime(now.year, now.month), end: today.add(const Duration(days: 1))),
      Period.lastMonth => DateTimeRange(start: DateTime(now.year, now.month - 1), end: DateTime(now.year, now.month)),
      Period.year => DateTimeRange(start: DateTime(now.year), end: today.add(const Duration(days: 1))),
    };
  }

  /// The comparable earlier window: same elapsed length, aligned to the prior month/year where that applies.
  DateTimeRange previous(DateTime now) {
    final r = range(now);
    final len = r.end.difference(r.start);
    switch (this) {
      case Period.month:
        final start = DateTime(r.start.year, r.start.month - 1);
        return DateTimeRange(start: start, end: start.add(len));
      case Period.year:
        final start = DateTime(r.start.year - 1);
        return DateTimeRange(start: start, end: start.add(len));
      case Period.lastMonth:
        return DateTimeRange(start: DateTime(r.start.year, r.start.month - 1), end: r.start);
      case Period.today:
      case Period.week:
        return DateTimeRange(start: r.start.subtract(len), end: r.start);
    }
  }
}

const paymentMethods = ['Cash', 'UPI', 'Bank transfer', 'Debit card', 'Credit card', 'Other'];

class Category {
  const Category(this.id, this.name, this.icon, this.color, {this.income = false, this.archived = false, this.builtin = true});
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool income;
  final bool archived;
  final bool builtin;

  Category copyWith({String? id, String? name, IconData? icon, Color? color, bool? archived}) => Category(
        id ?? this.id,
        name ?? this.name,
        icon ?? this.icon,
        color ?? this.color,
        income: income,
        archived: archived ?? this.archived,
        builtin: builtin,
      );
}

const defaultCategories = <Category>[
  Category('food', 'Food & groceries', LucideIcons.utensils, Color(0xFFF97316)),
  Category('transport', 'Transportation', LucideIcons.car, Color(0xFF0EA5E9)),
  Category('housing', 'Housing', LucideIcons.house, Color(0xFF8B5CF6)),
  Category('utilities', 'Utilities', LucideIcons.zap, Color(0xFFEAB308)),
  Category('shopping', 'Shopping', LucideIcons.shoppingBag, Color(0xFFEC4899)),
  Category('health', 'Healthcare', LucideIcons.heartPulse, Color(0xFFEF4444)),
  Category('fun', 'Entertainment', LucideIcons.clapperboard, Color(0xFF14B8A6)),
  Category('education', 'Education', LucideIcons.graduationCap, Color(0xFF6366F1)),
  Category('subs', 'Subscriptions', LucideIcons.repeat, Color(0xFFA855F7)),
  Category('travel', 'Travel', LucideIcons.plane, Color(0xFF06B6D4)),
  Category('personal', 'Personal care', LucideIcons.sparkles, Color(0xFFF472B6)),
  Category('fees', 'Fees & charges', LucideIcons.receipt, Color(0xFF64748B)),
  Category('other', 'Other', LucideIcons.ellipsis, Color(0xFF94A3B8)),
  Category('salary', 'Salary', LucideIcons.banknote, Color(0xFF12B76A), income: true),
  Category('freelance', 'Freelance income', LucideIcons.laptop, Color(0xFF22C55E), income: true),
  Category('invest', 'Investments', LucideIcons.trendingUp, Color(0xFF84CC16), income: true),
  Category('otherIn', 'Other income', LucideIcons.landmark, Color(0xFF10B981), income: true),
];

/// Live category list. The ledger store keeps this in sync so lookups like [categoryOf] work anywhere.
List<Category> categories = List.of(defaultCategories);

Category categoryOf(String id) => categories.firstWhere(
      (c) => c.id == id,
      orElse: () => categories.firstWhere((c) => !c.income && c.name == 'Other', orElse: () => defaultCategories[12]),
    );

/// The category preselected in the transaction form (ids differ between sample data and the server).
String defaultCategoryId({required bool income}) {
  final name = income ? 'Salary' : 'Food & groceries';
  for (final c in categories) {
    if (c.income == income && c.name == name && !c.archived) return c.id;
  }
  for (final c in categories) {
    if (c.income == income && !c.archived) return c.id;
  }
  return income ? 'salary' : 'food';
}

/// Icons offered when creating or editing a category.
const categoryIcons = <IconData>[
  LucideIcons.utensils, LucideIcons.car, LucideIcons.house, LucideIcons.zap, LucideIcons.shoppingBag,
  LucideIcons.heartPulse, LucideIcons.clapperboard, LucideIcons.graduationCap, LucideIcons.repeat,
  LucideIcons.plane, LucideIcons.sparkles, LucideIcons.receipt, LucideIcons.banknote, LucideIcons.laptop,
  LucideIcons.trendingUp, LucideIcons.landmark, LucideIcons.gift, LucideIcons.dumbbell, LucideIcons.pawPrint,
  LucideIcons.coffee, LucideIcons.baby, LucideIcons.wrench, LucideIcons.smartphone, LucideIcons.ellipsis,
];

const bookIcons = <String, IconData>{
  'wallet': LucideIcons.wallet,
  'house': LucideIcons.house,
  'briefcase': LucideIcons.briefcase,
  'plane': LucideIcons.plane,
  'education': LucideIcons.graduationCap,
  'folder': LucideIcons.folder,
  'users': LucideIcons.users,
};

const bookColors = <Color>[
  Color(0xFFE8590C),
  Color(0xFFE8384F),
  Color(0xFFF59E0B),
  Color(0xFF0EA5E9),
  Color(0xFF8B5CF6),
  Color(0xFF14B8A6),
];

class BookTemplate {
  const BookTemplate(this.name, this.description, this.iconKey);
  final String name;
  final String description;
  final String iconKey;
}

const bookTemplates = <BookTemplate>[
  BookTemplate('Personal', 'Everyday spending and income', 'wallet'),
  BookTemplate('Household', 'Rent, bills and groceries', 'house'),
  BookTemplate('Freelance', 'Client invoices and expenses', 'briefcase'),
  BookTemplate('Business', 'Company cash flow', 'briefcase'),
  BookTemplate('Travel', 'Trips and holidays', 'plane'),
  BookTemplate('Education', 'Fees and learning', 'education'),
  BookTemplate('Projects', 'Side projects', 'folder'),
];

class Book {
  const Book({
    required this.id,
    required this.name,
    this.description = '',
    required this.currency,
    this.openingMinor = 0,
    required this.color,
    this.iconKey = 'wallet',
    this.archived = false,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String currency;
  final int openingMinor;
  final Color color;
  final String iconKey;
  final bool archived;
  final DateTime createdAt;

  IconData get icon => bookIcons[iconKey] ?? LucideIcons.wallet;

  Book copyWith({
    String? id,
    String? name,
    String? description,
    String? currency,
    int? openingMinor,
    Color? color,
    String? iconKey,
    bool? archived,
  }) =>
      Book(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        currency: currency ?? this.currency,
        openingMinor: openingMinor ?? this.openingMinor,
        color: color ?? this.color,
        iconKey: iconKey ?? this.iconKey,
        archived: archived ?? this.archived,
        createdAt: createdAt,
      );
}

class Txn {
  const Txn({
    required this.id,
    required this.bookId,
    required this.type,
    required this.amountMinor,
    required this.title,
    this.note = '',
    required this.categoryId,
    required this.date,
    this.method = 'Cash',
    this.merchant = '',
    this.tags = const [],
    this.source = 'manual',
  });

  final String id;
  final String bookId;
  final TxnType type;
  final int amountMinor; // always positive; sign comes from [type]
  final String title;
  final String note;
  final String categoryId;
  final DateTime date;
  final String method;
  final String merchant;
  final List<String> tags;
  final String source; // 'manual', or 'import' when it came from a reviewed bank statement

  bool get imported => source == 'import';

  int get signed => type == TxnType.income ? amountMinor : -amountMinor;

  Txn copyWith({
    String? id,
    String? bookId,
    TxnType? type,
    int? amountMinor,
    String? title,
    String? note,
    String? categoryId,
    DateTime? date,
    String? method,
    String? merchant,
    List<String>? tags,
    String? source,
  }) =>
      Txn(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        type: type ?? this.type,
        amountMinor: amountMinor ?? this.amountMinor,
        title: title ?? this.title,
        note: note ?? this.note,
        categoryId: categoryId ?? this.categoryId,
        date: date ?? this.date,
        method: method ?? this.method,
        merchant: merchant ?? this.merchant,
        tags: tags ?? this.tags,
        source: source ?? this.source,
      );
}
