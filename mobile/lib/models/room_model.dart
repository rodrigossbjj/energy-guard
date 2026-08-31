class RoomModel {
  final String id;
  final String name;
  final String? location;
  final int? capacity;
  final String? deviceId;
  final String occupancyStatus;
  final bool acStatus;
  final double targetTemperature;
  final double? currentTemperature;

  RoomModel({
    required this.id,
    required this.name,
    this.location,
    this.capacity,
    this.deviceId,
    required this.occupancyStatus,
    required this.acStatus,
    required this.targetTemperature,
    this.currentTemperature,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String?,
      capacity: json['capacity'] as int?,
      deviceId: json['deviceId'] as String?,
      occupancyStatus: json['occupancyStatus'] as String? ?? 'EMPTY',
      acStatus: json['acStatus'] as bool? ?? false,
      targetTemperature: (json['targetTemperature'] as num?)?.toDouble() ?? 23.0,
      currentTemperature: (json['currentTemperature'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'capacity': capacity,
      'deviceId': deviceId,
      'occupancyStatus': occupancyStatus,
      'acStatus': acStatus,
      'targetTemperature': targetTemperature,
      'currentTemperature': currentTemperature,
    };
  }
}
