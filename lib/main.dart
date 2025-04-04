import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/eu_page.dart';
import 'package:transcriber_whisper/eu_text_page.dart';
import 'package:transcriber_whisper/home_page.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/transcribe_page.dart';

import 'demo_page.dart';
import 'es_page.dart';
import 'eu_text_page2.dart';
import 'otradiff_page.dart';

final getIt = GetIt.instance;

void main() {
  getIt.registerSingleton<TranscriptionCubit>(TranscriptionCubit());
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<TranscriptionCubit>(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        routes: {
          '/': (context) => const HomePage(), // Ruta principal
          '/testCompare':(context) => OtraDiffPage(title: '',),
          '/EUTextPage': (context) => const EUTextPage2(),
          '/EUPage': (context) => const EUPage(),
          '/ESPage': (context) => const ESPage(),
          '/TrascribePage':(context)=>  TranscribePage(),
          '/DemoPage':(context)=>  DemoPage(),
        },
      ),
    );
  }
}
