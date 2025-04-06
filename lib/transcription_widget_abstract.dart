import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/widgets/segmentEditor_widget.dart';

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

  //
  Map<String, Color> get _availableTags => TranscriptionCubit.availableTags;
  bool _tagSelected = false;
  List<int> _selectedIndexes = [];
  //

  @override
  void initState() {
    super.initState();
    internalAutoScrollEnabled = widget.autoScrollEnabled;
  }

  void setAutoScroll(bool value) {
    setState(() {
      internalAutoScrollEnabled = value;
    });
    getIt<TranscriptionCubit>().setAutoScroll(value);
    if (widget.onAutoScrollChanged != null) {
      widget.onAutoScrollChanged!(value);
    }
  }

  /*void showContextMenu(BuildContext context, Offset position, List<int> selectedIndexes) {
    getIt<TranscribeCubit>().showContextMenu(context, position, selectedIndexes);
  }*/

  /////// nuevo
  List<String> _getSelectedTags() {
    if (_selectedIndexes.isEmpty) {
      return [];
    }
    List<String> tags = [];
    final sessionCubit = getIt<TranscriptionCubit>();
    if (sessionCubit.state.transcription == null) return [];
    for (int i in _selectedIndexes) {
      if (i >= 0 && i < sessionCubit.state.transcription!.rawReferenceTextSegments!.length) {
        tags.addAll(sessionCubit.state.transcription!.rawReferenceTextSegments![i].tags);
      }
    }
    return tags.toSet().toList();
  }

  void showContextMenu(Offset position, {List<int>? wordIndexes}) async {
    _tagSelected = false;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    if (wordIndexes != null) {
      _selectedIndexes = wordIndexes;
    }
    final List<String> selectedTags = _getSelectedTags();
    await showMenu(
      context: context,
      position: RelativeRect.fromRect(position & const Size(40, 40), Offset.zero & overlay.size),
      items: <PopupMenuEntry>[
        /*PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar'),
          ),
          onTap: () {
            if (_selectedIndexes.isNotEmpty) {
              if (_selectedIndexes.length == 1) {
                _editSegment(context, _selectedIndexes.first);
              } else {
                _editSegments(context, _selectedIndexes);
              }
            }
          },
        ),*/
        /*PopupMenuItem(
          child:  Text('"${getIt<Transcription>().transsegments[_selectedIndexes.first].word}"'),
        ),*/
        const PopupMenuDivider(),
        PopupMenuItem(
          child: const Text('Seleccionar'),
          onTap: () {
            if (wordIndexes != null) {
              setState(() {
                _selectedIndexes.addAll(wordIndexes);
              });
            }
          },
        ),
        PopupMenuItem(
          child: const Text('Des-Seleccionar'),
          onTap: () {
            if (wordIndexes != null) {
              setState(() {
                _selectedIndexes.removeWhere((element) => wordIndexes.contains(element));
              });
            }
          },
        ),
        const PopupMenuDivider(),
        if (_selectedIndexes.isNotEmpty)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(leading: const Icon(Icons.delete), title: const Text('Eliminar')),
            onTap: () {
              if (_selectedIndexes.isNotEmpty) {
                for (int index in _selectedIndexes) {
                  getIt<TranscriptionCubit>().deleteSegment(index);
                }
              }
            },
          ),
        ..._availableTags.entries.map((entry) {
          final String tag = entry.key;
          final String symbol = TranscriptionCubit.tagToSymbol[tag] ?? tag;
          final Color color = entry.value;
          final bool isSelected = selectedTags.contains(tag);
          return PopupMenuItem<String>(
            value: tag,
            child: ListTile(leading: Icon(Icons.tag, color: color), title: Text(symbol), trailing: isSelected ? const Icon(Icons.check) : null),
            onTap: () {
              _tagSelected = true;
              if (isSelected) {
                _removeTagFromSelection(tag);
              } else {
                _applyTagToSelection(tag);
              }
              setState(() {});
            },
          );
        }).toList(),
      ],
    );
    if (!_tagSelected) {
      setState(() {
        _selectedIndexes = [];
      });
    }
  }

  void _editSegment(BuildContext context, int index) {
    final sessionCubit = getIt<TranscriptionCubit>();
    if (sessionCubit.state.transcription == null) return;
    final segment = sessionCubit.state.transcription!.rawReferenceTextSegments![index];
    showDialog(
      context: context,
      builder: (context) {
        return SegmentEditor(
          segment: segment,
          onSave: (newSegment) {
            getIt<TranscriptionCubit>().editSegment(newSegment);
          },
        );
      },
    );
  }

  void _applyTagToSelection(String tag) {
    final transcriberCubit = getIt<TranscriptionCubit>();
    if (transcriberCubit.state.transcription == null) return;
    if (_selectedIndexes.isEmpty) {
      return;
    }
    for (int i in _selectedIndexes) {
      if (i >= 0 && i < transcriberCubit.state.transcription!.rawReferenceTextSegments!.length) {
        transcriberCubit.addTagToSegment(i, tag);
      }
    }
    setState(() {
      _selectedIndexes.clear();
    });
  }

  void _removeTagFromSelection(String tag) {
    final sessionCubit = getIt<TranscriptionCubit>();
    if (sessionCubit.state.transcription == null) return;
    if (_selectedIndexes.isEmpty) {
      return;
    }
    for (int i in _selectedIndexes) {
      if (i >= 0 && i < sessionCubit.state.transcription!.rawReferenceTextSegments!.length) {
        sessionCubit.removeTagFromSegment(i, tag);
      }
    }
    setState(() {});
  }

  /////// fin nuevo

  Color getMixedTagColor(List<String> tags) {
    if (tags.isEmpty) {
      //return Colors.transparent;
      return Colors.white;
    }

    if (tags.length == 1) {
      return TranscriptionCubit.availableTags[tags.first] ?? Colors.transparent;
    }

    List<Color> tagColors = tags.map((tag) => TranscriptionCubit.availableTags[tag] ?? Colors.transparent).toList();
    return mixMultipleColors(tagColors);
  }

  Color mixMultipleColors(List<Color> colors) {
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
