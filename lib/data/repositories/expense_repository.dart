import 'package:drift/drift.dart';
import '../../domain/entities/expense.dart' as domain;
import '../database/app_database.dart' as drift show AppDatabase, Expense, ExpensesCompanion;
import '../../core/utils/uuid_generator.dart';

// Import Companion classes
import '../database/app_database.dart' as db;

/// Repository implementation for expense data operations
class ExpenseRepository {
  final drift.AppDatabase _database;

  ExpenseRepository(this._database);

  /// Get all expenses (excluding soft-deleted)
  Future<List<domain.Expense>> getAllExpenses() async {
    final expenses = await (_database.select(_database.expenses)
          ..where((tbl) => tbl.isDeleted.equals(0)))
        .get();
    return expenses.map(_toEntity).toList();
  }

  /// Get expense by ID
  Future<domain.Expense?> getExpenseById(String id) async {
    final expense = await (_database.select(_database.expenses)
          ..where((tbl) => tbl.id.equals(id) & tbl.isDeleted.equals(0)))
        .getSingleOrNull();
    return expense != null ? _toEntity(expense) : null;
  }

  /// Create a new expense
  Future<domain.Expense> createExpense(domain.Expense expense) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expenseCompanion = _toCompanion(expense).copyWith(
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await _database.into(_database.expenses).insert(expenseCompanion);
    return expense.copyWith(
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update an existing expense
  Future<domain.Expense> updateExpense(domain.Expense expense) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expenseCompanion = _toCompanion(expense).copyWith(
      updatedAt: Value(now),
    );
    await (_database.update(_database.expenses)
          ..where((tbl) => tbl.id.equals(expense.id)))
        .write(expenseCompanion);
    return expense.copyWith(updatedAt: now);
  }

  /// Soft delete an expense
  Future<void> deleteExpense(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(_database.expenses)
          ..where((tbl) => tbl.id.equals(id)))
        .write(db.ExpensesCompanion(
      isDeleted: const Value(1),
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  /// Hard delete an expense (permanent removal)
  Future<void> hardDeleteExpense(String id) async {
    await (_database.delete(_database.expenses)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  /// Get expenses by date range (epoch millis)
  Future<List<domain.Expense>> getExpensesByDateRange(
    int startDateMillis,
    int endDateMillis,
  ) async {
    final expenses = await (_database.select(_database.expenses)
          ..where((tbl) =>
              tbl.date.isBiggerOrEqualValue(startDateMillis) &
              tbl.date.isSmallerOrEqualValue(endDateMillis) &
              tbl.isDeleted.equals(0))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
        .get();
    return expenses.map(_toEntity).toList();
  }

  /// Convert database row to domain entity
  domain.Expense _toEntity(drift.Expense row) {
    return domain.Expense(
      id: row.id,
      name: row.name,
      categoryId: row.categoryId,
      accountId: row.accountId,
      amount: row.amount,
      date: row.date,
      note: row.note,
      attachmentPath: row.attachmentPath,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Convert domain entity to database companion
  drift.ExpensesCompanion _toCompanion(domain.Expense expense) {
    return drift.ExpensesCompanion.insert(
      id: expense.id.isEmpty ? UuidGenerator.generate() : expense.id,
      name: Value(expense.name),
      categoryId: Value(expense.categoryId),
      accountId: expense.accountId,
      amount: expense.amount,
      date: expense.date,
      note: Value(expense.note),
      attachmentPath: Value(expense.attachmentPath),
      isDeleted: Value(expense.isDeleted),
      deletedAt: Value(expense.deletedAt),
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
    );
  }
}
