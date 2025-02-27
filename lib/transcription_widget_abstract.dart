import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';

abstract class TranscriptionWidget extends StatefulWidget {
  final Transcription transcription;
  final Duration audioPosition;
  final int currentWordIndex;
  final Function(int) onWordTap;
  final bool autoScrollEnabled;
  final ValueChanged<bool>? onAutoScrollChanged;

  const TranscriptionWidget({
    Key? key,
    required this.transcription,
    required this.audioPosition,
    required this.currentWordIndex,
    required this.onWordTap,
    this.autoScrollEnabled = true,
    this.onAutoScrollChanged,
  }) : super(key: key);
}

abstract class TranscriptionWidgetState<T extends TranscriptionWidget> extends State<T> {
  bool internalAutoScrollEnabled = true;
  final GetIt getIt = GetIt.instance;

  @override
  void initState() {
    super.initState();
    internalAutoScrollEnabled = widget.autoScrollEnabled;
  }

  void setAutoScroll(bool value) {
    setState(() {
      internalAutoScrollEnabled = value;
    });
    getIt<TranscribeCubit>().setAutoScroll(value);
    if (widget.onAutoScrollChanged != null) {
      widget.onAutoScrollChanged!(value);
    }
  }

  void showContextMenu(BuildContext context, Offset position, List<int> selectedIndexes) {
    getIt<TranscribeCubit>().showContextMenu(context, position, selectedIndexes);
  }

  Color getMixedTagColor(List<String> tags) {
    if (tags.isEmpty) {
      return Colors.transparent;
    }

    if (tags.length == 1) {
      return TranscribeCubit.availableTags[tags.first] ?? Colors.transparent;
    }

    List<Color> tagColors = tags.map((tag) => TranscribeCubit.availableTags[tag] ?? Colors.transparent).toList();
    return _mixMultipleColors(tagColors);
  }

  Color _mixMultipleColors(List<Color> colors) {
    if (colors.isEmpty) {
      return Colors.transparent;
    }

    if (colors.length == 1) {
      return colors.first;
    }

    int totalRed = 0;
    int totalGreen = 0;
    int totalBlue = 0;

    for (Color color in colors) {
      totalRed += color.red;
      totalGreen += color.green;
      totalBlue += color.blue;
    }

    return Color.fromARGB(255, totalRed ~/ colors.length, totalGreen ~/ colors.length, totalBlue ~/ colors.length);
  }

  Color getBackgroundColor(double probability) {
    const Color colorLow = Colors.red;
    const Color colorHigh = Colors.green;
    probability = probability.clamp(0.0, 1.0);
    return Color.lerp(colorLow, colorHigh, probability)!;
  }
  void scrollToCurrentWord();
}