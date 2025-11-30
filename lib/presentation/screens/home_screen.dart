import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/notifiers/expense_notifier.dart';
import '../../domain/entities/expense.dart';
import '../../core/utils/uuid_generator.dart';
import '../../application/providers/account_repository_provider.dart';

/// Home screen displaying expenses
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseState = ref.watch(expenseNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Manager'),
        elevation: 2,
      ),
      body: expenseState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : expenseState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${expenseState.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(expenseNotifierProvider.notifier).loadExpenses();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : expenseState.expenses.isEmpty
                  ? const Center(
                      child: Text(
                        'No expenses yet.\nTap + to add one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      itemCount: expenseState.expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenseState.expenses[index];
                        final date = DateTime.fromMillisecondsSinceEpoch(expense.date);
                        return ListTile(
                          title: Text(expense.name ?? 'Untitled'),
                          subtitle: Text(
                            '${expense.amount.toStringAsFixed(2)} - ${date.toString().split(' ')[0]}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              ref
                                  .read(expenseNotifierProvider.notifier)
                                  .deleteExpense(expense.id);
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    // Get accounts for selection
    final accountRepo = ref.read(accountRepositoryProvider);
    
    accountRepo.getAllAccounts().then((accounts) {
      if (!context.mounted) return;
      
      if (accounts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please create an account first'),
          ),
        );
        return;
      }

      String? selectedAccountId = accounts.first.id;

      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: const Text('Add Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter expense name (e.g., "Lunch at KFC")',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Account',
                    ),
                    items: accounts.map((account) {
                      return DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedAccountId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'Enter notes',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final amount = double.tryParse(amountController.text.trim());

                  if (amount != null && amount > 0 && selectedAccountId != null) {
                    final now = DateTime.now().millisecondsSinceEpoch;
                    final expense = Expense(
                      id: UuidGenerator.generate(),
                      name: name.isEmpty ? null : name,
                      accountId: selectedAccountId!,
                      amount: amount,
                      date: now,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                      createdAt: now,
                      updatedAt: now,
                    );

                    ref.read(expenseNotifierProvider.notifier).addExpense(expense);
                    Navigator.pop(dialogContext);
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter valid amount and select an account'),
                      ),
                    );
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
    });
  }
}
