import 'package:drift/drift.dart';

/// Categories table with UUID string ID
class Categories extends Table {
  /// UUID string primary key
  TextColumn get id => text()();

  /// Category name (unique)
  TextColumn get name => text()();

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
