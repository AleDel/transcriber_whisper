import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:flutter/gestures.dart';
import 'package:transcriber_whisper/transcription_widget_abstract.dart';

class SlidingText extends TranscriptionWidget {
  final Function(Duration, int) onSeek;
  const SlidingText({
    Key? key,
    required this.onSeek,
  }) : super(key: key);

  @override
  _SlidingTextState createState() => _SlidingTextState();
}

class _SlidingTextState extends TranscriptionWidgetState<SlidingText> {
  // NEW: Create a ScrollController here
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentWord();
    });
  }



  @override
  void didUpdateWidget(covariant SlidingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentWord();
    });
  }

  @override
  void dispose() {
    // NEW: Dispose the ScrollController
    _scrollController.dispose();
    super.dispose();
  }


@override
  void scrollToCurrentWord() {
    if (!internalAutoScrollEnabled) return;
    final sessionCubit = context.read<SessionCubit>();
    final sessionState = sessionCubit.state;
    // MODIFIED: Use the local _scrollController
    final scrollController = _scrollController;
    //final scrollController = sessionState.sessionData!.scrollController;

    if (currentWordIndex == -1 || sessionState.sessionData?.transcription?.segments.isEmpty == true || !scrollController.hasClients) {
      return;
    }

    final index = currentWordIndex;
    final segments = sessionState.sessionData!.transcription!.segments;
    final totalDuration = segments.last.end;
    final totalTextWidth = (totalDuration / 1) * 200;

    final currentWordStart = segments[index].start;
    final currentWordEnd = segments[index].end;
    final currentWordPosition = (currentWordStart / totalDuration) * totalTextWidth;
    final currentWordWidth = ((currentWordEnd - currentWordStart) / totalDuration) * totalTextWidth;
    final currentWordCenter = currentWordPosition + (currentWordWidth / 2);

    final viewportWidth = scrollController.position.viewportDimension;
    final scrollOffset = currentWordCenter - (viewportWidth / 2);

    if (scrollOffset > 0) {
      scrollController.animateTo(scrollOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      //buildWhen: (previous, current) => previous.sessionData != current.sessionData,
      builder: (context, sessionState) {
        final currentSession = sessionState.sessionData;
        if (currentSession == null) {
          return const SizedBox.shrink();
        }
        if (currentSession.transcription == null || currentSession.transcription!.segments.isEmpty) {
          return Container();
        }
        final segments = currentSession.transcription!.segments;
        double totalDuration = segments.last.end;
        double totalTextWidth = (totalDuration / 1) * 200;
        // Obtener el ancho de la pantalla
        double screenWidth = MediaQuery.of(context).size.width;
        // Definir un ancho máximo
        double maxWaveformWidth = 1000;
        // Calcular el ancho final
        double waveformWidth = screenWidth < maxWaveformWidth ? screenWidth : maxWaveformWidth;
        // Calcular la posición del rectángulo
        // MODIFIED: Use the local _scrollController
        //double scrollOffset = sessionState.sessionData!.scrollController.hasClients == true ? sessionState.sessionData!.scrollController.offset : 0;
        double scrollOffset = _scrollController.hasClients == true ? _scrollController.offset : 0;
        double rectanglePosition = scrollOffset;
        double audioPosition = (currentSession.audioPosition.inMilliseconds / (totalDuration * 1000)) * totalTextWidth;
        double rectangleAudioPosition = (audioPosition / totalTextWidth) * waveformWidth;
        return Column(
          children: [
            // Fondo con la imagen de la forma de onda
            if (currentSession.waveformImage != null)
              Stack(
                children: [
                  Container(
                    width: waveformWidth,
                    height: 30, // Altura fija de 30
                    color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.5),
                    child: Image.memory(
                      base64Decode(currentSession.waveformImage!),
                      gaplessPlayback: true,
                      fit: BoxFit.fill,
                      isAntiAlias: true,
                    ),
                  ),
                  Positioned(
                    left: rectangleAudioPosition,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 30,
                      color: Colors.red.withOpacity(0.5),
                    ),
                  ),
                  Positioned(
                    left: rectanglePosition,
                    top: 0,
                    child: Container(
                      width: waveformWidth,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                  ),
                ],
              ),
            // MODIFIED: Use the local _scrollController
            SingleChildScrollView(
              //controller: sessionState.sessionData?.scrollController,
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: totalTextWidth,
                    height: 60, // Altura fija
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                    child: Stack(
                      children: [
                        // Barra de progreso
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            width: totalTextWidth * (currentSession.audioPosition.inMilliseconds / (totalDuration * 1000)),
                            height: 60, // Altura fija de 30
                            color: Colors.blue.withOpacity(0.5),
                          ),
                        ),

                        // Palabras
                        ...segments.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final wordData = entry.value;
                          double wordStart = wordData.start;
                          double wordEnd = wordData.end;
                          double wordPosition = (wordStart / totalDuration) * totalTextWidth;
                          double wordWidth = ((wordEnd - wordStart) / totalDuration) * totalTextWidth;

                          // Calcular el color de fondo en función de la probabilidad

                          Color backgroundColor = getBackgroundColor(wordData.probability);
                          Color tagColor = getMixedTagColor(wordData.tags);
                          return Positioned(
                            left: wordPosition,
                            top: 0,
                            height: 60,
                            child: Listener(
                              onPointerDown: (event) {
                                if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
                                  // Clic secundario (clic derecho)
                                  showContextMenu(event.position, wordIndexes: [index]);
                                }
                              },
                              child: GestureDetector(
                                onTap: () {
                                  onWordTap(index);
                                },
                                onLongPressStart: (details) {
                                  showContextMenu(details.globalPosition, wordIndexes: [index]);
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: wordWidth,
                                        color: wordData.tags.isEmpty ? Colors.transparent : tagColor.withOpacity(0.5),
                                        alignment: Alignment.center,
                                        child: Text(
                                          wordData.word,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: index == currentWordIndex ? Colors.blue : Colors.black,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    //probabilidad
                                    Container(
                                      width: wordWidth,
                                      color: backgroundColor,
                                      child: Text("${wordData.probability.toStringAsFixed(2)}", textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
