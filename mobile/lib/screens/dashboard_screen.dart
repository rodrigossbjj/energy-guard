import 'dart:async';
import 'package:flutter/material.dart';
import '../models/dashboard_summary_model.dart';
import '../services/dashboard_service.dart';
import '../services/mock_storage.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  late Future<DashboardSummaryModel> _summaryFuture;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.shield,
                    color: Colors.tealAccent,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Energy Guard', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: MockStorage.isMockMode ? Colors.amber.withAlpha(45) : Colors.tealAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MockStorage.isMockMode ? Colors.amberAccent : Colors.tealAccent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 3.5,
                  backgroundColor: MockStorage.isMockMode ? Colors.amberAccent : Colors.tealAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  MockStorage.isMockMode ? 'Simulado' : 'Ao Vivo',
                  style: TextStyle(
                    fontSize: 11,
                    color: MockStorage.isMockMode ? Colors.amberAccent : Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                      const Icon(Icons.cloud_off_outlined, size: 52, color: Colors.indigo),
                      const SizedBox(height: 12),
                      Text(
                        'Não foi possível conectar ao servidor:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1B4B),
                          foregroundColor: Colors.white,
                        ),
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

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  children: [
                    if (MockStorage.isMockMode)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade900, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Modo Simulação Ativo (Servidor offline). Dados de demonstração.',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // BANNER COMPACTO E POSITIVO DE STATUS
                    _buildStatusBanner(summary, hasWastedEnergy),

                    const SizedBox(height: 16),

                    const Text(
                      'Resumo do Monitoramento',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // METRICS RESPONSIVAS E COMPACTAS (SEM QUADRADOS GIGANTES)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 600;
                        final cards = [
                          _buildCompactMetricTile(
                            title: 'Salas Ocupadas',
                            value: '${summary.roomsOccupied}/${summary.totalRooms}',
                            subtitle: '${summary.roomsEmpty} vazias',
                            icon: Icons.people_alt_outlined,
                            color: Colors.teal.shade700,
                            bgColor: Colors.teal.shade50,
                          ),
                          _buildCompactMetricTile(
                            title: 'Atenção Ativa',
                            value: '${summary.roomsInAlert}',
                            subtitle: summary.roomsInAlert > 0 ? 'Ar em sala vazia' : 'Tudo certo',
                            icon: Icons.notifications_none_rounded,
                            color: summary.roomsInAlert > 0 ? Colors.orange.shade800 : Colors.teal.shade600,
                            bgColor: summary.roomsInAlert > 0 ? Colors.orange.shade50 : Colors.teal.shade50,
                          ),
                          _buildCompactMetricTile(
                            title: 'Ar Ligado',
                            value: '${summary.acOnCount}',
                            subtitle: 'De ${summary.totalRooms} salas',
                            icon: Icons.ac_unit,
                            color: Colors.indigo.shade700,
                            bgColor: Colors.indigo.shade50,
                          ),
                          _buildCompactMetricTile(
                            title: 'Tempo Ocioso',
                            value: _formatDuration(summary.totalWastedMinutes),
                            subtitle: 'Medido pelo dispositivo',
                            icon: Icons.timer_outlined,
                            color: const Color(0xFF1E1B4B),
                            bgColor: const Color(0xFFEEF2FF),
                          ),
                        ];

                        if (isWide) {
                          return Row(
                            children: [
                              for (int i = 0; i < cards.length; i++) ...[
                                Expanded(child: cards[i]),
                                if (i < cards.length - 1) const SizedBox(width: 10),
                              ],
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 10),
                                Expanded(child: cards[1]),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: cards[2]),
                                const SizedBox(width: 10),
                                Expanded(child: cards[3]),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // CABEÇALHO DA LISTA DE VERIFICAÇÃO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Salas para Verificar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: summary.alertRooms.isNotEmpty ? Colors.orange.shade50 : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: summary.alertRooms.isNotEmpty ? Colors.orange.shade200 : Colors.teal.shade200,
                            ),
                          ),
                          child: Text(
                            '${summary.alertRooms.length} ${summary.alertRooms.length == 1 ? 'alerta' : 'alertas'}',
                            style: TextStyle(
                              color: summary.alertRooms.isNotEmpty ? Colors.orange.shade900 : Colors.teal.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (summary.alertRooms.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_outlined, color: Colors.teal.shade600, size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Excelente! Todas as salas estão operando sem desperdício no momento.',
                                style: TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...summary.alertRooms.map((room) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.ac_unit, color: Colors.orange.shade800, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Sala vazia com ar ligado • Ref: ${room.targetTemperature.toStringAsFixed(1)}°C',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${room.deviceId != null ? 'Dispositivo: ${room.deviceId} • ' : ''}Ocioso total: ${_formatDuration(room.totalWastedMinutes)}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Text(
                                  'VERIFICAR',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusBanner(DashboardSummaryModel summary, bool hasWastedEnergy) {
    if (!hasWastedEnergy) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade600, Colors.teal.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withAlpha(35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.energy_savings_leaf, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ambientes em Uso Consciente!',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Nenhum ar-condicionado operando em sala vazia agora.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.notifications_active_outlined, color: Colors.orange.shade800, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desperdício de Energia Detectado!',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.wastingAcCount} ${summary.wastingAcCount == 1 ? 'sala vazia com ar ligado' : 'salas vazias com ar ligado'}.',
                  style: const TextStyle(color: Colors.black87, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDuration(summary.totalWastedMinutes),
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'tempo ocioso',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
