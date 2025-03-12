import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/mfa_service.dart';
import 'package:transcriber_whisper/new_page.dart';
import 'package:transcriber_whisper/session_screen.dart';

import 'cubits/project_cubit.dart';
import 'cubits/transcription_cubit.dart';
import 'data_repository.dart';
import 'indexed_db_service.dart';
import 'home_page.dart';
import 'main_page.dart';
import 'models/session_data.dart';

final getIt = GetIt.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  getIt.registerSingleton<IndexedDBService>(IndexedDBService());
  getIt.registerSingleton<MfaService>(MfaService());
  getIt.registerSingleton<DataRepository>(DataRepository(getIt<IndexedDBService>()));

  getIt.registerSingleton<ProjectCubit>(ProjectCubit(getIt<DataRepository>()));
  getIt.registerSingleton<TranscriptionCubit>(TranscriptionCubit(getIt<DataRepository>(), getIt<ProjectCubit>(), getIt<MfaService>()));
  //getIt.registerSingleton<TranscriptionCubit>(TranscriptionCubit(getIt<DataRepository>(), getIt<ProjectCubit>(), getIt<MfaService>(), TranscriptionState(transcriptionStatus: TranscriptionStatus.pending, currentProject: Project(id: "1", name: "name", sessions: [SessionData(id: "1", projectId: "1", audioFilename: "audio", transcription: Transcription(segments: []))]))));
  getIt.registerSingleton<SessionCubit>(SessionCubit(getIt<TranscriptionCubit>(), getIt<DataRepository>(), getIt<ProjectCubit>())); // Registra SessionCubit aquí
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<ProjectCubit>()),
        BlocProvider(create: (context) => getIt<TranscriptionCubit>()),
        BlocProvider(create: (context) => getIt<SessionCubit>()), // Proporciona SessionCubit aquí
      ],
      //child: const MaterialApp(home: HomePage()),
      child: MaterialApp(
        title: 'Transcriber Whisper',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: SessionScreen(),
        //home: MainPage(projectId: '',),
        /*routes: {
          '/session': (context) => SessionScreen(sessionData: ModalRoute.of(context)!.settings.arguments as SessionData),
        },*/
      ),
    );
  }
}