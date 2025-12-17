abstract class UIEvent {}

class PermissionPermanentlyDeniedEvent extends UIEvent {
  final String permissionName;
  final String message;

  PermissionPermanentlyDeniedEvent({
    required this.permissionName,
    required this.message,
  });
}

class PermissionDeniedEvent extends UIEvent {
  final String permissionName;
  final String message;

  PermissionDeniedEvent({required this.permissionName, required this.message});
}

class ErrorEvent extends UIEvent {
  final String message;

  ErrorEvent({required this.message});
}

class ConfirmationDialogEvent extends UIEvent {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  ConfirmationDialogEvent({
    required this.title,
    required this.message,
    this.confirmText = 'OK',
    this.cancelText = 'Cancel',
  });
}
