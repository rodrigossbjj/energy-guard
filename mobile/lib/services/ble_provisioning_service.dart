import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Códigos de status Wi-Fi retornados pela característica GATT 0xFF04 do ESP32.
class EspWifiStatus {
  static const int waiting = 0;
  static const int connecting = 1;
  static const int success = 2;
  static const int error = 3;
}

class BleProvisioningSession {
  final BluetoothDevice device;
  final String deviceId;
  final BluetoothCharacteristic ssidCharacteristic;
  final BluetoothCharacteristic passwordCharacteristic;
  final BluetoothCharacteristic statusCharacteristic;

  BleProvisioningSession({
    required this.device,
    required this.deviceId,
    required this.ssidCharacteristic,
    required this.passwordCharacteristic,
    required this.statusCharacteristic,
  });
}

class BleProvisioningService {
  // UUIDs exatos definidos em firmware/main/ble_config_service.c
  static const String serviceShortUuid = 'ff00';
  static const String deviceIdShortUuid = 'ff01';
  static const String wifiSsidShortUuid = 'ff02';
  static const String wifiPassShortUuid = 'ff03';
  static const String wifiStatusShortUuid = 'ff04';

  static bool matchesShortUuid(Guid guid, String shortHex) {
    final target = shortHex.toLowerCase();
    if (guid == Guid(target)) return true;
    final normalized128 = guid.str128.toLowerCase().replaceAll('-', '');
    final normalizedStr = guid.str.toLowerCase().replaceAll('-', '');
    return normalizedStr == target ||
        normalized128 == target ||
        normalized128.startsWith('0000$target') ||
        normalizedStr.startsWith('0000$target');
  }

  static bool isEnergyGuardDevice(ScanResult result) {
    final advName = result.advertisementData.advName;
    final platformName = result.device.platformName;
    final hasName = advName.toLowerCase().contains('energy guard') ||
        platformName.toLowerCase().contains('energy guard') ||
        advName.toUpperCase().startsWith('EG-') ||
        platformName.toUpperCase().startsWith('EG-');

    final hasService = result.advertisementData.serviceUuids
        .any((uuid) => matchesShortUuid(uuid, serviceShortUuid));

    return hasName || hasService;
  }

  static String extractDeviceName(ScanResult result) {
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    return 'Dispositivo Energy Guard';
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    if (kIsWeb) {
      // Web Bluetooth exige declarar os serviços para exibir dispositivos no seletor do navegador
      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceShortUuid)],
        timeout: timeout,
      );
    } else {
      await FlutterBluePlus.startScan(timeout: timeout);
    }
  }

  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
  }

  Future<BleProvisioningSession> connectAndInspect(
    BluetoothDevice device, {
    String? fallbackDisplayName,
  }) async {
    await stopScan();

    await device.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 15),
      autoConnect: false,
    );

    // Pausa para estabilizar a conexão GATT e a negociação MTU com o NimBLE
    await Future.delayed(const Duration(milliseconds: 500));

    List<BluetoothService> services = await device.discoverServices();

    BluetoothService? findConfigService(List<BluetoothService> list) {
      for (final service in list) {
        if (matchesShortUuid(service.uuid, serviceShortUuid)) {
          return service;
        }
        // Fallback estrutural: verifica se o serviço contém as características 0xFF02 e 0xFF03
        final hasSsid = service.characteristics.any((c) => matchesShortUuid(c.uuid, wifiSsidShortUuid));
        final hasPass = service.characteristics.any((c) => matchesShortUuid(c.uuid, wifiPassShortUuid));
        if (hasSsid && hasPass) {
          return service;
        }
      }
      return null;
    }

    BluetoothService? configService = findConfigService(services);

    // Retry único caso a descoberta inicial retorne lista incompleta logo após conectar
    if (configService == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      services = await device.discoverServices();
      configService = findConfigService(services);
    }

    if (configService == null) {
      final foundUuids = services.isEmpty
          ? 'nenhum'
          : services.map((s) => s.uuid.str).join(', ');
      await safeDisconnect(device);
      throw Exception(
        'Serviço Energy Guard (0xFF00) não encontrado neste dispositivo. Serviços encontrados: [$foundUuids]',
      );
    }

    BluetoothCharacteristic? devIdChar;
    BluetoothCharacteristic? ssidChar;
    BluetoothCharacteristic? passChar;
    BluetoothCharacteristic? statusChar;

    for (final chr in configService.characteristics) {
      if (matchesShortUuid(chr.uuid, deviceIdShortUuid)) {
        devIdChar = chr;
      } else if (matchesShortUuid(chr.uuid, wifiSsidShortUuid)) {
        ssidChar = chr;
      } else if (matchesShortUuid(chr.uuid, wifiPassShortUuid)) {
        passChar = chr;
      } else if (matchesShortUuid(chr.uuid, wifiStatusShortUuid)) {
        statusChar = chr;
      }
    }

    if (ssidChar == null || passChar == null || statusChar == null) {
      await safeDisconnect(device);
      throw Exception('Serviço de configuração Wi-Fi incompleto no dispositivo.');
    }

    // Lê o Device ID curto direto da característica 0xFF01 (ex: EG-A4CF12)
    String deviceId = '';
    if (devIdChar != null) {
      try {
        final rawBytes = await devIdChar.read();
        deviceId = utf8.decode(rawBytes, allowMalformed: true).replaceAll('\x00', '').trim();
      } catch (_) {}
    }

    // Fallback: extrai "EG-XXXXXX" do nome anunciado ("Energy Guard - EG-XXXXXX")
    if (deviceId.isEmpty && fallbackDisplayName != null) {
      final match = RegExp(r'EG-[A-Za-z0-9]+').firstMatch(fallbackDisplayName);
      if (match != null) {
        deviceId = match.group(0)!;
      }
    }

    if (deviceId.isEmpty) {
      deviceId = device.remoteId.str;
    }

    // Ativa notificações de status (0xFF04) antes de enviar credenciais
    try {
      await statusChar.setNotifyValue(true);
    } catch (_) {}

    return BleProvisioningSession(
      device: device,
      deviceId: deviceId,
      ssidCharacteristic: ssidChar,
      passwordCharacteristic: passChar,
      statusCharacteristic: statusChar,
    );
  }

  /// Envia SSID (0xFF02) e depois Senha (0xFF03) — ordem exigida pelo firmware —
  /// e aguarda a confirmação real de conexão Wi-Fi pela característica 0xFF04.
  Future<int> sendWifiCredentials(
    BleProvisioningSession session, {
    required String ssid,
    required String password,
    void Function(int status)? onStatusUpdate,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final ssidBytes = utf8.encode(ssid);
    final passBytes = utf8.encode(password);

    if (ssidBytes.isEmpty || ssidBytes.length > 32) {
      throw Exception('O nome da rede (SSID) deve ter entre 1 e 32 bytes.');
    }
    if (passBytes.length > 64) {
      throw Exception('A senha do Wi-Fi deve ter no máximo 64 bytes.');
    }

    final completer = Completer<int>();
    StreamSubscription<List<int>>? notifySub;
    Timer? pollingTimer;
    Timer? timeoutTimer;

    void handleStatusBytes(List<int> value) {
      if (value.isEmpty || completer.isCompleted) return;
      final status = value.first;
      onStatusUpdate?.call(status);
      if (status == EspWifiStatus.success || status == EspWifiStatus.error) {
        completer.complete(status);
      }
    }

    notifySub = session.statusCharacteristic.onValueReceived.listen(handleStatusBytes);

    // Polling de segurança caso o dispositivo Android/iOS atrase a entrega do Notify BLE
    pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (completer.isCompleted) return;
      try {
        final value = await session.statusCharacteristic.read();
        handleStatusBytes(value);
      } catch (_) {}
    });

    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Tempo esgotado aguardando o dispositivo conectar ao Wi-Fi.'),
        );
      }
    });

    try {
      // 1. Escreve SSID (0xFF02)
      await session.ssidCharacteristic.write(ssidBytes, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 120));

      // 2. Escreve Senha (0xFF03) -> dispara s_credentials_cb no ESP32
      await session.passwordCharacteristic.write(passBytes, withoutResponse: false);

      return await completer.future;
    } finally {
      await notifySub.cancel();
      pollingTimer.cancel();
      timeoutTimer.cancel();
    }
  }

  Future<void> safeDisconnect(BluetoothDevice? device) async {
    if (device == null) return;
    try {
      await device.disconnect();
    } catch (_) {}
  }
}
