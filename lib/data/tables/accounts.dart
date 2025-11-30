import 'package:drift/drift.dart';

/// Accounts table with UUID string ID
class Accounts extends Table {
  /// UUID string primary key
  TextColumn get id => text()();

  /// Account name (unique) - Ex: "Cash", "ICICI Bank"
  TextColumn get name => text()();

  /// Account type - Optional (BANK / UPI / CARD / WALLET / CASH)
  TextColumn get type => text().nullable()();

  /// Soft delete flag (0/1) - For account removal
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  /// Epoch millis - creation timestamp
  IntColumn get createdAt => integer()();

  /// Epoch millis - update timestamp
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {name}, // Unique constraint on name
      ];
}
