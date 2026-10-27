import 'duo_model_parser.dart';

/// Publicly reported display and fold-related capabilities.
class DuoCapabilities {
  /// Creates a capability snapshot.
  const DuoCapabilities({
    required this.supportsHingeAngle,
    required this.supportsFoldPosture,
    required this.supportsDisplayRegions,
    required this.supportsDisplayChanges,
    required this.supportsMultipleDisplays,
    required this.supportsSafeAreaInsets,
  });

  /// A snapshot indicating that no optional capability is available.
  const DuoCapabilities.unsupported()
    : supportsHingeAngle = false,
      supportsFoldPosture = false,
      supportsDisplayRegions = false,
      supportsDisplayChanges = false,
      supportsMultipleDisplays = false,
      supportsSafeAreaInsets = false;

  final bool supportsHingeAngle;
  final bool supportsFoldPosture;
  final bool supportsDisplayRegions;
  final bool supportsDisplayChanges;
  final bool supportsMultipleDisplays;
  final bool supportsSafeAreaInsets;

  /// Decodes known capability fields; absent fields default to false.
  factory DuoCapabilities.fromMap(Map<Object?, Object?> map) {
    bool read(String key) => DuoModelParser.boolean(map[key], key, fallback: false);
    return DuoCapabilities(
      supportsHingeAngle: read('supportsHingeAngle'),
      supportsFoldPosture: read('supportsFoldPosture'),
      supportsDisplayRegions: read('supportsDisplayRegions'),
      supportsDisplayChanges: read('supportsDisplayChanges'),
      supportsMultipleDisplays: read('supportsMultipleDisplays'),
      supportsSafeAreaInsets: read('supportsSafeAreaInsets'),
    );
  }

  Map<String, Object> toMap() => {
    'supportsHingeAngle': supportsHingeAngle,
    'supportsFoldPosture': supportsFoldPosture,
    'supportsDisplayRegions': supportsDisplayRegions,
    'supportsDisplayChanges': supportsDisplayChanges,
    'supportsMultipleDisplays': supportsMultipleDisplays,
    'supportsSafeAreaInsets': supportsSafeAreaInsets,
  };

  DuoCapabilities copyWith({
    bool? supportsHingeAngle,
    bool? supportsFoldPosture,
    bool? supportsDisplayRegions,
    bool? supportsDisplayChanges,
    bool? supportsMultipleDisplays,
    bool? supportsSafeAreaInsets,
  }) => DuoCapabilities(
    supportsHingeAngle: supportsHingeAngle ?? this.supportsHingeAngle,
    supportsFoldPosture: supportsFoldPosture ?? this.supportsFoldPosture,
    supportsDisplayRegions: supportsDisplayRegions ?? this.supportsDisplayRegions,
    supportsDisplayChanges: supportsDisplayChanges ?? this.supportsDisplayChanges,
    supportsMultipleDisplays: supportsMultipleDisplays ?? this.supportsMultipleDisplays,
    supportsSafeAreaInsets: supportsSafeAreaInsets ?? this.supportsSafeAreaInsets,
  );

  @override
  bool operator ==(Object other) => other is DuoCapabilities &&
      supportsHingeAngle == other.supportsHingeAngle &&
      supportsFoldPosture == other.supportsFoldPosture &&
      supportsDisplayRegions == other.supportsDisplayRegions &&
      supportsDisplayChanges == other.supportsDisplayChanges &&
      supportsMultipleDisplays == other.supportsMultipleDisplays &&
      supportsSafeAreaInsets == other.supportsSafeAreaInsets;

  @override
  int get hashCode => Object.hash(supportsHingeAngle, supportsFoldPosture,
      supportsDisplayRegions, supportsDisplayChanges, supportsMultipleDisplays,
      supportsSafeAreaInsets);

  @override
  String toString() => 'DuoCapabilities(${toMap()})';
}
