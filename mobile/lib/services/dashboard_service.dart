import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dashboard_summary_model.dart';
import 'api_config.dart';
import 'auth_service.dart';

class DashboardService {
  String get baseUrl => ApiConfig.dashboardUrl;

  Future<DashboardSummaryModel> getSummary({String? authToken}) async {
    final token = authToken ?? AuthService.currentToken;
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(Uri.parse(baseUrl), headers: headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return DashboardSummaryModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao carregar métricas do dashboard: ${response.statusCode}');
    }
  }
}
