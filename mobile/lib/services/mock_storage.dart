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

  static RoomModel createRoom(Map<String, dynamic> roomData) {
    final name = (roomData['name'] ?? 'Nova Sala').toString().trim();
    final deviceId = roomData['deviceId']?.toString().trim();

    if (rooms.any((r) => r.name.toLowerCase() == name.toLowerCase())) {
      throw Exception('Já existe uma sala cadastrada com o nome: $name');
    }

    if (deviceId != null && deviceId.isNotEmpty) {
      final existingIndex = rooms.indexWhere((r) => r.deviceId != null && r.deviceId == deviceId);
      if (existingIndex != -1) {
        final existingRoom = rooms[existingIndex];
        final password = roomData['portabilityPassword']?.toString().trim();
        if (password == null || password.isEmpty) {
          throw Exception(
            "PORTABILITY_REQUIRED: O dispositivo '$deviceId' já está vinculado à sala '${existingRoom.name}'. Digite a senha administrativa para autorizar a portabilidade.",
          );
        }
        if (password != 'admin123') {
          throw Exception('Senha de portabilidade incorreta.');
        }
        // Desvincula o dispositivo da sala anterior
        rooms[existingIndex] = existingRoom.copyWith(deviceId: '');
      }
    }

    final newRoom = RoomModel(
      id: 'mock-room-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      deviceId: (deviceId != null && deviceId.isNotEmpty) ? deviceId : null,
      occupancyStatus: 'EMPTY',
      acStatus: false,
      targetTemperature: (roomData['targetTemperature'] as num?)?.toDouble() ?? 23.0,
      lastAbsenceMinutes: 0.0,
      totalWastedMinutes: 0.0,
    );
    rooms.add(newRoom);
    return newRoom;
  }

  static RoomModel updateRoom(String id, Map<String, dynamic> roomData) {
    final index = rooms.indexWhere((r) => r.id == id);
    if (index == -1) {
      throw Exception('Sala não encontrada no mock');
    }

    final old = rooms[index];
    final name = (roomData['name'] ?? old.name).toString().trim();
    final deviceId = roomData['deviceId']?.toString().trim();

    if (rooms.any((r) => r.id != id && r.name.toLowerCase() == name.toLowerCase())) {
      throw Exception('Já existe outra sala com o nome: $name');
    }

    if (deviceId != null && deviceId.isNotEmpty) {
      final existingIndex = rooms.indexWhere((r) => r.id != id && r.deviceId != null && r.deviceId == deviceId);
      if (existingIndex != -1) {
        final existingRoom = rooms[existingIndex];
        final password = roomData['portabilityPassword']?.toString().trim();
        if (password == null || password.isEmpty) {
          throw Exception(
            "PORTABILITY_REQUIRED: O dispositivo '$deviceId' já está vinculado à sala '${existingRoom.name}'. Digite a senha administrativa para autorizar a portabilidade.",
          );
        }
        if (password != 'admin123') {
          throw Exception('Senha de portabilidade incorreta.');
        }
        // Desvincula o dispositivo da sala anterior
        rooms[existingIndex] = existingRoom.copyWith(deviceId: '');
      }
    }

    final updated = RoomModel(
      id: old.id,
      name: name,
      deviceId: (deviceId != null && deviceId.isNotEmpty) ? deviceId : null,
      occupancyStatus: old.occupancyStatus,
      acStatus: old.acStatus,
      targetTemperature: (roomData['targetTemperature'] as num?)?.toDouble() ?? old.targetTemperature,
      lastAbsenceMinutes: old.lastAbsenceMinutes,
      totalWastedMinutes: old.totalWastedMinutes,
    );
    rooms[index] = updated;
    return updated;
  }
}
