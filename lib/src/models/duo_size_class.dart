/// A UIKit horizontal or vertical size class.
enum DuoSizeClass { compact, regular, unspecified }

/// Size classes attached to the active iOS Flutter view.
///
/// Non-iOS implementations return [DuoSizeClass.unspecified].
class DuoSizeClassInfo {
  const DuoSizeClassInfo({required this.horizontal, required this.vertical});

  final DuoSizeClass horizontal;
  final DuoSizeClass vertical;

  factory DuoSizeClassInfo.fromMap(Map<Object?, Object?> map) =>
      DuoSizeClassInfo(
        horizontal: _parse(map['horizontal']),
        vertical: _parse(map['vertical']),
      );

  static DuoSizeClass _parse(Object? value) =>
      DuoSizeClass.values.where((item) => item.name == value).firstOrNull ??
      DuoSizeClass.unspecified;

  static const unspecified = DuoSizeClassInfo(
    horizontal: DuoSizeClass.unspecified,
    vertical: DuoSizeClass.unspecified,
  );
}
