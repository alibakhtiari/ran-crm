import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for handling battery optimization settings
class BatteryOptimizationService {
  static const platform = MethodChannel('com.crm.ran_crm/battery');

  /// Request to ignore battery optimizations for this app
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final bool result = await platform.invokeMethod('requestIgnoreBatteryOptimizations');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to request battery optimization ignore: ${e.message}');
      }
      return false;
    }
  }

  /// Check if battery optimization is ignored for this app
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool result = await platform.invokeMethod('isBatteryOptimizationIgnored');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to check battery optimization status: ${e.message}');
      }
      return false;
    }
  }

  /// Open battery optimization settings
  Future<bool> openBatteryOptimizationSettings() async {
    try {
      final bool result = await platform.invokeMethod('openBatteryOptimizationSettings');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to open battery optimization settings: ${e.message}');
      }
      return false;
    }
  }
}
