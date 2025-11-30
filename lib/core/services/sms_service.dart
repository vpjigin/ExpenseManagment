import 'package:flutter/services.dart';
import '../../domain/entities/expense.dart';
import '../../core/utils/uuid_generator.dart';
import '../../application/notifiers/expense_notifier.dart';

/// Service for reading and processing SMS messages
/// Uses native Android via MethodChannel
class SmsService {
  static const MethodChannel _channel = MethodChannel('sms_receiver');
  static ExpenseNotifier? _expenseNotifier;

  /// Read recent SMS messages and extract expenses
  Future<List<Expense>> readRecentSmsForExpenses({
    int limit = 50,
    int daysBack = 7,
  }) async {
    try {
      // Request SMS from native side
      final result = await _channel.invokeMethod<List<dynamic>>('getRecentSms', {
        'limit': limit,
        'daysBack': daysBack,
      });

      if (result == null) return [];

      final expenses = <Expense>[];

      for (var smsData in result) {
        final data = smsData as Map<dynamic, dynamic>;
        final body = data['body'] as String? ?? '';
        final sender = data['sender'] as String? ?? '';
        final timestamp = data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

        final expense = _parseExpenseFromSms(body, sender, timestamp);
        if (expense != null) {
          expenses.add(expense);
        }
      }

      return expenses;
    } catch (e) {
      // Handle permission errors or other issues
      return [];
    }
  }

  /// Initialize SMS listener for background SMS
  /// Optionally provide ExpenseNotifier to auto-save expenses
  static void initialize({ExpenseNotifier? expenseNotifier}) {
    try {
      _expenseNotifier = expenseNotifier;
      _channel.setMethodCallHandler(_handleMethodCall);
    } catch (e) {
      // Handle initialization errors
    }
  }

  /// Handle incoming SMS from native side (background)
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final arguments = call.arguments as Map<dynamic, dynamic>;
      final body = arguments['body'] as String? ?? '';
      final sender = arguments['sender'] as String? ?? '';
      final timestamp = arguments['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      
      // Parse expense from SMS
      final expense = _parseExpenseFromSms(body, sender, timestamp);
      
      // Auto-save expense if notifier is available
      if (expense != null && _expenseNotifier != null) {
        try {
          await _expenseNotifier!.addExpense(expense);
        } catch (e) {
          // Handle error silently
        }
      }
      
      return expense?.toJson();
    }
    return null;
  }

  /// Process recent SMS and create expenses
  /// Returns the number of expenses created
  Future<int> processRecentSmsAndCreateExpenses({
    required ExpenseNotifier expenseNotifier,
    int limit = 50,
    int daysBack = 7,
  }) async {
    try {
      final expenses = await readRecentSmsForExpenses(
        limit: limit,
        daysBack: daysBack,
      );

      int createdCount = 0;
      for (var expense in expenses) {
        try {
          await expenseNotifier.addExpense(expense);
          createdCount++;
        } catch (e) {
          // Skip duplicates or errors
        }
      }

      return createdCount;
    } catch (e) {
      return 0;
    }
  }

  /// Parse an expense from SMS content
  static Expense? _parseExpenseFromSms(String body, String sender, int timestamp) {
    final bodyLower = body.toLowerCase();
    
    // Common patterns for expense SMS:
    // - Amount patterns: Rs.500, ₹500, INR 500, 500 debited, etc.
    // - Keywords: debited, spent, paid, purchase, etc.
    
    // Extract amount (basic regex - can be improved)
    final amountRegex = RegExp(
      r'(?:rs\.?|inr|₹|rupees?)\s*:?\s*(\d+(?:\.\d{2})?)',
      caseSensitive: false,
    );
    
    final match = amountRegex.firstMatch(bodyLower);
    if (match == null) {
      // Try alternative patterns
      final altPattern = RegExp(r'(\d+(?:\.\d{2})?)\s*(?:rs|inr|₹)', caseSensitive: false);
      final altMatch = altPattern.firstMatch(bodyLower);
      if (altMatch == null) return null;
    }

    // Check if it's a debit/expense message
    final isExpense = bodyLower.contains(RegExp(
      r'(debited|spent|paid|purchase|withdrawal|deducted)',
      caseSensitive: false,
    ));

    if (!isExpense) return null;

    // Extract amount
    final amountStr = match?.group(1) ?? '';
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    // Create expense
    return Expense(
      id: UuidGenerator.generate(),
      name: _extractExpenseName(body),
      accountId: sender,
      amount: amount,
      date: timestamp,
      note: body,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Extract expense name from SMS body
  static String? _extractExpenseName(String body) {
    // Try to extract merchant name or transaction description
    // This is a simple implementation - can be improved with ML/NLP
    final lines = body.split('\n');
    for (var line in lines) {
      if (line.toLowerCase().contains(RegExp(r'(at|from|merchant|to)'))) {
        return line.trim();
      }
    }
    return null;
  }
}
