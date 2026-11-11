import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/room_service.dart';
import '../widgets/ble_wifi_config_modal.dart';

class RoomFormScreen extends StatefulWidget {
  final RoomModel? room;
  final String? initialDeviceId;

  const RoomFormScreen({super.key, this.room, this.initialDeviceId});

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetTempController = TextEditingController(text: '23.0');

  final RoomService _roomService = RoomService();
  bool _isLoading = false;
  bool _missingDeviceError = false;
  String? _configuredDeviceId;

  @override
  void initState() {
    super.initState();
    if (widget.room != null) {
      _nameController.text = widget.room!.name;
      _configuredDeviceId = widget.room!.deviceId;
      _targetTempController.text = widget.room!.targetTemperature.toString();
    } else if (widget.initialDeviceId != null && widget.initialDeviceId!.isNotEmpty) {
      _configuredDeviceId = widget.initialDeviceId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetTempController.dispose();
    super.dispose();
  }

  Future<void> _openBleConfigModal() async {
    final deviceId = await BleWifiConfigModal.show(context);
    if (deviceId != null && deviceId.isNotEmpty && mounted) {
      setState(() {
        _configuredDeviceId = deviceId;
        _missingDeviceError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispositivo "$deviceId" pronto e vinculado! Agora salve a sala.'),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    final isFormValid = _formKey.currentState!.validate();
    final isCreating = widget.room == null;

    if (isCreating && (_configuredDeviceId == null || _configuredDeviceId!.isEmpty)) {
      setState(() => _missingDeviceError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Conecte e configure o Wi-Fi do dispositivo via Bluetooth antes de salvar a sala.'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!isFormValid) return;

    setState(() => _isLoading = true);

    final roomData = {
      'name': _nameController.text.trim(),
      'deviceId': (_configuredDeviceId == null || _configuredDeviceId!.trim().isEmpty)
          ? null
          : _configuredDeviceId!.trim(),
      'targetTemperature': double.tryParse(_targetTempController.text.trim()) ?? 23.0,
    };

    try {
      if (widget.room == null) {
        await _roomService.createRoom(roomData);
      } else {
        await _roomService.updateRoom(widget.room!.id, roomData);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.room == null ? 'Sala cadastrada com sucesso!' : 'Sala atualizada com sucesso!'),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.room != null;
    final hasDevice = _configuredDeviceId != null && _configuredDeviceId!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Sala' : 'Nova Sala'),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nome da Sala *',
                      hintText: 'Ex: Sala 101, Lab. de Microcontroladores',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: const Icon(Icons.meeting_room_outlined, color: Colors.indigo),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Informe o nome da sala';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _targetTempController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Temperatura de Referência (°C)',
                      hintText: 'Ex: 23.0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: const Icon(Icons.thermostat_outlined, color: Colors.indigo),
                    ),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final temp = double.tryParse(val.trim());
                        if (temp == null || temp < 10 || temp > 40) {
                          return 'Informe uma temperatura válida (10°C a 40°C)';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // SEÇÃO DE CONFIGURAÇÃO DO DISPOSITIVO VIA BLUETOOTH (BLE)
                  const Text(
                    'Dispositivo da Sala *',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _openBleConfigModal,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hasDevice
                            ? Colors.teal.shade50
                            : (_missingDeviceError ? Colors.red.shade50 : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hasDevice
                              ? Colors.teal.shade300
                              : (_missingDeviceError ? Colors.red.shade400 : Colors.indigo.shade200),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: hasDevice ? Colors.teal.shade100 : Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  hasDevice ? Icons.check_circle_outline : Icons.bluetooth_searching,
                                  color: hasDevice ? Colors.teal.shade800 : const Color(0xFF1E1B4B),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasDevice
                                          ? 'Dispositivo Configurado e Vinculado'
                                          : 'Conectar Dispositivo e Configurar Wi-Fi',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                        color: hasDevice ? Colors.teal.shade900 : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      hasDevice
                                          ? 'ID do Dispositivo: $_configuredDeviceId'
                                          : 'Toque aqui para parear via Bluetooth e enviar a rede Wi-Fi.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: hasDevice ? Colors.teal.shade800 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _openBleConfigModal,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: hasDevice ? Colors.teal.shade800 : const Color(0xFF1E1B4B),
                              side: BorderSide(
                                color: hasDevice ? Colors.teal.shade400 : const Color(0xFF1E1B4B),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.bluetooth, size: 18),
                            label: Text(
                              hasDevice ? 'Reconfigurar Wi-Fi / Trocar Dispositivo' : 'Abrir Assistente Bluetooth',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_missingDeviceError && !hasDevice) ...[
                    const SizedBox(height: 6),
                    Text(
                      'É obrigatório parear e configurar o Wi-Fi do dispositivo para vincular a esta sala.',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF1E1B4B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      isEditing ? 'Salvar Alterações' : 'Cadastrar Sala',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
