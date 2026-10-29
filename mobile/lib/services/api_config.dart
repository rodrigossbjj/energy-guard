class ApiConfig {
  // IP padrão configurável. Altere aqui para o IP da sua máquina na rede local
  // ao testar em dispositivo físico (ex: '192.168.1.50'), ou use '10.0.2.2' para emulador Android.
  static String host = 'localhost';
  static int backendPort = 8081;
  static int keycloakPort = 8080;

  // Keycloak OIDC Config
  static String realm = 'energy-guard';
  static String clientId = 'energy-guard-app';

  // URLs Dinâmicas
  static String get backendBaseUrl => 'http://$host:$backendPort/api/v1';
  static String get roomsUrl => '$backendBaseUrl/rooms';
  static String get dashboardUrl => '$backendBaseUrl/dashboard/summary';
  static String get telemetryUrl => '$backendBaseUrl/telemetry';

  // Keycloak Direct Access Grant Token Endpoint (Resource Owner Password Credentials)
  static String get keycloakTokenUrl =>
      'http://$host:$keycloakPort/realms/$realm/protocol/openid-connect/token';

  /// Atualiza o host dinamicamente (ex: se o usuário configurar na tela de login)
  static void updateHost(String newHost) {
    if (newHost.trim().isNotEmpty) {
      host = newHost.trim().replaceAll('http://', '').replaceAll('https://', '').split(':').first;
    }
  }
}

