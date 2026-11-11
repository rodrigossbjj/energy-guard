import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dashboard_summary_model.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'mock_storage.dart';

class DashboardService {
  String get baseUrl => ApiConfig.dashboardUrl;

  Future<DashboardSummaryModel> getSummary({String? authToken}) async {
    final token = authToken ?? AuthService.currentToken;
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http
          .get(Uri.parse(baseUrl), headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        MockStorage.isMockMode = false;
        return DashboardSummaryModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Falha ao carregar métricas do dashboard: ${response.statusCode}');
      }
    } catch (_) {
      // Fallback gracioso para modo mock/demonstração quando o backend não estiver rodando
      MockStorage.isMockMode = true;
      return MockStorage.getSummary();
    }
  }
}
