import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/account_repository.dart';
import 'database_provider.dart';

/// Provider for account repository
final accountRepositoryProvider =
    Provider<AccountRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return AccountRepository(database);
});
