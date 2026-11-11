class RoomModel {
  final String id;
  final String name;
  final String? deviceId;
  final String occupancyStatus;
  final bool acStatus;
  final double targetTemperature;
  final double? lastAbsenceMinutes;
  final double totalWastedMinutes;

  RoomModel({
    required this.id,
    required this.name,
    this.deviceId,
    required this.occupancyStatus,
    required this.acStatus,
    required this.targetTemperature,
    this.lastAbsenceMinutes,
    this.totalWastedMinutes = 0.0,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceId: json['deviceId'] as String?,
      occupancyStatus: json['occupancyStatus'] as String? ?? 'EMPTY',
      acStatus: json['acStatus'] as bool? ?? false,
      targetTemperature: (json['targetTemperature'] as num?)?.toDouble() ?? 23.0,
      lastAbsenceMinutes: (json['lastAbsenceMinutes'] as num?)?.toDouble(),
      totalWastedMinutes: (json['totalWastedMinutes'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'deviceId': deviceId,
      'occupancyStatus': occupancyStatus,
      'acStatus': acStatus,
      'targetTemperature': targetTemperature,
      'lastAbsenceMinutes': lastAbsenceMinutes,
      'totalWastedMinutes': totalWastedMinutes,
    };
  }

  RoomModel copyWith({
    String? id,
    String? name,
    String? deviceId,
    String? occupancyStatus,
    bool? acStatus,
    double? targetTemperature,
    double? lastAbsenceMinutes,
    double? totalWastedMinutes,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      occupancyStatus: occupancyStatus ?? this.occupancyStatus,
      acStatus: acStatus ?? this.acStatus,
      targetTemperature: targetTemperature ?? this.targetTemperature,
      lastAbsenceMinutes: lastAbsenceMinutes ?? this.lastAbsenceMinutes,
      totalWastedMinutes: totalWastedMinutes ?? this.totalWastedMinutes,
    );
  }
}
