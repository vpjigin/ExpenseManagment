import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

/// Domain entity representing a category
@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required int createdAt, // Epoch millis
    required int updatedAt, // Epoch millis
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
