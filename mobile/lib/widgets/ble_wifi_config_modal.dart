import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_provisioning_service.dart';

enum _BleStep { scan, wifiForm, success }

class BleWifiConfigModal extends StatefulWidget {
  const BleWifiConfigModal({super.key});

  /// Abre o modal e retorna o `deviceId` (ex: `EG-A4CF12`) após confirmar a conexão Wi-Fi.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BleWifiConfigModal(),
    );
  }

  @override
  State<BleWifiConfigModal> createState() => _BleWifiConfigModalState();
}

class _BleWifiConfigModalState extends State<BleWifiConfigModal> {
  final BleProvisioningService _bleService = BleProvisioningService();
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  _BleStep _step = _BleStep.scan;
  bool _isScanning = false;
  bool _isConnectingDevice = false;
  bool _isSendingWifi = false;
  bool _obscurePassword = true;
  bool _isSimulatedSession = false;

  String? _statusMessage;
  String? _errorMessage;
  String? _connectedDeviceId;
  BleProvisioningSession? _session;

  final List<ScanResult> _foundDevices = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;

  @override
  void initState() {
    super.initState();
    _initBleListeners();
  }

  void _initBleListeners() {
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      final filtered = results.where(BleProvisioningService.isEnergyGuardDevice).toList();
      setState(() {
        _foundDevices
          ..clear()
          ..addAll(filtered);
      });
    });

    _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      setState(() {
        _isScanning = scanning;
      });
    });

    if (!kIsWeb) {
      _startScan();
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _bleService.stopScan();
    _bleService.safeDisconnect(_session?.device);
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _errorMessage = null;
      _foundDevices.clear();
    });

    try {
      if (!kIsWeb) {
        final adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState != BluetoothAdapterState.on) {
          setState(() {
            _errorMessage = 'O Bluetooth está desligado. Ative-o para buscar o dispositivo.';
          });
          return;
        }
      }

      await _bleService.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível iniciar a busca Bluetooth: $e';
      });
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    setState(() {
      _isConnectingDevice = true;
      _errorMessage = null;
      _statusMessage = 'Conectando ao dispositivo via Bluetooth...';
    });

    try {
      final displayName = BleProvisioningService.extractDeviceName(result);
      final session = await _bleService.connectAndInspect(
        result.device,
        fallbackDisplayName: displayName,
      );

      if (!mounted) return;
      setState(() {
        _session = session;
        _connectedDeviceId = session.deviceId;
        _isSimulatedSession = false;
        _isConnectingDevice = false;
        _statusMessage = null;
        _step = _BleStep.wifiForm;
      });
    } catch (e) {
      if (!mounted) return;
      final cleanError = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isConnectingDevice = false;
        _statusMessage = null;
        _errorMessage = 'Falha ao conectar no dispositivo: $cleanError';
      });
    }
  }

  void _startSimulatedPairing() {
    _bleService.stopScan();
    setState(() {
      _errorMessage = null;
      _isSimulatedSession = true;
      _connectedDeviceId = 'EG-SIM101';
      _step = _BleStep.wifiForm;
    });
  }

  Future<void> _sendWifiCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSendingWifi = true;
      _errorMessage = null;
      _statusMessage = 'Enviando rede e senha para o dispositivo...';
    });

    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    if (_isSimulatedSession) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _statusMessage = 'Dispositivo conectando ao Wi-Fi "$ssid"...');
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      setState(() {
        _isSendingWifi = false;
        _statusMessage = null;
        _step = _BleStep.success;
      });
      return;
    }

    if (_session == null) return;

    try {
      final resultStatus = await _bleService.sendWifiCredentials(
        _session!,
        ssid: ssid,
        password: password,
        onStatusUpdate: (status) {
          if (!mounted) return;
          if (status == EspWifiStatus.connecting) {
            setState(() {
              _statusMessage = 'Dispositivo tentando conectar à rede "$ssid"...';
            });
          }
        },
      );

      if (!mounted) return;

      if (resultStatus == EspWifiStatus.success) {
        await _bleService.safeDisconnect(_session?.device);
        setState(() {
          _isSendingWifi = false;
          _statusMessage = null;
          _step = _BleStep.success;
        });
      } else {
        setState(() {
          _isSendingWifi = false;
          _statusMessage = null;
          _errorMessage =
              'O dispositivo não conseguiu conectar ao Wi-Fi "$ssid". Verifique o nome da rede e a senha e tente novamente.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingWifi = false;
        _statusMessage = null;
        _errorMessage = 'Erro durante a configuração Wi-Fi: $e';
      });
    }
  }

  Future<void> _handleBackToScan() async {
    await _bleService.safeDisconnect(_session?.device);
    if (!mounted) return;
    setState(() {
      _session = null;
      _connectedDeviceId = null;
      _isSimulatedSession = false;
      _errorMessage = null;
      _statusMessage = null;
      _step = _BleStep.scan;
    });
    if (!kIsWeb) {
      _startScan();
    }
  }

  Future<void> _handleClose() async {
    await _bleService.stopScan();
    await _bleService.safeDisconnect(_session?.device);
    if (mounted) {
      Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho do Modal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bluetooth, color: Color(0xFF1E1B4B), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Configurar Dispositivo',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  if (!_isSendingWifi && !_isConnectingDevice)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: _handleClose,
                      tooltip: 'Fechar',
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_step == _BleStep.scan) _buildScanStep(),
              if (_step == _BleStep.wifiForm) _buildWifiFormStep(),
              if (_step == _BleStep.success) _buildSuccessStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.touch_app_outlined, color: Colors.indigo.shade700, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pressione o botão de configuração no dispositivo até a luz verde piscar e toque em Buscar.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1E1B4B)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_errorMessage != null) ...[
          _buildErrorBox(_errorMessage!),
          const SizedBox(height: 12),
        ],
        if (_isConnectingDevice)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                const CircularProgressIndicator(color: Color(0xFF1E1B4B)),
                const SizedBox(height: 14),
                Text(
                  _statusMessage ?? 'Conectando ao dispositivo...',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _isScanning ? 'Buscando dispositivos...' : 'Dispositivos encontrados',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_isScanning ? 'Buscando' : 'Buscar'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_foundDevices.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.bluetooth_searching, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    _isScanning
                        ? 'Procurando dispositivos Energy Guard...'
                        : 'Nenhum dispositivo encontrado ainda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _foundDevices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final result = _foundDevices[index];
                  final name = BleProvisioningService.extractDeviceName(result);
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _connectToDevice(result),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.indigo.shade50,
                            child: const Icon(Icons.developer_board, color: Color(0xFF1E1B4B), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Sinal: ${result.rssi} dBm',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.indigo),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _startSimulatedPairing,
            icon: const Icon(Icons.science_outlined, size: 16),
            label: const Text(
              'Simular pareamento (para testes sem dispositivo)',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWifiFormStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.bluetooth_connected, color: Colors.teal.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dispositivo conectado: $_connectedDeviceId${_isSimulatedSession ? ' (Simulado)' : ''}',
                    style: TextStyle(
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!_isSendingWifi)
                  TextButton(
                    onPressed: _handleBackToScan,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Trocar', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ssidController,
            enabled: !_isSendingWifi,
            decoration: InputDecoration(
              labelText: 'Nome da Rede Wi-Fi (SSID) *',
              hintText: 'Ex: IFCE_Lab',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: const Icon(Icons.wifi, color: Colors.indigo),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Informe o nome da rede Wi-Fi';
              }
              if (utf8.encode(val.trim()).length > 32) {
                return 'Nome da rede excede o limite de 32 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            enabled: !_isSendingWifi,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Senha do Wi-Fi',
              hintText: 'Deixe vazio se a rede for aberta',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.indigo),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (val) {
              if (val != null && utf8.encode(val).length > 64) {
                return 'Senha excede o limite de 64 caracteres';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorBox(_errorMessage!),
          ],
          if (_statusMessage != null && _isSendingWifi) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E1B4B)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E1B4B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _isSendingWifi ? null : _sendWifiCredentials,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1B4B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isSendingWifi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(
              _isSendingWifi ? 'Conectando...' : 'Conectar Dispositivo ao Wi-Fi',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.teal.shade600, size: 48),
              const SizedBox(height: 12),
              Text(
                'Wi-Fi configurado com sucesso!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'O dispositivo ($_connectedDeviceId) conectou-se à rede "${_ssidController.text.trim()}" com sucesso.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, _connectedDeviceId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.link),
          label: Text(
            'Vincular $_connectedDeviceId à Sala',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade900, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

