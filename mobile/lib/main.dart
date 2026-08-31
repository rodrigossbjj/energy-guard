import 'package:flutter/material.dart';
import 'screens/room_list_screen.dart';

void main() {
  runApp(const EnergyGuardApp());
}

class EnergyGuardApp extends StatelessWidget {
  const EnergyGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Energy Guard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const RoomListScreen(),
    );
  }
}
