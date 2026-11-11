import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/room_service.dart';

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
  final _deviceIdController = TextEditingController();
  final _targetTempController = TextEditingController(text: '23.0');

  final RoomService _roomService = RoomService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.room != null) {
      _nameController.text = widget.room!.name;
      _deviceIdController.text = widget.room!.deviceId ?? '';
      _targetTempController.text = widget.room!.targetTemperature.toString();
    } else if (widget.initialDeviceId != null && widget.initialDeviceId!.isNotEmpty) {
      _deviceIdController.text = widget.initialDeviceId!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deviceIdController.dispose();
    _targetTempController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final roomData = {
      'name': _nameController.text.trim(),
      'deviceId': _deviceIdController.text.trim().isEmpty ? null : _deviceIdController.text.trim(),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Sala' : 'Nova Sala'),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.indigo.shade700),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Vincule o ID do seu ESP32 (ex: EG-A4CF12) para receber alertas automáticos desta sala.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF1E1B4B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                controller: _deviceIdController,
                decoration: InputDecoration(
                  labelText: 'ID do Dispositivo ESP32',
                  hintText: 'Ex: EG-A4CF12',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: const Icon(Icons.developer_board, color: Colors.indigo),
                ),
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
    );
  }
}
