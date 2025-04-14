import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/widgets/audio_drop_zone.dart';
import 'package:transcriber_whisper/widgets/compact_tag_legend_widget.dart';
import 'package:transcriber_whisper/widgets/loadingWidget.dart';
import 'package:transcriber_whisper/widgets/punctuation_error_legend_widget.dart';
import 'package:transcriber_whisper/widgets/reading_mode_form.dart';
import 'package:transcriber_whisper/widgets/reading_speed_form.dart';
import 'package:transcriber_whisper/widgets/real_text_display_widget.dart';
import 'package:transcriber_whisper/widgets/tag_legend_widget.dart';

import 'models/audioFileInfo.dart';

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final ScrollController _scrollController = ScrollController();
  GetIt getIt = GetIt.instance;
  List<AudioFileInfo> _audioFiles = [];

  // Variables para almacenar los datos
  double? _readingSpeedTime;
  List<String> _selectedReadingModes = [];
  List<Map<String, dynamic>> _segmentData = [];

  @override
  void initState() {
    super.initState();
    getIt<TranscriptionCubit>().useMockTranscriptionEU();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Métodos para actualizar los datos
  void _updateReadingSpeedTime(double time) {
    setState(() {
      _readingSpeedTime = time;
    });
  }

  void _updateSelectedReadingModes(List<String> modes) {
    setState(() {
      _selectedReadingModes = modes;
    });
  }

  void _updateSegmentData(List<Map<String, dynamic>> data) {
    setState(() {
      _segmentData = data;
    });
  }

  // Método para guardar todos los datos
  void _saveAllData() {
    // Aquí puedes guardar todos los datos
    print("Tiempo de lectura: $_readingSpeedTime");
    print("Modos de lectura: $_selectedReadingModes");
    print("Datos de los segmentos: $_segmentData");
    // Puedes usar un servicio o una base de datos para guardar los datos
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Datos guardados")));
  }

  void _onFilesChanged(List<AudioFileInfo> files) {
    print('_onFilesChanged: ${files.length}');
    setState(() {
      _audioFiles = files;
    });
    if (files.isNotEmpty) {
      //_projectCubit.addSessionsToProject(files.map((e) => e.file).toList(), projectId: widget.projectId);
      //cubitProject.addSessionsToProject(files.map((e) => e.file).toList(), projectId: widget.projectId);
    }
  }

  void _onFilesReady() {
    print('_onFilesReady');
    if (_audioFiles.isNotEmpty) {
      //_projectCubit.addSessionsToProject(files.map((e) => e.file).toList(), projectId: widget.projectId);
      //cubitProject.addSessionsToProject(files.map((e) => e.file).toList(), projectId: widget.projectId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Page'), actions: [SizedBox(width: 500, child: AudioDropZone(onFilesChanged: _onFilesChanged, onFilesReady: _onFilesReady))]),
      body: Stack(
        children: [
          BlocBuilder<TranscriptionCubit, TranscriptionState>(
            builder: (context, state) {
              if (state.status == TranscriptionStatus.error) {
                return const Center(child: Text('Error al transcribir el audio'));
              }
              if (state.status == TranscriptionStatus.noserver) {
                return const Center(child: Text('No se pudo conectar con el servidor'));
              }
              if (state.status == TranscriptionStatus.loading) {
                return Center(child: LoadingWidget());
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // interfaz grafica principal
                    state.transcription != null
                        ? Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                TagLegendWidget(onSegmentDataChanged: _updateSegmentData),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Column(
                                        children: [
                                          ReadingSpeedForm(onTimeChanged: _updateReadingSpeedTime),
                                          SizedBox(
                                            height: 100,
                                            child: RealTextDisplayWidget(transcription: state.transcription!, audioPosition: Duration(), currentWordIndex: 0, onWordTap: (int) {}),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Flexible(child: ReadingModeForm(onModesChanged: _updateSelectedReadingModes)),
                                  ],
                                ),
                                Row(children: [Flexible(child: CompactTagLegendWidget()), Flexible(child: PunctuationErrorLegendWidget())]),

                                ElevatedButton(onPressed: _saveAllData, child: const Text("Guardar")),
                              ],
                            ),
                          ),
                        )
                        : Container(),
                  ],
                ),
              );
            },
          ),
          //FloatingWindow(title: "MFA Logs", initialX: 10, initialY: 10, initialWidth: 300, initialHeight: 100, child: MfaLogsWidget()),
        ],
      ),
    );
  }
}
