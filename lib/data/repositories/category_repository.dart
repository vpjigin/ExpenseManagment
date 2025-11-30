import 'package:drift/drift.dart';
import '../../domain/entities/category.dart' as domain;
import '../database/app_database.dart' as drift show AppDatabase, Category, CategoriesCompanion;
import '../../core/utils/uuid_generator.dart';

/// Repository implementation for category data operations
class CategoryRepository {
  final drift.AppDatabase _database;

  CategoryRepository(this._database);

  /// Get all categories
  Future<List<domain.Category>> getAllCategories() async {
    final categories = await _database.select(_database.categories).get();
    return categories.map(_toEntity).toList();
  }

  /// Get category by ID
  Future<domain.Category?> getCategoryById(String id) async {
    final category = await (_database.select(_database.categories)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    return category != null ? _toEntity(category) : null;
  }

  /// Create a new category
  Future<domain.Category> createCategory(domain.Category category) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final categoryCompanion = _toCompanion(category).copyWith(
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await _database.into(_database.categories).insert(categoryCompanion);
    return category.copyWith(
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update an existing category
  Future<domain.Category> updateCategory(domain.Category category) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final categoryCompanion = _toCompanion(category).copyWith(
      updatedAt: Value(now),
    );
    await (_database.update(_database.categories)
          ..where((tbl) => tbl.id.equals(category.id)))
        .write(categoryCompanion);
    return category.copyWith(updatedAt: now);
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    await (_database.delete(_database.categories)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  /// Convert database row to domain entity
  domain.Category _toEntity(drift.Category row) {
    return domain.Category(
      id: row.id,
      name: row.name,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Convert domain entity to database companion
  drift.CategoriesCompanion _toCompanion(domain.Category category) {
    return drift.CategoriesCompanion.insert(
      id: category.id.isEmpty ? UuidGenerator.generate() : category.id,
      name: category.name,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    );
  }
}
