import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tafsol_genie_app/view/screens/home_screen.dart';


void main() => runApp(ProviderScope(child: const MyApp()));

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WS Audio (flutter_soloud)',
      home: const HomeScreen(),
    );
  }
}
