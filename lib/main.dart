import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:transcriber_whisper/diff_text_page.dart';
import 'package:transcriber_whisper/share_page.dart';
import 'package:transcriber_whisper/transcribe_page.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/viewer_page.dart';
import 'check_audio_page.dart';
import 'check_server_transcription_ page.dart';
import 'details_page.dart';
import 'models/iframe_integration.dart';

final getIt = GetIt.instance;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Define the routes
final _router = GoRouter(
  navigatorKey: navigatorKey,
  routes: [
    GoRoute(
        path: '/',
        builder: (context, state) {
          print("iendo a la ruta: /");
          return Center(child: Text(""),);
          /*return BlocProvider(
            create: (context) => getIt<TranscriptionCubit>(),
            child: const DiffTextPage(),
          );*/
        }),
    GoRoute(
      path: '/share',
      builder: (context, state) => BlocProvider(
        create: (context) => getIt<TranscriptionCubit>(),
        child: const SharePage(),
      ),
    ),
    GoRoute(
      path: '/details/:audioName',
      builder: (context, state) {
        final audioName = state.pathParameters['audioName']!; // Get audioName here
        print("iendo a la ruta: de detalles de $audioName");
        print("GoRoute audioName: $audioName");
        return BlocProvider(
          create: (context) => getIt<TranscriptionCubit>(),
          child: DetailsPage(audioName: audioName), // Pass audioName to DetailsPage
        );
      },
    ),
    GoRoute(
      path: '/checkaudio?filename=:audioName',
      builder: (context, state) {
        final audioName = state.pathParameters['audioName']!; // Get audioName here
        print("iendo a la ruta: de detalles de $audioName");
        print("GoRoute audioName: $audioName");
        return BlocProvider(
          create: (context) => getIt<TranscriptionCubit>(),
          child: CheckAudioPage( filename: audioName,)
          //child: DetailsPage(audioName: audioName), // Pass audioName to DetailsPage
        );
      },
    ),
    GoRoute(
      path: '/view?filename=:audioName',
      builder: (context, state) {
        final audioName = state.pathParameters['audioName']!; // Get audioName here
        final text = state.uri.queryParameters['text'];
        print("iendo a la ruta: de view de $audioName");
        print("GoRoute audioName: $audioName");
        return BlocProvider(
            create: (context) => getIt<TranscriptionCubit>(),
            child: ViewerPage( filename: audioName, text:text)
          //child: DetailsPage(audioName: audioName), // Pass audioName to DetailsPage
        );
      },
    ),
    GoRoute(
      path: '/view', // Cambiado el path
      builder: (context, state) {
        final filename = state.uri.queryParameters['filename']; // Get filename from query parameters
        final text = state.uri.queryParameters['text']; // Get text from query parameters
        print("viendo el view filename: $filename");
        return BlocProvider(
            create: (context) => getIt<TranscriptionCubit>(),
            child: ViewerPage( filename: filename!, text:text)
          //child: DetailsPage(audioName: audioName), // Pass audioName to DetailsPage
        );
      },
    ),
    GoRoute(
      path: '/checkaudio',
      builder: (context, state) {
        final filename = state.uri.queryParameters['filename'];
        print("viendo el filename: $filename");
        return CheckAudioPage(filename: filename);
      },
    ),
    GoRoute(
      path: '/statusServerTranscription', // Nueva ruta
      builder: (context, state) {
        print("viendo la ruta: /statusServerTranscription");
        return const CheckServerTranscriptionPage();
      },
    ),
    GoRoute(
      path: '/transcribe', // Nueva ruta
      builder: (context, state) {
        print("viendo la ruta: /transcribe");
        return const TranscribePage();
      },
    ),
    GoRoute(
      path: '/transcribe-file', // Nueva ruta para filepath
      builder: (context, state) {
        final filePath = state.uri.queryParameters['filepath']; // Get filepath from query parameters
        print("viendo la ruta: /transcribe-file");
        print("viendo el filepath: $filePath");
        return BlocProvider(
          create: (context) => getIt<TranscriptionCubit>(),
          child: TranscribePage(filePath: filePath), // Pass filePath to TranscribePage
        );
      },
    ),
  ],
);

void main() {
  print('Main function started');
  getIt.registerSingleton<TranscriptionCubit>(TranscriptionCubit());
  getIt.registerSingleton<IframeIntegration>(IframeIntegration());
  runApp(const MainAppWrapper());
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
    //_handleInitialUrl();
  }

  void _handleInitialUrl() async {
    final path = html.window.location.hash;
    print('Current URL: $path');
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized; // Wait for the first frame
    Future.microtask(() {
      _router.go(path.replaceFirst('#', '')); // Use go instead of replace
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TranscriptionCubit>(
      create: (context) => getIt<TranscriptionCubit>(),
      child: MaterialApp.router(
        routerConfig: _router,
        title: 'Diff Viewer',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
      ),
    );
  }
}



