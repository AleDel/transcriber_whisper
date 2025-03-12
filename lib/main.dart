import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/eu_page.dart';
import 'package:transcriber_whisper/eu_text_page.dart';
import 'package:transcriber_whisper/home_page.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:get_it/get_it.dart';

import 'es_page.dart';

final getIt = GetIt.instance;

void main() {
  getIt.registerSingleton<TranscribeCubit>(TranscribeCubit());
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<TranscribeCubit>(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        routes: {
          '/': (context) => const HomePage(), // Ruta principal
          '/EUTextPage': (context) => const EUTextPage(),
          '/EUPage': (context) => const EUPage(),
          '/ESPage': (context) => const ESPage(),
        },
      ),
    );
  }
}
