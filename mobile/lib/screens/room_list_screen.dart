import 'dart:async';
import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/mock_storage.dart';
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
    // Auto-refresh a cada 4 segundos para manter os status sincronizados
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

  String _formatDuration(double minutes) {
    if (minutes <= 0) return '0 min';
    if (minutes < 1.0) {
      final secs = (minutes * 60).round();
      return '$secs s';
    }
    if (minutes < 60.0) {
      return '${minutes.toStringAsFixed(1)} min';
    }
    final hours = minutes ~/ 60;
    final rem = (minutes % 60).round();
    return '${hours}h ${rem}min';
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
            SnackBar(
              content: const Text('Sala excluída com sucesso!'),
              backgroundColor: Colors.teal.shade700,
              behavior: SnackBarBehavior.floating,
            ),
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
        return Colors.teal.shade700;
      case 'ALERT_DESPERDICIO':
        return Colors.orange.shade800;
      case 'EMPTY':
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'OCCUPIED':
        return 'Ocupada';
      case 'ALERT_DESPERDICIO':
        return 'Atenção: Sala Vazia';
      case 'EMPTY':
      default:
        return 'Vazia';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Salas Monitoradas'),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (MockStorage.isMockMode)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Colors.amberAccent),
                  SizedBox(width: 6),
                  Text(
                    'Simulado',
                    style: TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
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
                    const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.indigo),
                    const SizedBox(height: 16),
                    Text('Não foi possível carregar as salas:\n${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1B4B),
                        foregroundColor: Colors.white,
                      ),
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
                  Icon(Icons.meeting_room_outlined, size: 64, color: Colors.indigo),
                  SizedBox(height: 16),
                  Text('Nenhuma sala cadastrada ainda.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('Toque no botão "+" abaixo para cadastrar a primeira sala.', style: TextStyle(color: Colors.black54)),
                ],
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: RefreshIndicator(
                onRefresh: () async => _refreshRooms(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final statusColor = _getStatusColor(room.occupancyStatus);
                    final isWasting = room.occupancyStatus == 'ALERT_DESPERDICIO';

                    return Card(
                      color: Colors.white,
                      elevation: isWasting ? 3 : 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: isWasting
                            ? BorderSide(color: Colors.orange.shade400, width: 1.5)
                            : BorderSide(color: Colors.grey.shade200, width: 1),
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
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withAlpha(140)),
                                  ),
                                  child: Text(
                                    _getStatusText(room.occupancyStatus),
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                            if (room.deviceId != null && room.deviceId!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.developer_board, size: 15, color: Colors.indigo.shade400),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dispositivo: ${room.deviceId}',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 20),

                            // Estado do Ar-Condicionado
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: room.acStatus ? Colors.indigo.shade50 : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: room.acStatus ? Colors.indigo.shade100 : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        room.acStatus ? Icons.ac_unit : Icons.power_off_outlined,
                                        color: room.acStatus ? Colors.indigo.shade700 : Colors.grey.shade600,
                                        size: 21,
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
                                              color: room.acStatus ? Colors.indigo.shade900 : Colors.grey.shade700,
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
                                        color: Colors.orange.shade700,
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

                            // Métricas Reais: Temperatura de Referência e Tempo Ocioso Registrado
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.thermostat_outlined, size: 17, color: Colors.teal.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ref: ${room.targetTemperature.toStringAsFixed(1)}°C',
                                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.timer_outlined, size: 17, color: Colors.indigo.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ocioso total: ${_formatDuration(room.totalWastedMinutes)}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E1B4B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (room.lastAbsenceMinutes != null && room.lastAbsenceMinutes! > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Última ausência registrada: ${_formatDuration(room.lastAbsenceMinutes!)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
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
                                  icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
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
              ),
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
