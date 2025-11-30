import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../application/notifiers/expense_notifier.dart';
import '../../domain/entities/expense.dart';
import '../../core/utils/uuid_generator.dart';
import '../../application/providers/account_repository_provider.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/sms_service.dart';
import '../widgets/permission_explanation_dialog.dart';

/// Home screen displaying expenses
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasCheckedPermission = false;

  @override
  void initState() {
    super.initState();
    // Check permission after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermission();
      // Initialize SMS service with expense notifier for auto-processing
      _initializeSmsService();
    });
  }

  void _initializeSmsService() {
    // Initialize SMS service with the expense notifier
    // This allows automatic expense creation from incoming SMS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(expenseNotifierProvider.notifier);
      SmsService.initialize(expenseNotifier: notifier);
    });
  }

  Future<void> _checkPermission() async {
    if (_hasCheckedPermission) return;
    _hasCheckedPermission = true;

    try {
      // Check if permission is already granted
      final isGranted = await PermissionService.isPermissionGranted();
      
      if (isGranted) {
        return; // Permission already granted, no need to show dialog
      }

      // Check if we've asked before
      final hasAsked = await PermissionService.hasAskedPermission();
      
      if (!hasAsked && mounted) {
        // Show explanation dialog
        _showPermissionDialog();
      }
    } catch (e) {
      // If there's an error, just continue
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PermissionExplanationDialog(
        onGrantPermission: () {
          Navigator.of(dialogContext).pop();
          _requestPermission();
        },
        onSkip: () {
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Future<void> _requestPermission() async {
    try {
      final granted = await PermissionService.requestPermission();
      
      if (!granted && mounted) {
        // Check if permission is permanently denied
        try {
          final status = await ph.Permission.sms.status;
          if (status.isPermanentlyDenied && mounted) {
            _showSettingsDialog();
          }
        } catch (e) {
          // If we can't check status, just continue
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void _showSettingsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'SMS permission is required for automatic expense detection. '
          'Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await PermissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanSmsForExpenses() async {
    // Check permission first
    final hasPermission = await PermissionService.isPermissionGranted();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission is required to scan messages'),
          ),
        );
      }
      return;
    }

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanning SMS messages...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      final smsService = SmsService();
      final expenseNotifier = ref.read(expenseNotifierProvider.notifier);
      
      final count = await smsService.processRecentSmsAndCreateExpenses(
        expenseNotifier: expenseNotifier,
        limit: 50,
        daysBack: 7,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Found and added $count expense(s) from SMS'
                  : 'No expenses found in recent SMS messages',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning SMS: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseState = ref.watch(expenseNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Manager'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Scan SMS for expenses',
            onPressed: () => _scanSmsForExpenses(),
          ),
        ],
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
