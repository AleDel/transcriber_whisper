import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/widgets/audioPlayer_widget.dart';
import 'package:transcriber_whisper/widgets/floatingWindow_widget.dart';
import 'package:transcriber_whisper/widgets/mfaLogs_widget.dart';
import 'package:transcriber_whisper/widgets/selectableRichText_widget.dart';
import 'package:transcriber_whisper/widgets/slider_widget.dart';
import 'package:transcriber_whisper/widgets/vertical_widget.dart';

class HomePage3 extends StatefulWidget {
  const HomePage3({super.key});

  @override
  State<HomePage3> createState() => _HomePage3State();
}

class _HomePage3State extends State<HomePage3> {
  final ScrollController _scrollController = ScrollController();
  GetIt getIt = GetIt.instance;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Transcriber')),
      body: Stack(
        children: [
          BlocBuilder<TranscribeCubit, TranscribeState>(
            builder: (context, state) {
              if (state.status == TranscribeStatus.error) {
                return const Center(child: Text('Error al transcribir el audio'));
              }
              if (state.status == TranscribeStatus.noserver) {
                return const Center(child: Text('No se pudo conectar con el servidor'));
              }
              if (state.status == TranscribeStatus.loading) {
                return Center(child: CircularProgressIndicator());
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // botones transcribir, etc
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async => getIt<TranscribeCubit>().pickAudioFile(),
                          child: const Text('Cargar Audio'),
                        ),
                        ElevatedButton(
                          onPressed: () async => getIt<TranscribeCubit>().useMockTranscription(),
                          child: const Text('Usar Mock data'),
                        ),
                      ],
                    ),
                    // interfaz grafica principal
                    state.transcription != null
                        ? Expanded(
                          child: Column(
                            children: [
                              AudioPlayerWidget(),
                              if (state.waveformImageBase64 != null)
                                Image.memory(
                                  base64Decode(state.waveformImageBase64!),
                                  width: 500,
                                  height: 100,
                                ),
                              if (state.melSpectrogramBase64 != null)
                                Image.memory(
                                  base64Decode(state.melSpectrogramBase64!),
                                  width: 500,
                                  height: 100,
                                ),
                              SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                child: SlidingText(
                                  transcription: state.transcription!,
                                  audioPosition: state.extradata!.audioPosition,
                                  currentWordIndex: state.extradata!.currentWordIndex,
                                  waveformImageBase64: state.waveformImageBase64,
                                  scrollController: _scrollController,
                                  onWordTap: (index) {
                                    getIt<TranscribeCubit>().forceCurrentWord(index);
                                  },
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: VerticalTranscription(
                                        transcription: state.transcription!,
                                        audioPosition: state.extradata!.audioPosition,
                                        currentWordIndex: state.extradata!.currentWordIndex,
                                        onSeek: (duration, index) {
                                          getIt<TranscribeCubit>().forceCurrentWord(index);
                                        },
                                        autoScrollEnabled: true,
                                        onAutoScrollChanged: (value) {
                                          getIt<TranscribeCubit>().setAutoScroll(value);
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: SelectableRichText(
                                        segments: state.transcription!.segments,
                                        currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                                        onWordTap: (index) {
                                          getIt<TranscribeCubit>().forceCurrentWord(index);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        : Container(),
                  ],
                ),
              );
            },
          ),
          FloatingWindow(
            title: "MFA Logs",
            initialX: 10,
            initialY: 10,
            initialWidth: 300,
            initialHeight: 100,
            child: MfaLogsWidget(),
          ),
        ],
      ),
    );
  }
}
