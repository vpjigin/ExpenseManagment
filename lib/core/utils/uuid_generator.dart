import 'package:uuid/uuid.dart';

/// Utility class for generating UUIDs
class UuidGenerator {
  static const _uuid = Uuid();

  /// Generates a new UUID v4 string
  static String generate() => _uuid.v4();
}
