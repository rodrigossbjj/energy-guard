import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room_model.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'mock_storage.dart';

class RoomService {
  String get baseUrl => ApiConfig.roomsUrl;

  Future<List<RoomModel>> getRooms({String? authToken}) async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: _buildHeaders(authToken ?? AuthService.currentToken),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        MockStorage.isMockMode = false;
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((item) => RoomModel.fromJson(item)).toList();
      } else {
        throw Exception('Falha ao carregar salas: ${response.statusCode}');
      }
    } catch (_) {
      MockStorage.isMockMode = true;
      return List<RoomModel>.from(MockStorage.rooms);
    }
  }

  Future<RoomModel> createRoom(Map<String, dynamic> roomData, {String? authToken}) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: _buildHeaders(authToken ?? AuthService.currentToken),
        body: jsonEncode(roomData),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 201) {
        return RoomModel.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Falha ao criar sala');
      }
    } catch (_) {
      final newRoom = RoomModel(
        id: 'mock-room-${DateTime.now().millisecondsSinceEpoch}',
        name: roomData['name'] ?? 'Nova Sala',
        deviceId: roomData['deviceId'] ?? 'EG-NEW',
        occupancyStatus: 'EMPTY',
        acStatus: false,
        targetTemperature: (roomData['targetTemperature'] as num?)?.toDouble() ?? 23.0,
        lastAbsenceMinutes: 0.0,
        totalWastedMinutes: 0.0,
      );
      MockStorage.rooms.add(newRoom);
      return newRoom;
    }
  }

  Future<RoomModel> updateRoom(String id, Map<String, dynamic> roomData, {String? authToken}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: _buildHeaders(authToken ?? AuthService.currentToken),
        body: jsonEncode(roomData),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return RoomModel.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Falha ao atualizar sala');
      }
    } catch (_) {
      final index = MockStorage.rooms.indexWhere((r) => r.id == id);
      if (index != -1) {
        final old = MockStorage.rooms[index];
        final updated = RoomModel(
          id: old.id,
          name: roomData['name'] ?? old.name,
          deviceId: roomData['deviceId'] ?? old.deviceId,
          occupancyStatus: old.occupancyStatus,
          acStatus: old.acStatus,
          targetTemperature: (roomData['targetTemperature'] as num?)?.toDouble() ?? old.targetTemperature,
          lastAbsenceMinutes: old.lastAbsenceMinutes,
          totalWastedMinutes: old.totalWastedMinutes,
        );
        MockStorage.rooms[index] = updated;
        return updated;
      }
      throw Exception('Sala não encontrada no mock');
    }
  }

  Future<void> deleteRoom(String id, {String? authToken}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: _buildHeaders(authToken ?? AuthService.currentToken),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 204) {
        throw Exception('Falha ao deletar sala: ${response.statusCode}');
      }
    } catch (_) {
      MockStorage.rooms.removeWhere((r) => r.id == id);
    }
  }

  Future<RoomModel> updateRoomStatus(
    String id, {
    bool? acStatus,
    String? occupancyStatus,
    double? targetTemperature,
    String? authToken,
  }) async {
    final body = <String, dynamic>{};
    if (acStatus != null) body['acStatus'] = acStatus;
    if (occupancyStatus != null) body['occupancyStatus'] = occupancyStatus;
    if (targetTemperature != null) body['targetTemperature'] = targetTemperature;

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$id/status'),
        headers: _buildHeaders(authToken ?? AuthService.currentToken),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return RoomModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Falha ao atualizar status da sala');
      }
    } catch (_) {
      final index = MockStorage.rooms.indexWhere((r) => r.id == id);
      if (index != -1) {
        final old = MockStorage.rooms[index];
        final newAc = acStatus ?? old.acStatus;
        final newOcc = occupancyStatus ?? old.occupancyStatus;
        final newTemp = targetTemperature ?? old.targetTemperature;
        final updated = RoomModel(
          id: old.id,
          name: old.name,
          deviceId: old.deviceId,
          occupancyStatus: (newAc && newOcc == 'EMPTY') ? 'ALERT_DESPERDICIO' : newOcc,
          acStatus: newAc,
          targetTemperature: newTemp,
          lastAbsenceMinutes: old.lastAbsenceMinutes,
          totalWastedMinutes: old.totalWastedMinutes,
        );
        MockStorage.rooms[index] = updated;
        return updated;
      }
      throw Exception('Sala não encontrada no mock');
    }
  }

  Map<String, String> _buildHeaders(String? authToken) {
    final headers = {'Content-Type': 'application/json'};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }
}
