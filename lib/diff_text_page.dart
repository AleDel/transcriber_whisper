import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/widgets/audioPlayer_widget.dart';
import 'package:transcriber_whisper/widgets/highlighted_real_text_widget.dart';
import 'package:transcriber_whisper/widgets/loadingWidget.dart';
import 'package:transcriber_whisper/widgets/sliding_text_widget.dart';


class DiffTextPage extends StatefulWidget {
  const DiffTextPage({super.key});

  @override
  State<DiffTextPage> createState() => _DiffTextPageState();
}

class _DiffTextPageState extends State<DiffTextPage> {
  final ScrollController _scrollController = ScrollController();
  GetIt getIt = GetIt.instance;

  @override
  void initState() {
    super.initState();
    /*WidgetsBinding.instance.addPostFrameCallback((_) {
      //getIt<TranscriptionCubit>().restartAudioPlayer();
      getIt<TranscriptionCubit>().useMockTranscriptionEU();
    });*/
  }

  @override
  void dispose() {
    _scrollController.dispose();
    getIt<TranscriptionCubit>().stopAudioPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Diff Text Page')),
      body: Stack(
        children: [
          BlocBuilder<TranscriptionCubit, TranscriptionState>(
            builder: (context, state) {
              print("state.status ---------------------> ${state.status}");
              if (state.status == TranscriptionStatus.error) {
                return const Center(child: Text('Error al transcribir el audio'));
              }
              if (state.status == TranscriptionStatus.noserver) {
                return const Center(child: Text('No se pudo conectar con el servidor'));
              }
              if (state.status == TranscriptionStatus.loading) {
                //return Center(child: CircularProgressIndicator());
                //return LoadingWidget();
                return LoadingAnimationWidget.hexagonDots(color: Colors.red, size: 100);
              }
              return Column(
                // Eliminado Center y añadido Column
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // botones transcribir, etc
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        //ElevatedButton(onPressed: () async => getIt<TranscriptionCubit>().pickAudioFile(), child: const Text('Cargar Audio')),
                        //ElevatedButton(onPressed: () async => getIt<TranscriptionCubit>().useMockTranscriptionEU(), child: const Text('Usar Mock data')),
                        ElevatedButton(onPressed: () async => getIt<TranscriptionCubit>().useMockTranscriptionES(), child: const Text('Usar Mock data Es')),
                        ElevatedButton(onPressed: () async => getIt<TranscriptionCubit>().useMockTranscriptionEU(), child: const Text('Usar Mock data Eu')),
                      ],
                    ),
                  ),
                  // interfaz grafica principal
                  if (state.transcription != null)
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 60,
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: SlidingText(
                                      transcription: state.transcription!,
                                      audioPosition: state.extradata!.audioPosition,
                                      currentWordIndex: state.extradata!.currentWordIndex,
                                      waveformImageBase64: state.waveformImageBase64,
                                      scrollController: _scrollController,
                                      onWordTap: (index) {
                                        getIt<TranscriptionCubit>().forceCurrentWord(index);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              //Expanded(child: SizedBox(height: 60, child: AudioPlayerWidget())),
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: HighlightedRealTextWidget(
                                currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                                onWordTap: (index) {
                                  getIt<TranscriptionCubit>().forceCurrentWord(index);
                                },
                                transcription: state.transcription!,
                                audioPosition: state.extradata!.audioPosition,
                                scrollController: ScrollController(),
                                onShowAssociatedWordsChanged: (bool value) {},
                                onShowOnlyDifferentWordsChanged: (bool value) {},
                                onHighlightDifferencesChanged: (bool value) {},
                                onHighlightDeletedWordsChanged: (bool value) {},
                                onShowOnlyInsertionsChanged: (bool value) {},
                                onShowInsertionsAndDeletionsWithArrowsChanged: (bool value) {},
                                onShowCoincidencePunctuationAndDeletedChanged: (bool value) {},
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          //FloatingWindow(title: "MFA Logs", initialX: 10, initialY: 10, initialWidth: 300, initialHeight: 100, child: MfaLogsWidget()),
        ],
      ),
    );
  }
}