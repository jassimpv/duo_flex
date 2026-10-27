import 'duo_model_parser.dart';

/// Device and operating-system details provided by public platform APIs.
class DuoDeviceInfo {
  const DuoDeviceInfo({this.model, this.systemName, this.systemVersion, this.isFoldable});
  final String? model;
  final String? systemName;
  final String? systemVersion;
  /// Null means foldability is unknown; it is never inferred from the model.
  final bool? isFoldable;

  factory DuoDeviceInfo.fromMap(Map<Object?, Object?> map) => DuoDeviceInfo(
    model: DuoModelParser.optionalString(map['model'], 'model'),
    systemName: DuoModelParser.optionalString(map['systemName'], 'systemName'),
    systemVersion: DuoModelParser.optionalString(map['systemVersion'], 'systemVersion'),
    isFoldable: map['isFoldable'] == null ? null : DuoModelParser.boolean(map['isFoldable'], 'isFoldable'),
  );
  Map<String, Object?> toMap() => {'model': model, 'systemName': systemName, 'systemVersion': systemVersion, 'isFoldable': isFoldable};
  @override
  bool operator ==(Object other) => other is DuoDeviceInfo && model == other.model && systemName == other.systemName && systemVersion == other.systemVersion && isFoldable == other.isFoldable;
  @override
  int get hashCode => Object.hash(model, systemName, systemVersion, isFoldable);
  @override
  String toString() => 'DuoDeviceInfo(${toMap()})';
}
