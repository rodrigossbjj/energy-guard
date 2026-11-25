import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../widgets/ble_wifi_config_modal.dart';
import 'login_screen.dart';
import 'room_form_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final RoomService _roomService = RoomService();
  List<RoomModel> _rooms = [];
  bool _isLoadingRooms = true;
  bool _isTestingPing = false;
  int? _latencyMs;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingRooms = true);
    try {
      final rooms = await _roomService.getRooms();
      final ping = await _roomService.pingBackend();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _latencyMs = ping;
        _isLoadingRooms = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRooms = false);
    }
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

  String _formatLastSeen(DateTime? updatedAt) {
    if (updatedAt == null) return 'Sem registro recente';
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 5) return 'Agora mesmo';
    if (diff.inSeconds < 60) return 'Há ${diff.inSeconds} s';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours} h';
    return 'Há ${diff.inDays} d';
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Confirmar Saída'),
        content: const Text('Deseja realmente desconectar e sair do Energy Guard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              AuthService.logout();
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _showServerConfigDialog() {
    final hostController = TextEditingController(text: ApiConfig.host);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.dns_outlined, color: Color(0xFF1E1B4B)),
            SizedBox(width: 8),
            Text('Configurar Servidor API', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Altere o IP ou Host do servidor Backend em tempo real:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hostController,
              decoration: InputDecoration(
                labelText: 'Host / IP',
                hintText: 'ex: 192.168.1.15 ou localhost',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.settings_ethernet),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Porta Backend: ${ApiConfig.backendPort}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1B4B),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              ApiConfig.updateHost(hostController.text);
              Navigator.pop(ctx);
              await _testPing();
            },
            child: const Text('Salvar e Testar'),
          ),
        ],
      ),
    );
  }

  Future<void> _testPing() async {
    setState(() => _isTestingPing = true);
    final latency = await _roomService.pingBackend();
    final rooms = await _roomService.getRooms();
    if (!mounted) return;
    setState(() {
      _latencyMs = latency;
      _rooms = rooms;
      _isTestingPing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          latency != null
              ? 'Conectado ao servidor (${ApiConfig.host}) em $latency ms!'
              : 'Servidor (${ApiConfig.host}) inacessível. Operando em modo simulado.',
        ),
        backgroundColor: latency != null ? Colors.teal.shade700 : Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleEditRoom(RoomModel room) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RoomFormScreen(room: room)),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _handleResetSingleRoomMetrics(RoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Zerar Contador da Sala'),
        content: Text(
          'Deseja zerar o tempo ocioso acumulado da sala "${room.name}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1B4B),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zerar Sala'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _roomService.resetRoomMetrics(room.id, adminPassword: AuthService.adminPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contador da sala "${room.name}" zerado com sucesso!'),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _handleDeleteRoom(RoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Excluir Sala'),
        content: Text('Deseja excluir permanentemente a sala "${room.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _roomService.deleteRoom(room.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sala "${room.name}" excluída com sucesso!'),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _handleUnlinkDevice(RoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Desvincular Dispositivo'),
        content: Text(
          'Deseja desvincular o dispositivo "${room.deviceId}" da sala "${room.name}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _roomService.unlinkDevice(room.id, adminPassword: AuthService.adminPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispositivo desvinculado da sala "${room.name}".'),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _handleLinkOrReconfigureBle(RoomModel room) async {
    final newDeviceId = await BleWifiConfigModal.show(context);
    if (newDeviceId == null || newDeviceId.isEmpty || !mounted) return;

    try {
      await _roomService.updateRoom(room.id, {
        'name': room.name,
        'deviceId': newDeviceId,
        'targetTemperature': room.targetTemperature,
        'portabilityPassword': AuthService.adminPassword,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispositivo "$newDeviceId" vinculado à sala "${room.name}"!'),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao vincular: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _handleResetAllMetrics() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Zerar Todos os Contadores'),
        content: const Text(
          'Isso zerará o tempo ocioso acumulado de todas as salas cadastradas. Deseja confirmar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1B4B),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zerar Tudo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _roomService.resetAllMetrics(adminPassword: AuthService.adminPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Todos os contadores de ociosidade foram zerados!'),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _showBatchTemperatureDialog() {
    final tempController = TextEditingController(text: '23.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.thermostat_outlined, color: Color(0xFF1E1B4B)),
            SizedBox(width: 8),
            Text('Padronizar Temperatura', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Defina a temperatura de referência para aplicar em todas as suas salas de uma vez:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tempController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Temperatura (°C)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.thermostat),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1B4B),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final temp = double.tryParse(tempController.text.trim());
              if (temp == null || temp < 10 || temp > 40) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informe uma temperatura entre 10°C e 40°C.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _roomService.updateBatchTemperature(
                  temp,
                  adminPassword: AuthService.adminPassword,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Temperatura de todas as salas padronizada para ${temp.toStringAsFixed(1)}°C!'),
                    backgroundColor: Colors.teal.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _loadData();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red.shade700),
                );
              }
            },
            child: const Text('Aplicar em Todas'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = AuthService.currentUserEmail ?? 'admin@energyguard.com';
    final linkedCount = _rooms.where((r) => r.deviceId != null && r.deviceId!.isNotEmpty).length;
    final unlinkedCount = _rooms.length - linkedCount;
    final totalWasted = _rooms.fold<double>(0.0, (sum, r) => sum + r.totalWastedMinutes);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Meu Perfil', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Atualizar dados',
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // CARD DE PERFIL DO USUÁRIO
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xFFEEF2FF),
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AuthService.displayName,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Text(
                                'Conta Ativa • Energy Guard',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _confirmLogout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.logout, size: 17),
                        label: const Text('Sair', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // SEÇÃO DE GESTÃO E CONFIGURAÇÕES
                const Row(
                  children: [
                    Icon(Icons.tune, size: 19, color: Color(0xFF1E1B4B)),
                    SizedBox(width: 8),
                    Text(
                      'Gestão do Ambiente & Dispositivos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 1. CONECTIVIDADE E SERVIDOR
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Conectividade & Servidor',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _latencyMs != null ? Colors.teal.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _latencyMs != null ? Colors.teal.shade200 : Colors.red.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 3.5,
                                  backgroundColor: _latencyMs != null ? Colors.teal : Colors.red.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _latencyMs != null
                                      ? 'API Online (${_latencyMs}ms)'
                                      : 'API Offline',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _latencyMs != null ? Colors.teal.shade900 : Colors.red.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Endpoint ativo: ${ApiConfig.backendBaseUrl}',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isTestingPing ? null : _testPing,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E1B4B),
                              side: BorderSide(color: Colors.indigo.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isTestingPing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.network_check, size: 17),
                            label: const Text('Testar API', style: TextStyle(fontSize: 12.5)),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _showServerConfigDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E1B4B),
                              side: BorderSide(color: Colors.indigo.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            label: const Text('Alterar IP', style: TextStyle(fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 2. CONTROLES EM LOTE (GERAL)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Controles Gerais (Em Lote)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tempo ocioso acumulado nas suas salas: ${_formatDuration(totalWasted)}',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _handleResetAllMetrics,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1B4B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('Zerar Todas as Salas', style: TextStyle(fontSize: 12.5)),
                          ),
                          OutlinedButton.icon(
                            onPressed: _showBatchTemperatureDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E1B4B),
                              side: BorderSide(color: Colors.indigo.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.thermostat_outlined, size: 18),
                            label: const Text('Padronizar Temperatura Geral', style: TextStyle(fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. GESTÃO INDIVIDUAL DAS SALAS E DISPOSITIVOS
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Gestão Individual de Salas & Dispositivos',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Text(
                            '$linkedCount ativos • $unlinkedCount sem vínculo',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingRooms)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_rooms.isEmpty)
                        Text(
                          'Nenhuma sala cadastrada no momento.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        )
                      else
                        ..._rooms.map((room) {
                          final hasDevice = room.deviceId != null && room.deviceId!.isNotEmpty;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hasDevice ? Colors.grey.shade200 : Colors.orange.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // LINHA 1: Nome da Sala + Badge do Dispositivo + Menu de Ações Secundárias (⋮)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: hasDevice ? Colors.teal.shade50 : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        hasDevice ? Icons.developer_board : Icons.link_off,
                                        size: 20,
                                        color: hasDevice ? Colors.teal.shade700 : Colors.orange.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        room.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: hasDevice ? Colors.teal.shade50 : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: hasDevice ? Colors.teal.shade200 : Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        hasDevice ? room.deviceId! : 'Sem vínculo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: hasDevice ? Colors.teal.shade800 : Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade700),
                                      tooltip: 'Mais opções',
                                      color: Colors.white,
                                      surfaceTintColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      onSelected: (value) {
                                        if (value == 'unlink') {
                                          _handleUnlinkDevice(room);
                                        } else if (value == 'delete') {
                                          _handleDeleteRoom(room);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        if (hasDevice)
                                          PopupMenuItem(
                                            value: 'unlink',
                                            child: Row(
                                              children: [
                                                Icon(Icons.link_off, size: 18, color: Colors.orange.shade800),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Desvincular Dispositivo',
                                                  style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                                                ),
                                              ],
                                            ),
                                          ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Excluir Sala',
                                                style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // LINHA 2: Faixa Alinhada de Indicadores da Sala
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.thermostat_outlined, size: 15, color: Colors.teal.shade700),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Ref: ${room.targetTemperature.toStringAsFixed(1)}°C',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.timer_outlined, size: 15, color: Colors.indigo.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Ocioso: ${_formatDuration(room.totalWastedMinutes)}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E1B4B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.sensors, size: 15, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatLastSeen(room.updatedAt),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // LINHA 3: Grade Simétrica de 3 Botões de Mesmo Tamanho (100% Alinhados)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildRoomActionButton(
                                        icon: Icons.edit_outlined,
                                        label: 'Editar',
                                        color: Colors.indigo.shade700,
                                        bgColor: Colors.indigo.shade50,
                                        onTap: () => _handleEditRoom(room),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildRoomActionButton(
                                        icon: Icons.restart_alt,
                                        label: 'Zerar Tempo',
                                        color: Colors.teal.shade700,
                                        bgColor: Colors.teal.shade50,
                                        onTap: () => _handleResetSingleRoomMetrics(room),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildRoomActionButton(
                                        icon: Icons.bluetooth,
                                        label: hasDevice ? 'Wi-Fi BLE' : 'Vincular',
                                        color: const Color(0xFF1E1B4B),
                                        bgColor: const Color(0xFFEEF2FF),
                                        onTap: () => _handleLinkOrReconfigureBle(room),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withAlpha(45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
