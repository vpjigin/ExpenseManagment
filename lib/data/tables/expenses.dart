import 'package:drift/drift.dart';

/// Expenses table with UUID string ID
class Expenses extends Table {
  /// UUID string primary key
  TextColumn get id => text()();

  /// Optional title (ex: "Lunch at KFC")
  TextColumn get name => text().nullable()();

  /// Foreign key to categories.id (nullable)
  TextColumn get categoryId => text().nullable()();

  /// Foreign key to accounts.id (required)
  TextColumn get accountId => text()();

  /// Expense amount
  RealColumn get amount => real()();

  /// Epoch millis - when expense happened
  IntColumn get date => integer()();

  /// User notes
  TextColumn get note => text().nullable()();

  /// File path / URL
  TextColumn get attachmentPath => text().nullable()();

  /// Soft delete flag (0/1)
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  /// Epoch millis - when deleted (nullable)
  IntColumn get deletedAt => integer().nullable()();

  /// Epoch millis - creation timestamp
  IntColumn get createdAt => integer()();

  /// Epoch millis - update timestamp
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
