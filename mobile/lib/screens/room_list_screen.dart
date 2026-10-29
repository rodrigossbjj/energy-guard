import 'dart:async';
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
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _refreshRooms();
    // Auto-refresh a cada 4 segundos para manter os status e temperaturas sincronizados
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _roomsFuture = _roomService.getRooms();
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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
        return 'Desperdício Detectado!';
      case 'EMPTY':
      default:
        return 'Vazia';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Monitoramento de Salas'),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRooms,
            tooltip: 'Atualizar agora',
          ),
        ],
      ),
      body: FutureBuilder<List<RoomModel>>(
        future: _roomsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: _refreshRooms,
                      child: const Text('Tentar Novamente'),
                    ),
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
                  Text('Clique no botão "+" abaixo para cadastrar a primeira sala.'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshRooms(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                final statusColor = _getStatusColor(room.occupancyStatus);
                final isWasting = room.occupancyStatus == 'ALERT_DESPERDICIO';

                return Card(
                  elevation: isWasting ? 4 : 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: isWasting
                        ? BorderSide(color: Colors.red.shade400, width: 2)
                        : BorderSide.none,
                  ),
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
                        const Divider(height: 22),
                        
                        // Estado do Ar-Condicionado (Apenas Leitura / Status)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: room.acStatus ? Colors.blue.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: room.acStatus ? Colors.blue.shade200 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    room.acStatus ? Icons.ac_unit : Icons.power_off,
                                    color: room.acStatus ? Colors.blue.shade700 : Colors.grey.shade600,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ar-Condicionado',
                                        style: TextStyle(fontSize: 11, color: Colors.black54),
                                      ),
                                      Text(
                                        room.acStatus ? 'EM FUNCIONAMENTO' : 'DESLIGADO',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: room.acStatus ? Colors.blue.shade900 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (isWasting)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'OCIOSO',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.thermostat, size: 18, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text('Alvo: ${room.targetTemperature.toStringAsFixed(1)}°C'),
                            if (room.currentTemperature != null) ...[
                              const SizedBox(width: 16),
                              Text(
                                'Atual: ${room.currentTemperature!.toStringAsFixed(1)}°C',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.indigo),
                              tooltip: 'Editar sala',
                              onPressed: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => RoomFormScreen(room: room)),
                                );
                                if (result == true) {
                                  _refreshRooms();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Excluir sala',
                              onPressed: () => _deleteRoom(room),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const RoomFormScreen()),
          );
          if (result == true) {
            _refreshRooms();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
