import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/models/audioFileInfo.dart';
import 'package:transcriber_whisper/widgets/audio_drop_zone.dart';

import 'models/session.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final audioPlayer = AudioPlayer();
  String _originalText = '';
  List<AudioFileInfo> _files = [];

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  void _onFilesChanged(List<AudioFileInfo> files) {
    print("Callback Drop Zone en main page, _onFilesChanged: ${files}");
    final cubit = context.read<TranscribeCubit>();
    List<PlatformFile> platformFiles = [];
    for (var fileInfo in files) {
      platformFiles.add(fileInfo.file);
    }
    cubit.addFiles(platformFiles);

  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TranscribeCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcriber Whisper'),
      ),
      body: BlocBuilder<TranscribeCubit, TranscribeState>(
        builder: (context, state) {
          if (state.currentProject != null && state.currentProject!.sessions.isNotEmpty) {
            _originalText = state.currentProject!.sessions.first.originalText ?? "";
          }
          return Column(
            children: [
              // Lista de Sesiones
              if (state.currentProject != null && state.currentProject!.sessions.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: state.currentProject!.sessions.length,
                    itemBuilder: (context, index) {
                      final session = state.currentProject!.sessions[index];
                      return ListTile(
                        title: Text('Sesión ${index + 1} - ${session.audioFilename}'),
                        subtitle: session.status == SessionStatus.processingAudio
                            ? const Text("Procesando Audio")
                            : session.status == SessionStatus.transcribing
                            ? const Text("Transcribiendo")
                            : session.status == SessionStatus.completed
                            ? const Text("Completado")
                            : session.status == SessionStatus.error
                            ? const Text("Error")
                            : const Text("Pendiente"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (session.status != SessionStatus.processingAudio && session.status != SessionStatus.transcribing && session.status != SessionStatus.completed)
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () async {
                                  await cubit.processSession(session);
                                  //await cubit.processAndTranscribeFiles(state.currentProject!.id, [PlatformFile(name: session.audioFilename, path: session.wavFilename, size: 0)]);
                                },
                              ),
                            if (session.status == SessionStatus.processingAudio || session.status == SessionStatus.transcribing) const CircularProgressIndicator(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (state.currentProject != null && state.currentProject!.sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No hay sesiones guardadas para este proyecto.'),
                ),
              // Botón para Añadir Sesiones
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Mostrar el DropZone para añadir archivos
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return BlocBuilder<TranscribeCubit, TranscribeState>(
                              builder: (context, state) {
                                return SizedBox(
                                  height: 300, // Ajusta la altura según tus necesidades
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: AudioDropZone(
                                          onFilesChanged: _onFilesChanged,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton(
                                            onPressed: state.files.isEmpty
                                                ? null
                                                : () async {
                                              if (state.currentProject != null) {
                                                await cubit.addFilesToProject(state.currentProject!.id, state.files);
                                                cubit.clearFiles();
                                                Navigator.pop(context); // Cerrar el BottomSheet
                                              }
                                            },
                                            child: const Text('Aceptar'),
                                          ),
                                          const SizedBox(width: 16),
                                          ElevatedButton(
                                            onPressed: () async {
                                              cubit.clearFiles();
                                              Navigator.pop(context); // Cerrar el BottomSheet
                                            },
                                            child: const Text('Cancelar'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      child: const Text('Añadir Sesión'),
                    ),
                    const SizedBox(width: 16), // Espacio entre los botones
                    ElevatedButton(
                      onPressed: state.currentProject == null
                          ? null
                          : () async {
                        await cubit.deleteAllSessions(state.currentProject!.id);
                      },
                      child: const Text('Borrar Sesiones'),
                    ),
                  ],
                ),
              ),
              // Lista de Archivos
              // Transcripción (Solo visible cuando hay una transcripción)
              if (state.transcription != null)
                Expanded(
                  child: ListView.builder(
                    itemCount: state.transcription!.segments.length,
                    itemBuilder: (context, index) {
                      final segment = state.transcription!.segments[index];
                      return ListTile(
                        title: Text(segment.word),
                        subtitle: Text('Start: ${segment.start}, End: ${segment.end}'),
                      );
                    },
                  ),
                ),
              // Texto Original
              if (state.currentProject != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: TextEditingController(text: _originalText),
                    onChanged: (value) {
                      setState(() {
                        _originalText = value;
                      });
                      if (state.currentProject != null) {
                        if (state.currentProject!.sessions.isNotEmpty) {
                          cubit.saveOriginalText(state.currentProject!.id, state.currentProject!.sessions.first.id, value);
                        }
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Texto original',
                    ),
                  ),
                ),
              // Información Adicional
              if (state.extradata != null)
                Text(
                  'Audio Position: ${state.extradata!.audioPosition ?? 0}, Current Word Index: ${state.extradata!.currentWordIndex ?? 0}',
                ),
              if (state.status == TranscribeStatus.noserver) Center(child: Text('Error: ${state.errorMessage} ${state.errorDetails}'))
            ],
          );
        },
      ),
    );
  }
}