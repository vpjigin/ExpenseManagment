import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling SMS permissions
class PermissionService {
  static const String _permissionAskedKey = 'sms_permission_asked';
  static const String _permissionGrantedKey = 'sms_permission_granted';

  /// Check if SMS permission has been asked before
  static Future<bool> hasAskedPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionAskedKey) ?? false;
  }

  /// Check if SMS permission is granted
  static Future<bool> isPermissionGranted() async {
    try {
      final status = await ph.Permission.sms.status;
      return status.isGranted;
    } catch (e) {
      // If SMS permission is not available, return false
      return false;
    }
  }

  /// Request SMS permission
  static Future<bool> requestPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Mark that we've asked for permission
      await prefs.setBool(_permissionAskedKey, true);
      
      // Request permission
      final status = await ph.Permission.sms.request();
      
      // Save permission status
      await prefs.setBool(_permissionGrantedKey, status.isGranted);
      
      return status.isGranted;
    } catch (e) {
      // If SMS permission is not available, mark as asked and return false
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_permissionAskedKey, true);
      return false;
    }
  }

  /// Check if permission was previously granted
  static Future<bool> wasPermissionGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionGrantedKey) ?? false;
  }

  /// Open app settings if permission is permanently denied
  static Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }
}
