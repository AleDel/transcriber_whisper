/*import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/cubits/project_cubit.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/cubits/transcription_cubit.dart';
import 'package:transcriber_whisper/models/session_data.dart';
import 'package:transcriber_whisper/widgets/audioPlayer_widget.dart';
import 'package:transcriber_whisper/widgets/sliding_text_widget.dart';
import 'package:transcriber_whisper/widgets/transcriptionDiff_widget.dart';
import 'package:transcriber_whisper/widgets/vertical_text_widget.dart';

class SessionDetailPage extends StatefulWidget {
  final SessionData session;

  const SessionDetailPage({Key? key, required this.session}) : super(key: key);

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  //late SessionCubit _sessionCubit;
  GetIt getIt = GetIt.instance;
  @override
  void initState() {
    super.initState();
    //_sessionCubit = GetIt.instance<SessionCubit>();
    //_sessionCubit.loadSession(widget.session.id);
    getIt<SessionCubit>().loadSession(widget.session.id, "no audio");
    //getIt<SessionCubit>().updateSession(widget.session);
    getIt<SessionCubit>().loadProcessedAudio();
    //getIt<SessionCubit>().initAudioPlayer();
  }
  @override
  void dispose() {
    getIt<SessionCubit>().audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //_sessionCubit.loadProcessedAudio();
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles de la Sesión: ${widget.session.audioFilename} --- ${widget.session.id}'),
      ),
      body: BlocBuilder<ProjectCubit, ProjectState>(
        builder: (context, projectState) {
          if (projectState.project == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Encuentra la sesión actual en el proyecto
          final currentSessionProject = projectState.project!.sessions.firstWhere((s) => s.id == widget.session.id, orElse: () => widget.session);
          return BlocConsumer<TranscriptionCubit, TranscriptionState>(
            listener: (context, state) {
              if (state.transcriptionStatus == TranscriptionStatus.connectedAudioProcess) {
                _showSnackBar(context, 'Procesamiento de audio Conexión');
              } else if (state.transcriptionStatus == TranscriptionStatus.processingAudio) {
                _showSnackBar(context, 'Procesamiento de audio Procesando...');
              } else if (state.transcriptionStatus == TranscriptionStatus.completedAudioProcess) {
                _showSnackBar(context, 'Procesamiento de audio completado');
              } else if (state.transcriptionStatus == TranscriptionStatus.processingTranscription) {
                _showSnackBar(context, '///////////Transcribiendo audio...');
              } else if (state.transcriptionStatus == TranscriptionStatus.completedTranscription) {
                _showSnackBar(context, 'Transcripción completada');
              } else if (state.transcriptionStatus == TranscriptionStatus.error) {
                _showSnackBar(context, 'Error: ${state.errorMessage}');
              }
            },
            builder: (context, state) {
              final cubitTranscription = context.read<TranscriptionCubit>();
              return BlocBuilder<SessionCubit, SessionState>(
                builder: (context, sessionState) {
                  final currentSession = sessionState.sessionData ?? currentSessionProject;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Nombre del Archivo: ${currentSession.audioFilename}'), const SizedBox(height: 20),
                        // Botón para procesar el audio
                        if (state.transcriptionStatus == TranscriptionStatus.pending && currentSession.transcription == null)
                          ElevatedButton(
                            onPressed: () async {
                              cubitTranscription.sendFilesToAudioProcessor(currentSession);
                            },
                            child: const Text('Procesar Audio'),
                          ),
                        // Mostrar el estado del procesamiento

                        Text("${state.transcriptionStatus}"),
                        if (state.transcriptionStatus == TranscriptionStatus.error) Text("${state.errorMessage}"),
                        if (currentSession.transcription != null)
                          Expanded(
                            child: Column(
                              children: [
                                if (state.transcriptionStatus == TranscriptionStatus.pending && currentSession.transcription == null)
                                  ElevatedButton(
                                    onPressed: () async {
                                      cubitTranscription.sendFilesToAudioProcessor(currentSession);
                                    },
                                    child: const Text('volver a transcribir'),
                                  ),
                                SlidingText(
                                  audioPosition: sessionState.sessionStatusData?.audioPosition ?? Duration.zero,
                                  currentWordIndex: sessionState.sessionStatusData?.currentWordIndex ?? 0,
                                  onWordTap: (int index) {
                                    //context.read<SessionCubit>().forceCurrentWord(index);
                                  },
                                  transcription: currentSession.transcription!,
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: VerticalTranscription(
                                          //session: currentSession,
                                          audioPosition: sessionState.sessionStatusData?.audioPosition ?? Duration.zero,
                                          currentWordIndex: sessionState.sessionStatusData?.currentWordIndex ?? 0,
                                          onWordTap: (int index) {
                                            // Aquí puedes manejar el clic en una palabra
                                            //context.read<SessionCubit>().forceCurrentWord(index);

                                            getIt<SessionCubit>().forceCurrentWord(index);
                                          },
                                          onSeek: (Duration d, int indexword) {
                                            print("seeeeek");
                                            getIt<SessionCubit>().audioPlayer.seek(d);
                                            getIt<SessionCubit>().forceCurrentWord(indexword);
                                            //context.read<SessionCubit>().updateCurrentWord(d);
                                          },
                                          transcription: currentSession.transcription!,
                                        ),
                                      ),
                                      Expanded(
                                          child: Column(
                                        children: [
                                          AudioPlayerWidget(
                                            //sessionData: sessionState.sessionData!,
                                          ),
                                          Expanded(
                                              child: TranscriptionDiff(
                                            session: currentSession,
                                          ))
                                        ],
                                      )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}*/
