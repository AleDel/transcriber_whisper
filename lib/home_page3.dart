import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/widgets/floatingWindow_widget.dart';
import 'package:transcriber_whisper/widgets/mfaLogs_widget.dart';
import 'package:transcriber_whisper/widgets/slider_widget.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/widgets/vertical_widget.dart';
import 'package:transcriber_whisper/widgets/selectableRichText_widget.dart';
import 'package:flutter_audio_waveforms/flutter_audio_waveforms.dart'; // Import the package

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GetIt getIt = GetIt.instance;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Audio Transcriber')),
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
                    //Text("estado: ${state.status.name}"),
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () async => getIt<TranscribeCubit>().pickAudioFile(),
                          child: const Text('Pick Audio File'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async => getIt<TranscribeCubit>().useFakeTranscription(),
                          child: const Text('Use Test'),
                        ),
                      ],
                    ),
                    //SizedBox(height: 100, child: MfaLogsWidget()), // Lo quitamos de aquí
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  state.status == TranscribeStatus.isPlayerplaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                                onPressed: () {
                                  if (state.status == TranscribeStatus.isPlayerplaying) {
                                    getIt<TranscribeCubit>().audioPlayer.pause();
                                  } else {
                                    getIt<TranscribeCubit>().audioPlayer.resume();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.reply_all_rounded),
                                onPressed: () {
                                  getIt<TranscribeCubit>().audioPlayer.seek(
                                    const Duration(seconds: 0),
                                  );
                                },
                              ),
                              Text(
                                '${state.extradata?.audioPosition.toString().split('.').first ?? "0:00"} / ${state.extradata?.audioDuration.toString().split('.').first ?? "0:00"}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          state.transcription != null
                              ? Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 0,
                                      child: SingleChildScrollView(
                                        controller: getIt<TranscribeCubit>().scrollController,
                                        scrollDirection: Axis.horizontal,
                                        child: SlidingText(
                                          key: const Key('slider-text'),
                                          transcription: state.transcription!,
                                          audioPosition:
                                              state.extradata?.audioPosition ?? Duration.zero,
                                          currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                                          //waveformImageBase64: state.waveformImageBase64,
                                          scrollController:
                                              getIt<TranscribeCubit>().scrollController,
                                          onWordTap: (index) {
                                            getIt<TranscribeCubit>().forceCurrentWord(index);
                                          },
                                          onAutoScrollChanged: (value) {
                                            getIt<TranscribeCubit>().setAutoScroll(value);
                                          },
                                          autoScrollEnabled: true,
                                        ),
                                      ),
                                    ),
                                    /*Expanded(
                                      child: SizedBox(
                                        height: 100,
                                        //width: 1000,
                                        child:
                                        //state.waveformImageBase64 != null ?
                                        Image.memory(
                                          base64Decode(state.waveformImageBase64!),
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                          isAntiAlias: true,
                                        ),
                                        //    : Container(),
                                      ),
                                    ),*/
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: VerticalTranscription(
                                              transcription: state.transcription!,
                                              audioPosition:
                                                  state.extradata?.audioPosition ?? Duration.zero,
                                              currentWordIndex:
                                                  state.extradata?.currentWordIndex ?? -1,
                                              onSeek: (Duration d, int indexword) {
                                                getIt<TranscribeCubit>().audioPlayer.seek(
                                                  d,
                                                ); //se hace el seek
                                                getIt<TranscribeCubit>().forceCurrentWord(
                                                  indexword,
                                                );
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: SelectableRichText(
                                              segments: state.transcription!.segments,
                                              currentWordIndex:
                                                  state.extradata?.currentWordIndex ?? -1,
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
                    ),
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
