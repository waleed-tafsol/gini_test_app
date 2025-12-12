import 'package:flutter/material.dart';
import 'package:gini_test_app/audio_page.dart';
import 'package:gini_test_app/audio_provider.dart';
import 'package:gini_test_app/human_model_view.dart';
import 'package:provider/provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WS Audio (sound_stream)',
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AudioProvider>(
            create: (context) => AudioProvider(),
          ),
        ],
        child: const AudioPage(),
      ),
    );
  }
}
