import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_repository_provider.dart';
import '../../data/repositories/expense_repository.dart';
import '../../core/utils/uuid_generator.dart';

/// State for expense list
class ExpenseState {
  final List<Expense> expenses;
  final bool isLoading;
  final String? error;

  ExpenseState({
    required this.expenses,
    this.isLoading = false,
    this.error,
  });

  ExpenseState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    String? error,
  }) {
    return ExpenseState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for managing expense state
class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final ExpenseRepository _repository;

  ExpenseNotifier(this._repository) : super(ExpenseState(expenses: [])) {
    loadExpenses();
  }

  /// Load all expenses
  Future<void> loadExpenses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final expenses = await _repository.getAllExpenses();
      state = state.copyWith(expenses: expenses, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Add a new expense
  Future<void> addExpense(Expense expense) async {
    try {
      final expenseWithId = expense.id.isEmpty
          ? expense.copyWith(id: UuidGenerator.generate())
          : expense;
      await _repository.createExpense(expenseWithId);
      await loadExpenses();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    try {
      await _repository.updateExpense(expense);
      await loadExpenses();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete an expense
  Future<void> deleteExpense(String id) async {
    try {
      await _repository.deleteExpense(id);
      await loadExpenses();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider for expense notifier
final expenseNotifierProvider =
    StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return ExpenseNotifier(repository);
});
