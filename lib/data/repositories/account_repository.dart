import 'package:drift/drift.dart';
import '../../domain/entities/account.dart' as domain;
import '../database/app_database.dart' as drift show AppDatabase, Account, AccountsCompanion;
import '../../core/utils/uuid_generator.dart';

// Import Companion classes
import '../database/app_database.dart' as db;

/// Repository implementation for account data operations
class AccountRepository {
  final drift.AppDatabase _database;

  AccountRepository(this._database);

  /// Get all accounts (excluding soft-deleted)
  Future<List<domain.Account>> getAllAccounts() async {
    final accounts = await (_database.select(_database.accounts)
          ..where((tbl) => tbl.isDeleted.equals(0)))
        .get();
    return accounts.map(_toEntity).toList();
  }

  /// Get account by ID
  Future<domain.Account?> getAccountById(String id) async {
    final account = await (_database.select(_database.accounts)
          ..where((tbl) => tbl.id.equals(id) & tbl.isDeleted.equals(0)))
        .getSingleOrNull();
    return account != null ? _toEntity(account) : null;
  }

  /// Create a new account
  Future<domain.Account> createAccount(domain.Account account) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final accountCompanion = _toCompanion(account).copyWith(
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await _database.into(_database.accounts).insert(accountCompanion);
    return account.copyWith(
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update an existing account
  Future<domain.Account> updateAccount(domain.Account account) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final accountCompanion = _toCompanion(account).copyWith(
      updatedAt: Value(now),
    );
    await (_database.update(_database.accounts)
          ..where((tbl) => tbl.id.equals(account.id)))
        .write(accountCompanion);
    return account.copyWith(updatedAt: now);
  }

  /// Soft delete an account
  Future<void> deleteAccount(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(_database.accounts)
          ..where((tbl) => tbl.id.equals(id)))
        .write(db.AccountsCompanion(
      isDeleted: const Value(1),
      updatedAt: Value(now),
    ));
  }

  /// Hard delete an account (permanent removal)
  Future<void> hardDeleteAccount(String id) async {
    await (_database.delete(_database.accounts)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  /// Convert database row to domain entity
  domain.Account _toEntity(drift.Account row) {
    return domain.Account(
      id: row.id,
      name: row.name,
      type: row.type,
      isDeleted: row.isDeleted,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Convert domain entity to database companion
  drift.AccountsCompanion _toCompanion(domain.Account account) {
    return drift.AccountsCompanion.insert(
      id: account.id.isEmpty ? UuidGenerator.generate() : account.id,
      name: account.name,
      type: Value(account.type),
      isDeleted: Value(account.isDeleted),
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }
}
