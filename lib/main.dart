import 'package:flutter/material.dart';
import 'package:gini_test_app/audio_provider.dart';
import 'package:gini_test_app/home_screen.dart';
import 'package:provider/provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AudioProvider>(
          create: (context) => AudioProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'WS Audio (sound_stream)',
        home: const HomeScreen(),
      ),
    );
  }
}
