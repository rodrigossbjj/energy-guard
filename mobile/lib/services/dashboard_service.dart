import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dashboard_summary_model.dart';

class DashboardService {
  final String baseUrl;

  DashboardService({this.baseUrl = 'http://localhost:8081/api/v1/dashboard/summary'});

  Future<DashboardSummaryModel> getSummary({String? authToken}) async {
    final headers = {'Content-Type': 'application/json'};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final response = await http.get(Uri.parse(baseUrl), headers: headers);

    if (response.statusCode == 200) {
      return DashboardSummaryModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao carregar métricas do dashboard: ${response.statusCode}');
    }
  }
}
