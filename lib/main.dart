import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/diff_text_page.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:get_it/get_it.dart';
import 'models/iframe_integration.dart';

final getIt = GetIt.instance;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  getIt.registerSingleton<TranscriptionCubit>(TranscriptionCubit());
  getIt.registerSingleton<IframeIntegration>(IframeIntegration());
  runApp(const MainAppWrapper()); // Usar MainAppWrapper en lugar de MainApp
}

// Nuevo StatefulWidget para exponer la función a JavaScript
class MainAppWrapper extends StatefulWidget {
  const MainAppWrapper({super.key});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> {
  @override
  void initState() {
    super.initState();
    getIt<IframeIntegration>().exposeFunctionToJs(getIt: getIt); // Llamar a exposeFunctionToJs en initState
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diff Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (context) => getIt<TranscriptionCubit>(),
        child: const DiffTextPage(),
      ),
    );
  }
}