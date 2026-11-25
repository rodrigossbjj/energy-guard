import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room_model.dart';
import 'api_config.dart';
import 'auth_service.dart';

class RoomService {
  String get baseUrl => ApiConfig.roomsUrl;

  Future<List<RoomModel>> getRooms({String? authToken}) async {
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: _buildHeaders(authToken ?? AuthService.currentToken),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((item) => RoomModel.fromJson(item)).toList();
    } else {
      throw Exception('Falha ao carregar salas: ${response.statusCode}');
    }
  }

  Future<RoomModel> createRoom(Map<String, dynamic> roomData, {String? authToken}) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: _buildHeaders(authToken ?? AuthService.currentToken),
      body: jsonEncode(roomData),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 201) {
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response, 'Falha ao criar sala'));
    }
  }

  Future<RoomModel> updateRoom(String id, Map<String, dynamic> roomData, {String? authToken}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: _buildHeaders(authToken ?? AuthService.currentToken),
      body: jsonEncode(roomData),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response, 'Falha ao atualizar sala'));
    }
  }

  Future<void> deleteRoom(String id, {String? authToken}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: _buildHeaders(authToken ?? AuthService.currentToken),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode != 204) {
      throw Exception('Falha ao deletar sala: ${response.statusCode}');
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

    final response = await http.patch(
      Uri.parse('$baseUrl/$id/status'),
      headers: _buildHeaders(authToken ?? AuthService.currentToken),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response, 'Falha ao atualizar status da sala'));
    }
  }

  Future<RoomModel> unlinkDevice(
    String roomId, {
    required String adminPassword,
    String? authToken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$roomId/unlink-device'),
      headers: _buildHeaders(authToken ?? AuthService.currentToken),
      body: jsonEncode({'adminPassword': adminPassword}),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response, 'Falha ao desvincular dispositivo'));
    }
  }

  Future<RoomModel> resetRoomMetrics(
    String roomId, {
    required String adminPassword,
    String? authToken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$roomId/reset-metrics'),
      headers: _buildHeaders(authToken ?? AuthService.currentToken),
      body: jsonEncode({'adminPassword': adminPassword}),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response, 'Falha ao zerar contador da sala'));
    }
  }

  Future<void> resetAllMetrics({
    required String adminPassword,
    String? authToken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-metrics'),
      headers: _buildHeaders(authToken ?? AuthService.currentToken),
      body: jsonEncode({'adminPassword': adminPassword}),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, 'Falha ao zerar contadores'));
    }
  }

  Future<List<RoomModel>> updateBatchTemperature(
    double targetTemperature, {
    required String adminPassword,
    String? authToken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/batch-temperature'),
      headers: _buildHeaders(authToken ?? AuthService.currentToken),
      body: jsonEncode({
        'adminPassword': adminPassword,
        'targetTemperature': targetTemperature,
      }),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((item) => RoomModel.fromJson(item)).toList();
    } else {
      throw Exception(_extractErrorMessage(response, 'Falha ao atualizar temperaturas em lote'));
    }
  }

  /// Testa a conectividade com o backend e retorna a latência em milissegundos (ou null se offline).
  Future<int?> pingBackend() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: _buildHeaders(AuthService.currentToken),
      ).timeout(const Duration(seconds: 3));
      stopwatch.stop();
      if (response.statusCode == 200) {
        return stopwatch.elapsedMilliseconds;
      }
      return null;
    } catch (_) {
      stopwatch.stop();
      return null;
    }
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final err = jsonDecode(response.body);
      return err['message'] ?? fallback;
    } catch (_) {
      return '$fallback (${response.statusCode})';
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
