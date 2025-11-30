import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense.freezed.dart';
part 'expense.g.dart';

/// Domain entity representing an expense
@freezed
class Expense with _$Expense {
  const factory Expense({
    required String id,
    String? name,
    String? categoryId,
    required String accountId,
    required double amount,
    required int date, // Epoch millis
    String? note,
    String? attachmentPath,
    @Default(0) int isDeleted,
    int? deletedAt,
    required int createdAt, // Epoch millis
    required int updatedAt, // Epoch millis
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}
