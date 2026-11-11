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
    http.Response? response;
    try {
      response = await http.post(
        Uri.parse(baseUrl),
        headers: _buildHeaders(authToken ?? AuthService.currentToken),
        body: jsonEncode(roomData),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Falha de rede: utiliza armazenamento simulado (Mock)
      MockStorage.isMockMode = true;
      return MockStorage.createRoom(roomData);
    }

    if (response.statusCode == 201) {
      MockStorage.isMockMode = false;
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      String errorMessage = 'Falha ao criar sala';
      try {
        final err = jsonDecode(response.body);
        errorMessage = err['message'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<RoomModel> updateRoom(String id, Map<String, dynamic> roomData, {String? authToken}) async {
    http.Response? response;
    try {
      response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: _buildHeaders(authToken ?? AuthService.currentToken),
        body: jsonEncode(roomData),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Falha de rede: utiliza armazenamento simulado (Mock)
      MockStorage.isMockMode = true;
      return MockStorage.updateRoom(id, roomData);
    }

    if (response.statusCode == 200) {
      MockStorage.isMockMode = false;
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      String errorMessage = 'Falha ao atualizar sala';
      try {
        final err = jsonDecode(response.body);
        errorMessage = err['message'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
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
