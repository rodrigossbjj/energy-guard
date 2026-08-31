import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/room_service.dart';

class RoomFormScreen extends StatefulWidget {
  final RoomModel? room;

  const RoomFormScreen({super.key, this.room});

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _targetTempController = TextEditingController(text: '23.0');

  final RoomService _roomService = RoomService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.room != null) {
      _nameController.text = widget.room!.name;
      _locationController.text = widget.room!.location ?? '';
      _capacityController.text = widget.room!.capacity?.toString() ?? '';
      _deviceIdController.text = widget.room!.deviceId ?? '';
      _targetTempController.text = widget.room!.targetTemperature.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _deviceIdController.dispose();
    _targetTempController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final roomData = {
      'name': _nameController.text.trim(),
      'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      'capacity': _capacityController.text.trim().isEmpty ? null : int.parse(_capacityController.text.trim()),
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
            content: Text(widget.room == null ? 'Sala criada com sucesso!' : 'Sala atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
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
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Sala' : 'Nova Sala'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Sala *',
                  hintText: 'Ex: Sala 101, Lab de Micro',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.room),
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
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Localização / Bloco',
                  hintText: 'Ex: Bloco A - 2º Andar',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacidade (Pessoas)',
                  hintText: 'Ex: 30',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    final num = int.tryParse(val);
                    if (num == null || num < 1) {
                      return 'A capacidade deve ser maior que 0';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'ID do Dispositivo ESP32',
                  hintText: 'Ex: ESP32-ROOM-101',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.developer_board),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetTempController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Temperatura Alvo (°C)',
                  hintText: 'Ex: 23.0',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.thermostat),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(
                  isEditing ? 'Salvar Alterações' : 'Cadastrar Sala',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
