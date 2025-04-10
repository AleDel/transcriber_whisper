import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/diff_text_page.dart';
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

import 'dart:html' as html;

final getIt = GetIt.instance;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  getIt.registerSingleton<TranscriptionCubit>(TranscriptionCubit());
  // Escuchar el evento popstate
  /*html.window.onPopState.listen((_) {
    print("aaaaaaaaaa");
    // Redirigir a la ruta principal
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  });
  // Escuchar el evento load
  html.window.onLoad.listen((_) {
    print("aaaaaaaaaa");
    // Redirigir a la ruta principal
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  });*/
  // Escuchar el evento flutter-first-frame
  html.window.addEventListener('flutter-first-frame', (ev) {
    print("Flutter se ha cargado recibido");
    //getIt<TranscriptionCubit>().resetState();
    // Redirigir a la ruta principal
     //navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);

  });
  html.window.onBeforeUnload.listen((event) async{
    print("onBeforeUnload");
    getIt<TranscriptionCubit>().audioPlayer.release();
    getIt<TranscriptionCubit>().audioPlayer.dispose();
    //await navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  });
  html.window.onUnload.listen((event) async{
    print("onUnload");
   // await navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  });
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<TranscriptionCubit>(),
      child:MaterialApp(home: DiffTextPage(),) /*MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          //'/': (context) => const HomePage(), // Ruta principal
          '/': (context) => const DiffTextPage(), // Ruta principal
          '/testCompare':(context) => OtraDiffPage(title: '',),
          '/EUTextPage': (context) => const EUTextPage2(),
          '/EUPage': (context) => const EUPage(),
          '/ESPage': (context) => const ESPage(),
          '/TrascribePage':(context)=>  TranscribePage(),
          '/DemoPage':(context)=>  DemoPage(),
          '/DiffTextPage':(context)=>  DiffTextPage(),
        },
      ),*/
    );
  }
}
