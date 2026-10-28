/// Fold configuration reported by a platform, when publicly available.
enum DuoFoldPosture {
  unknown,
  closed,
  partiallyOpen,
  halfOpen,
  fullyOpen,
  tabletop,
  book,
  tent,
  continuous,
  folded,
}

/// Converts a platform posture string without throwing for unknown values.
DuoFoldPosture fromNativePosture(String? value) {
  if (value == null) return DuoFoldPosture.unknown;
  final normalized = value.replaceAll('_', '').replaceAll('-', '').toLowerCase();
  for (final posture in DuoFoldPosture.values) {
    if (posture.name.toLowerCase() == normalized) return posture;
  }
  return DuoFoldPosture.unknown;
}

/// Converts a posture to its stable channel representation.
String toNativePosture(DuoFoldPosture posture) => posture.name;
