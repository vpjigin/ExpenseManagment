// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExpenseImpl _$$ExpenseImplFromJson(Map<String, dynamic> json) =>
    _$ExpenseImpl(
      id: json['id'] as String,
      name: json['name'] as String?,
      categoryId: json['categoryId'] as String?,
      accountId: json['accountId'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: (json['date'] as num).toInt(),
      note: json['note'] as String?,
      attachmentPath: json['attachmentPath'] as String?,
      isDeleted: (json['isDeleted'] as num?)?.toInt() ?? 0,
      deletedAt: (json['deletedAt'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
    );

Map<String, dynamic> _$$ExpenseImplToJson(_$ExpenseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'categoryId': instance.categoryId,
      'accountId': instance.accountId,
      'amount': instance.amount,
      'date': instance.date,
      'note': instance.note,
      'attachmentPath': instance.attachmentPath,
      'isDeleted': instance.isDeleted,
      'deletedAt': instance.deletedAt,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };
