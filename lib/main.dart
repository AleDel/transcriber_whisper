import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:get_it/get_it.dart';

import 'data_repository.dart';
import 'home_page.dart';

final getIt = GetIt.instance;

void main() {
  //WidgetsFlutterBinding.ensureInitialized();
  //getIt.registerLazySingleton<TranscribeCubit>(() => TranscribeCubit());
  getIt.registerSingleton<DataRepository>(DataRepository());
  getIt.registerSingleton<TranscribeCubit>(TranscribeCubit(getIt<DataRepository>()));
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<TranscribeCubit>(),
      //child: const MaterialApp(home: HomePage3()),
      child: MaterialApp(home: HomePage()),
    );
  }
}
