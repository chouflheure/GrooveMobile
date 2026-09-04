/// Compares two dot-separated version strings (e.g. "1.4.2"), ignoring any
/// build suffix (a `+build` part, as used in pubspec's `1.0.0+1`).
///
/// Returns a negative number if [current] < [other], zero if equal, and a
/// positive number if [current] > [other]. Missing/non-numeric segments are
/// treated as 0, so "1.4" == "1.4.0" and a blank string compares as "0".
int compareVersions(String current, String other) {
  final a = _segments(current);
  final b = _segments(other);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final valueA = i < a.length ? a[i] : 0;
    final valueB = i < b.length ? b[i] : 0;
    if (valueA != valueB) return valueA - valueB;
  }
  return 0;
}

/// Whether [current] is strictly lower than [minimum].
bool isVersionBelow(String current, String minimum) =>
    minimum.isNotEmpty && compareVersions(current, minimum) < 0;

List<int> _segments(String version) {
  final withoutBuild = version.split('+').first;
  return withoutBuild
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
}
