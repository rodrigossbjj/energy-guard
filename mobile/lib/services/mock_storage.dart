import '../models/dashboard_summary_model.dart';
import '../models/room_model.dart';

class MockStorage {
  static bool isMockMode = false;

  static final List<RoomModel> rooms = [
    RoomModel(
      id: 'mock-room-1',
      name: 'Lab. Microcontroladores (Sala 101)',
      location: 'Bloco C - 1º Andar',
      capacity: 30,
      deviceId: 'EG-A4CF12',
      occupancyStatus: 'ALERT_DESPERDICIO',
      acStatus: true,
      targetTemperature: 22.0,
      currentTemperature: 21.4,
    ),
    RoomModel(
      id: 'mock-room-2',
      name: 'Auditório Principal',
      location: 'Bloco A - Térreo',
      capacity: 120,
      deviceId: 'EG-B5D133',
      occupancyStatus: 'OCCUPIED',
      acStatus: true,
      targetTemperature: 23.0,
      currentTemperature: 23.2,
    ),
    RoomModel(
      id: 'mock-room-3',
      name: 'Sala de Reuniões 02',
      location: 'Bloco B - 2º Andar',
      capacity: 12,
      deviceId: 'EG-C6E244',
      occupancyStatus: 'EMPTY',
      acStatus: false,
      targetTemperature: 24.0,
      currentTemperature: 27.8,
    ),
  ];

  static DashboardSummaryModel getSummary() {
    final totalRooms = rooms.length;
    final roomsOccupied = rooms.where((r) => r.occupancyStatus == 'OCCUPIED').length;
    final roomsEmpty = rooms.where((r) => r.occupancyStatus == 'EMPTY').length;
    final roomsInAlert = rooms.where((r) => r.occupancyStatus == 'ALERT_DESPERDICIO').length;
    final acOnCount = rooms.where((r) => r.acStatus).length;
    final wastingAcCount = rooms.where((r) => r.acStatus && r.occupancyStatus != 'OCCUPIED').length;

    // Estimativa mockada de 2.2 kWh por AC e R$ 0.85/kWh
    final estimatedWastedKwh = wastingAcCount * 2.2;
    final estimatedCost = estimatedWastedKwh * 0.85;
    final alertRooms = rooms.where((r) => r.occupancyStatus == 'ALERT_DESPERDICIO').toList();

    return DashboardSummaryModel(
      totalRooms: totalRooms,
      roomsOccupied: roomsOccupied,
      roomsEmpty: roomsEmpty,
      roomsInAlert: roomsInAlert,
      acOnCount: acOnCount,
      wastingAcCount: wastingAcCount,
      estimatedWastedKwhPerHour: estimatedWastedKwh,
      estimatedCostPerHour: estimatedCost,
      alertRooms: alertRooms,
    );
  }
}

