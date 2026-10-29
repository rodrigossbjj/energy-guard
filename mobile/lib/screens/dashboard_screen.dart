import 'dart:async';
import 'package:flutter/material.dart';
import '../models/dashboard_summary_model.dart';
import '../models/room_model.dart';
import '../services/dashboard_service.dart';
import '../services/room_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  final RoomService _roomService = RoomService();

  late Future<DashboardSummaryModel> _summaryFuture;
  Timer? _pollingTimer;
  final Set<String> _turningOffRooms = {};

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
    // Auto-refresh a cada 4 segundos para refletir os sensores em tempo real
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _summaryFuture = _dashboardService.getSummary();
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _refreshDashboard() {
    setState(() {
      _summaryFuture = _dashboardService.getSummary();
    });
  }

  Future<void> _turnOffAcForRoom(RoomModel room) async {
    setState(() {
      _turningOffRooms.add(room.id);
    });

    try {
      await _roomService.updateRoomStatus(room.id, acStatus: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Ar-condicionado da sala "${room.name}" desligado com sucesso!'),
              ],
            ),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refreshDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desligar o ar-condicionado: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _turningOffRooms.remove(room.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text('Energy Guard'),
          ],
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent),
                SizedBox(width: 6),
                Text('Ao Vivo', style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
            tooltip: 'Atualizar agora',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshDashboard(),
        child: FutureBuilder<DashboardSummaryModel>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.amber),
                      const SizedBox(height: 16),
                      Text(
                        'Erro ao conectar com a API:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        onPressed: _refreshDashboard,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final summary = snapshot.data!;
            final hasWastedEnergy = summary.wastingAcCount > 0;

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // BANNER DINÂMICO DE ALERTA DE DESPERDÍCIO DE AR-CONDICIONADO
                if (hasWastedEnergy)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB91C1C), Color(0xFF991B1B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withAlpha(70),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Desperdício de Ar-Condicionado!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${summary.wastingAcCount} ${summary.wastingAcCount == 1 ? 'sala está vazia com ar ligado' : 'salas estão vazias com ar ligado'}.',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(50),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Custo Estimado Perdido', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  Text(
                                    'R\$ ${summary.estimatedCostPerHour.toStringAsFixed(2)} /h',
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Potência em Ociosidade', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  Text(
                                    '${summary.estimatedWastedKwhPerHour.toStringAsFixed(2)} kWh/h',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: const Color(0xFF065F46),
                    child: const Padding(
                      padding: EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          Icon(Icons.energy_savings_leaf, color: Colors.tealAccent, size: 32),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Operação Eficiente',
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Nenhum ar-condicionado operando sem pessoas presentes no momento.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                const Text(
                  'Indicadores do Sistema',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 10),

                // Grid de KPI Cards com Foco no Ar-Condicionado
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _buildKpiCard(
                      title: 'Salas com Alerta',
                      value: summary.roomsInAlert.toString(),
                      icon: Icons.error_outline,
                      color: summary.roomsInAlert > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                      subtitle: 'Desperdício ativo',
                    ),
                    _buildKpiCard(
                      title: 'Ar Ligado Sem Pessoas',
                      value: summary.wastingAcCount.toString(),
                      icon: Icons.ac_unit,
                      color: summary.wastingAcCount > 0 ? Colors.orange.shade800 : Colors.grey.shade600,
                      subtitle: 'Desligamento indicado',
                    ),
                    _buildKpiCard(
                      title: 'Salas Ocupadas',
                      value: '${summary.roomsOccupied} / ${summary.totalRooms}',
                      icon: Icons.people_alt_outlined,
                      color: Colors.green.shade700,
                      subtitle: '${summary.roomsEmpty} vazias',
                    ),
                    _buildKpiCard(
                      title: 'Total de Ar Ligado',
                      value: summary.acOnCount.toString(),
                      icon: Icons.power_outlined,
                      color: Colors.indigo.shade700,
                      subtitle: 'Aparelhos ativos',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Seção de Salas com Ar-Condicionado em Desperdício
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Salas em Desperdício de Ar',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: summary.alertRooms.isNotEmpty ? Colors.red.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${summary.alertRooms.length} ${summary.alertRooms.length == 1 ? 'sala' : 'salas'}',
                        style: TextStyle(
                          color: summary.alertRooms.isNotEmpty ? Colors.red.shade900 : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (summary.alertRooms.isEmpty)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Nenhuma sala precisando de intervenção remota no momento.',
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...summary.alertRooms.map((room) {
                    final isBusy = _turningOffRooms.contains(room.id);

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.red.shade300, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.red.shade100,
                              radius: 22,
                              child: Icon(Icons.ac_unit, color: Colors.red.shade800, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${room.location ?? "Geral"} • Sala VAZIA',
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Temp: ${room.currentTemperature?.toStringAsFixed(1) ?? room.targetTemperature.toStringAsFixed(1)}°C',
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: isBusy ? null : () => _turnOffAcForRoom(room),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: isBusy
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.power_settings_new, size: 16),
                              label: const Text('Desligar Ar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
