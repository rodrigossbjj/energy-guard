import 'room_model.dart';

class DashboardSummaryModel {
  final int totalRooms;
  final int roomsOccupied;
  final int roomsEmpty;
  final int roomsInAlert;
  final int acOnCount;
  final int wastingAcCount;
  final double estimatedWastedKwhPerHour;
  final double estimatedCostPerHour;
  final List<RoomModel> alertRooms;

  DashboardSummaryModel({
    required this.totalRooms,
    required this.roomsOccupied,
    required this.roomsEmpty,
    required this.roomsInAlert,
    required this.acOnCount,
    required this.wastingAcCount,
    required this.estimatedWastedKwhPerHour,
    required this.estimatedCostPerHour,
    required this.alertRooms,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      totalRooms: json['totalRooms'] as int? ?? 0,
      roomsOccupied: json['roomsOccupied'] as int? ?? 0,
      roomsEmpty: json['roomsEmpty'] as int? ?? 0,
      roomsInAlert: json['roomsInAlert'] as int? ?? 0,
      acOnCount: json['acOnCount'] as int? ?? 0,
      wastingAcCount: json['wastingAcCount'] as int? ?? 0,
      estimatedWastedKwhPerHour: (json['estimatedWastedKwhPerHour'] as num?)?.toDouble() ?? 0.0,
      estimatedCostPerHour: (json['estimatedCostPerHour'] as num?)?.toDouble() ?? 0.0,
      alertRooms: (json['alertRooms'] as List<dynamic>?)
              ?.map((item) => RoomModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
