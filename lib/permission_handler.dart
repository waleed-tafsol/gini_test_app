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
      final status = await permission.status;

      // If already granted, continue to next permission
      if (status.isGranted) {
        return PermissionResult(
          isGranted: true,
          isPermanentlyDenied: false,
          permissionName: _getPermissionName(permission),
        );
      }

      // Request permission
      final requestStatus = await permission.request();

      // If granted, continue to next permission
      if (requestStatus.isGranted) {
        return PermissionResult(
          isGranted: true,
          isPermanentlyDenied: false,
          permissionName: _getPermissionName(permission),
        );
      }

      // Return result with denial status
      return PermissionResult(
        isGranted: false,
        isPermanentlyDenied: requestStatus.isPermanentlyDenied,
        permissionName: _getPermissionName(permission),
      );
    }

    // Should not reach here, but return a default result
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
