import '../models/dashboard_summary_model.dart';
import '../models/room_model.dart';

class MockStorage {
  static bool isMockMode = false;

  static final List<RoomModel> rooms = [
    RoomModel(
      id: 'mock-room-1',
      name: 'Lab. Microcontroladores (Sala 101)',
      deviceId: 'EG-A4CF12',
      occupancyStatus: 'ALERT_DESPERDICIO',
      acStatus: true,
      targetTemperature: 23.0,
      lastAbsenceMinutes: 4.5,
      totalWastedMinutes: 14.2,
    ),
    RoomModel(
      id: 'mock-room-2',
      name: 'Auditório Principal',
      deviceId: 'EG-B5D133',
      occupancyStatus: 'OCCUPIED',
      acStatus: true,
      targetTemperature: 22.0,
      lastAbsenceMinutes: 2.0,
      totalWastedMinutes: 2.0,
    ),
    RoomModel(
      id: 'mock-room-3',
      name: 'Sala de Estudos 02',
      deviceId: 'EG-C6E244',
      occupancyStatus: 'EMPTY',
      acStatus: false,
      targetTemperature: 24.0,
      lastAbsenceMinutes: 0.0,
      totalWastedMinutes: 0.0,
    ),
  ];

  static DashboardSummaryModel getSummary() {
    final totalRooms = rooms.length;
    final roomsOccupied = rooms.where((r) => r.occupancyStatus == 'OCCUPIED').length;
    final roomsInAlert = rooms.where((r) => r.occupancyStatus == 'ALERT_DESPERDICIO').length;
    final roomsEmpty = totalRooms - roomsOccupied - roomsInAlert;
    final acOnCount = rooms.where((r) => r.acStatus).length;
    final wastingAcCount = rooms.where((r) => r.acStatus && r.occupancyStatus != 'OCCUPIED').length;

    final totalWastedMinutes = rooms.fold<double>(
      0.0,
      (sum, room) => sum + room.totalWastedMinutes,
    );

    final alertRooms = rooms.where((r) => r.occupancyStatus == 'ALERT_DESPERDICIO').toList();

    return DashboardSummaryModel(
      totalRooms: totalRooms,
      roomsOccupied: roomsOccupied,
      roomsEmpty: roomsEmpty,
      roomsInAlert: roomsInAlert,
      acOnCount: acOnCount,
      wastingAcCount: wastingAcCount,
      totalWastedMinutes: double.parse(totalWastedMinutes.toStringAsFixed(2)),
      alertRooms: alertRooms,
    );
  }
}
