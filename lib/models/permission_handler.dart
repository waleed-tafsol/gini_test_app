import 'dart:developer' as developer;
import 'package:permission_handler/permission_handler.dart';

/// Result of a permission request
class PermissionResult {
  final bool isGranted;
  final bool isPermanentlyDenied;
  final String permissionName;

  PermissionResult({
    required this.isGranted,
    required this.isPermanentlyDenied,
    required this.permissionName,
  });
}

class PermissionHandler {
  /// Requests a list of permissions and returns the result
  /// Does not show dialogs - returns result for the caller to handle
  final List<Permission> permissions = [Permission.microphone];

  Future<PermissionResult> requestPermissions() async {
    for (final permission in permissions) {
      try {
        final status = await permission.status;
        developer.log('📱 Permission status for ${_getPermissionName(permission)}: $status');

        // If already granted, return success
        if (status.isGranted) {
          developer.log('✅ Permission already granted: ${_getPermissionName(permission)}');
          return PermissionResult(
            isGranted: true,
            isPermanentlyDenied: false,
            permissionName: _getPermissionName(permission),
          );
        }

        // Check if permission is restricted (iOS specific - parental controls)
        if (status.isRestricted) {
          developer.log('🚫 Permission restricted: ${_getPermissionName(permission)}');
          return PermissionResult(
            isGranted: false,
            isPermanentlyDenied: true,
            permissionName: _getPermissionName(permission),
          );
        }

        // Check if permission is permanently denied
        if (status.isPermanentlyDenied) {
          developer.log('🚫 Permission permanently denied: ${_getPermissionName(permission)}');
          return PermissionResult(
            isGranted: false,
            isPermanentlyDenied: true,
            permissionName: _getPermissionName(permission),
          );
        }

        // Request permission (only if not denied or permanently denied)
        if (status.isDenied) {
          developer.log('📝 Requesting permission: ${_getPermissionName(permission)}');
          final requestStatus = await permission.request();
          developer.log('📱 Permission request result: $requestStatus');

          // If granted, return success
          if (requestStatus.isGranted) {
            developer.log('✅ Permission granted: ${_getPermissionName(permission)}');
            return PermissionResult(
              isGranted: true,
              isPermanentlyDenied: false,
              permissionName: _getPermissionName(permission),
            );
          }

          // Check if now permanently denied after request
          if (requestStatus.isPermanentlyDenied) {
            developer.log('🚫 Permission permanently denied after request: ${_getPermissionName(permission)}');
            return PermissionResult(
              isGranted: false,
              isPermanentlyDenied: true,
              permissionName: _getPermissionName(permission),
            );
          }

          // Permission denied (but not permanently)
          developer.log('❌ Permission denied: ${_getPermissionName(permission)}');
          return PermissionResult(
            isGranted: false,
            isPermanentlyDenied: false,
            permissionName: _getPermissionName(permission),
          );
        }

        // If status is limited (iOS 14+), treat as granted
        if (status.isLimited) {
          developer.log('✅ Permission limited (treated as granted): ${_getPermissionName(permission)}');
          return PermissionResult(
            isGranted: true,
            isPermanentlyDenied: false,
            permissionName: _getPermissionName(permission),
          );
        }

        // Unknown status
        developer.log('⚠️ Unknown permission status: $status for ${_getPermissionName(permission)}');
      } catch (e, stackTrace) {
        developer.log('❌ Error requesting permission: $e', error: e, stackTrace: stackTrace);
        return PermissionResult(
          isGranted: false,
          isPermanentlyDenied: false,
          permissionName: _getPermissionName(permission),
        );
      }
    }

    // Should not reach here, but return a default result
    developer.log('⚠️ No permissions to request');
    return PermissionResult(
      isGranted: false,
      isPermanentlyDenied: false,
      permissionName: 'Unknown',
    );
  }

  /// Opens app settings - can be called from UI after showing dialog
  Future<void> openSettings() async {
    await openAppSettings();
  }

  String _getPermissionName(Permission permission) {
    if (permission == Permission.microphone) {
      return 'Microphone';
    }
    // Add other permission names as needed
    return permission.toString().split('.').last;
  }
}
