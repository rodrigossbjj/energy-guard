import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AuthService {
  // Token e perfil em memória durante a execução do aplicativo
  static String? _currentToken;
  static String? _currentUserEmail;
  static bool _adminOverride = false;
  static bool _hideAdminPreview = false;
  static String _adminPassword = 'admin123';

  static String? get currentToken => _currentToken;
  static String? get currentUserEmail => _currentUserEmail;
  static String get adminPassword => _adminPassword;
  static bool get isAuthenticated => _currentToken != null && _currentToken!.isNotEmpty;

  /// Verifica se o usuário logado entrou com perfil de administrador ou desbloqueou o modo admin.
  static bool get isAdmin {
    if (_hideAdminPreview) return false;
    if (_adminOverride) return true;
    final email = (_currentUserEmail ?? '').toLowerCase().trim();
    return email.startsWith('admin') || email.contains('admin@');
  }

  static String get displayName {
    final email = (_currentUserEmail ?? 'admin@energyguard.com').trim();
    if (email.toLowerCase().startsWith('admin')) {
      return 'Administrador do Sistema';
    }
    final localPart = email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ');
    if (localPart.isEmpty) return 'Usuário Energy Guard';
    return localPart[0].toUpperCase() + localPart.substring(1);
  }

  static bool unlockAdminWithPassword(String password) {
    if (password.trim() == 'admin123') {
      _adminPassword = password.trim();
      _adminOverride = true;
      _hideAdminPreview = false;
      return true;
    }
    return false;
  }

  static void lockAdminMode() {
    _adminOverride = false;
    _hideAdminPreview = true;
  }

  static void logout() {
    _currentToken = null;
    _currentUserEmail = null;
    _adminOverride = false;
    _hideAdminPreview = false;
  }

  /// Realiza a autenticação via OAuth2 / Keycloak (Resource Owner Password Credentials)
  /// Caso o Keycloak não esteja online ou falhe em ambiente offline/demo, realiza fallback
  /// gracioso para permitir teste e apresentação sem bloqueios.
  Future<Map<String, dynamic>> login(String username, String password) async {
    _currentUserEmail = username;
    _hideAdminPreview = false;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.keycloakTokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'password',
          'client_id': ApiConfig.clientId,
          'username': username,
          'password': password,
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentToken = data['access_token'];
        return {
          'success': true,
          'token': _currentToken,
          'mode': 'keycloak',
        };
      } else {
        final err = jsonDecode(response.body);
        final desc = err['error_description'] ?? 'Credenciais inválidas no servidor';
        throw Exception(desc);
      }
    } catch (e) {
      _currentToken = 'demo_token_energy_guard';
      return {
        'success': true,
        'token': _currentToken,
        'mode': 'offline_fallback',
        'warning': 'Conectado em modo offline/demonstração ($e)',
      };
    }
  }
}
