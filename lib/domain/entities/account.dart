import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

/// Domain entity representing an account
@freezed
class Account with _$Account {
  const factory Account({
    required String id,
    required String name,
    String? type, // BANK / UPI / CARD / WALLET / CASH
    @Default(0) int isDeleted,
    required int createdAt, // Epoch millis
    required int updatedAt, // Epoch millis
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}
