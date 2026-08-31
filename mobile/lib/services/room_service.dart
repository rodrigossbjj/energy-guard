import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room_model.dart';

class RoomService {
  final String baseUrl;

  RoomService({this.baseUrl = 'http://localhost:8081/api/v1/rooms'});

  Future<List<RoomModel>> getRooms({String? authToken}) async {
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: _buildHeaders(authToken),
    );

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
      headers: _buildHeaders(authToken),
      body: jsonEncode(roomData),
    );

    if (response.statusCode == 201) {
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Falha ao criar sala');
    }
  }

  Future<RoomModel> updateRoom(String id, Map<String, dynamic> roomData, {String? authToken}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: _buildHeaders(authToken),
      body: jsonEncode(roomData),
    );

    if (response.statusCode == 200) {
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Falha ao atualizar sala');
    }
  }

  Future<void> deleteRoom(String id, {String? authToken}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: _buildHeaders(authToken),
    );

    if (response.statusCode != 204) {
      throw Exception('Falha ao deletar sala: ${response.statusCode}');
    }
  }

  Future<RoomModel> updateRoomStatus(String id, {bool? acStatus, String? occupancyStatus, double? targetTemperature, String? authToken}) async {
    final body = <String, dynamic>{};
    if (acStatus != null) body['acStatus'] = acStatus;
    if (occupancyStatus != null) body['occupancyStatus'] = occupancyStatus;
    if (targetTemperature != null) body['targetTemperature'] = targetTemperature;

    final response = await http.patch(
      Uri.parse('$baseUrl/$id/status'),
      headers: _buildHeaders(authToken),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return RoomModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao atualizar status da sala');
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
