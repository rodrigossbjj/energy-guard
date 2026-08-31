import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/room_service.dart';
import 'room_form_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final RoomService _roomService = RoomService();
  late Future<List<RoomModel>> _roomsFuture;

  @override
  void initState() {
    super.initState();
    _refreshRooms();
  }

  void _refreshRooms() {
    setState(() {
      _roomsFuture = _roomService.getRooms();
    });
  }

  Future<void> _deleteRoom(RoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a sala "${room.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _roomService.deleteRoom(room.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sala excluída com sucesso!'), backgroundColor: Colors.green),
          );
          _refreshRooms();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _toggleAcStatus(RoomModel room) async {
    try {
      await _roomService.updateRoomStatus(room.id, acStatus: !room.acStatus);
      _refreshRooms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao alterar status do AC: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'OCCUPIED':
        return Colors.green;
      case 'ALERT_DESPERDICIO':
        return Colors.red;
      case 'EMPTY':
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'OCCUPIED':
        return 'Ocupada';
      case 'ALERT_DESPERDICIO':
        return 'Alerta de Desperdício!';
      case 'EMPTY':
      default:
        return 'Vazia';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salas Monitoradas - Energy Guard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRooms,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: FutureBuilder<List<RoomModel>>(
        future: _roomsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Erro ao carregar salas: ${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _refreshRooms, child: const Text('Tentar Novamente')),
                  ],
                ),
              ),
            );
          }

          final rooms = snapshot.data ?? [];
          if (rooms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nenhuma sala cadastrada.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Clique no botão "+" para cadastrar a primeira sala.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final statusColor = _getStatusColor(room.occupancyStatus);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              room.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(38),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              _getStatusText(room.occupancyStatus),
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (room.location != null && room.location!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(room.location!, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                room.acStatus ? Icons.ac_unit : Icons.power_off,
                                color: room.acStatus ? Colors.blue : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ar-Condicionado: ${room.acStatus ? "LIGADO" : "DESLIGADO"}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: room.acStatus ? Colors.blue : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: room.acStatus,
                            onChanged: (_) => _toggleAcStatus(room),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.thermostat, size: 18, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('Alvo: ${room.targetTemperature}°C'),
                          if (room.currentTemperature != null) ...[
                            const SizedBox(width: 16),
                            Text('Atual: ${room.currentTemperature}°C', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.indigo),
                            onPressed: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => RoomFormScreen(room: room)),
                              );
                              if (updated == true) _refreshRooms();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteRoom(room),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RoomFormScreen()),
          );
          if (created == true) _refreshRooms();
        },
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Sala'),
      ),
    );
  }
}
