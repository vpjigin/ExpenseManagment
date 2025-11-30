import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../tables/expenses.dart';
import '../tables/categories.dart';
import '../tables/accounts.dart';

part 'app_database.g.dart';

/// App database using Drift
@DriftDatabase(tables: [Expenses, Categories, Accounts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Schema changed significantly - drop old tables and recreate
        if (from < 2) {
          // Drop old tables if they exist
          await m.deleteTable('expenses');
          // Create new tables with correct schema
          await m.createTable(expenses);
          await m.createTable(categories);
          await m.createTable(accounts);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'expense_db.sqlite'));
    return NativeDatabase(file);
  });
}
