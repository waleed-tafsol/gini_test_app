extension StringCasingExtension on String {
  String toCamelCase() {
    if (isEmpty) return this;

    return replaceAllMapped(RegExp(r'_([a-z])'), (Match m) {
      return m.group(1)!.toUpperCase();
    });
  }
}
