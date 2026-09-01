import 'package:flutter/material.dart';
import '../models/dashboard_summary_model.dart';
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

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  void _refreshDashboard() {
    setState(() {
      _summaryFuture = _dashboardService.getSummary();
    });
  }

  Future<void> _turnOffAcForRoom(String roomId) async {
    try {
      await _roomService.updateRoomStatus(roomId, acStatus: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ar-condicionado desligado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desligar ar-condicionado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Energy Guard - Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshDashboard(),
        child: FutureBuilder<DashboardSummaryModel>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.amber),
                      const SizedBox(height: 16),
                      Text(
                        'Erro ao carregar indicador de energia:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
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
                // Banner Resumo de Desperdício Financeiro
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: hasWastedEnergy ? Colors.red[800] : Colors.green[700],
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasWastedEnergy ? Icons.trending_up : Icons.check_circle_outline,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              hasWastedEnergy ? 'Desperdício de Energia Detectado' : 'Consumo Eficiente',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Custo Estimado',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'R\$ ${summary.estimatedCostPerHour.toStringAsFixed(2)} /h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.white30,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Potência Desperdiçada',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${summary.estimatedWastedKwhPerHour.toStringAsFixed(2)} kWh/h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Visão Geral do Monitoramento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),

                // Grid de KPI Cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _buildKpiCard(
                      title: 'Salas em Alerta',
                      value: summary.roomsInAlert.toString(),
                      icon: Icons.error_outline,
                      color: summary.roomsInAlert > 0 ? Colors.red : Colors.grey,
                      subtitle: 'Desperdício ativo',
                    ),
                    _buildKpiCard(
                      title: 'ACs Ligados Sem Uso',
                      value: summary.wastingAcCount.toString(),
                      icon: Icons.power_off_outlined,
                      color: summary.wastingAcCount > 0 ? Colors.orange : Colors.grey,
                      subtitle: 'Ar em sala vazia',
                    ),
                    _buildKpiCard(
                      title: 'Salas Ocupadas',
                      value: '${summary.roomsOccupied} / ${summary.totalRooms}',
                      icon: Icons.people_alt_outlined,
                      color: Colors.green,
                      subtitle: '${summary.roomsEmpty} vazias',
                    ),
                    _buildKpiCard(
                      title: 'Total de ACs Ligados',
                      value: summary.acOnCount.toString(),
                      icon: Icons.ac_unit,
                      color: Colors.blue,
                      subtitle: 'Dispositivos ativos',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Seção de Salas em Alerta
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Alertas que Exigem Atenção',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Chip(
                      label: Text('${summary.alertRooms.length}'),
                      backgroundColor: summary.alertRooms.isNotEmpty ? Colors.red[100] : Colors.grey[200],
                      labelStyle: TextStyle(
                        color: summary.alertRooms.isNotEmpty ? Colors.red[900] : Colors.grey[700],
                        fontWeight: FontWeight.bold,
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
                          Icon(Icons.thumb_up_alt_outlined, color: Colors.green, size: 28),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Nenhum alerta pendente no momento! Todas as salas estão economizando energia.',
                              style: TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...summary.alertRooms.map((room) => Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.redAccent, width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            child: Icon(Icons.warning, color: Colors.white),
                          ),
                          title: Text(
                            room.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            'Local: ${room.location ?? "N/A"} • Temp: ${room.currentTemperature ?? room.targetTemperature}°C',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: () => _turnOffAcForRoom(room.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.power_settings_new, size: 18),
                            label: const Text('Desligar AC'),
                          ),
                        ),
                      )),
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
