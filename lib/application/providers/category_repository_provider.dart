import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/category_repository.dart';
import 'database_provider.dart';

/// Provider for category repository
final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return CategoryRepository(database);
});
