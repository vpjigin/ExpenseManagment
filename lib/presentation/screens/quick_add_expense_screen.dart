import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/notifiers/expense_notifier.dart';
import '../../domain/entities/expense.dart';
import '../../core/utils/uuid_generator.dart';
import '../../application/providers/account_repository_provider.dart';
import '../../application/providers/category_repository_provider.dart';

/// Quick add expense screen shown as overlay when SMS is received
class QuickAddExpenseScreen extends ConsumerStatefulWidget {
  final double? prefilledAmount;
  final String? smsBody;

  const QuickAddExpenseScreen({
    super.key,
    this.prefilledAmount,
    this.smsBody,
  });

  @override
  ConsumerState<QuickAddExpenseScreen> createState() =>
      _QuickAddExpenseScreenState();
}

class _QuickAddExpenseScreenState extends ConsumerState<QuickAddExpenseScreen> {
  static const MethodChannel _channel = MethodChannel('quick_add_expense');
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedAccountId;
  String? _selectedCategoryId;
  List<dynamic> _accounts = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefilledData();
    _loadData();
  }

  Future<void> _loadPrefilledData() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPrefilledData');
      if (result != null) {
        final amount = result['amount'] as double?;
        
        if (amount != null && amount > 0) {
          _amountController.text = amount.toStringAsFixed(2);
        }
      }
    } catch (e) {
      // If method channel fails, use widget parameters
      if (widget.prefilledAmount != null) {
        _amountController.text = widget.prefilledAmount!.toStringAsFixed(2);
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final accountRepo = ref.read(accountRepositoryProvider);
      final categoryRepo = ref.read(categoryRepositoryProvider);

      final accounts = await accountRepo.getAllAccounts();
      final categories = await categoryRepo.getAllCategories();

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _categories = categories;
          _isLoading = false;
          // Auto-select first account if available
          if (accounts.isNotEmpty) {
            _selectedAccountId = accounts.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(_amountController.text.trim());
    
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
        ),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an account'),
        ),
      );
      return;
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final expense = Expense(
        id: UuidGenerator.generate(),
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        categoryId: _selectedCategoryId,
        accountId: _selectedAccountId!,
        amount: amount,
        date: now,
        note: widget.smsBody ?? '',
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(expenseNotifierProvider.notifier).addExpense(expense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense added successfully!'),
            duration: Duration(seconds: 1),
          ),
        );
        // Close the screen after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Add Expense'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter expense name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      hintText: 'Enter amount',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ..._categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Account *',
                      border: OutlineInputBorder(),
                    ),
                    items: _accounts.map((account) {
                      return DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(account.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAccountId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveExpense,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Expense'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
    );
  }
}
