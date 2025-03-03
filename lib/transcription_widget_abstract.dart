import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
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
  List<int> _selectedIndexes = [];
  bool _tagSelected = false;
  Map<String, Color> get _availableTags => TranscribeCubit.availableTags;

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

  List<String> _getSelectedTags() {
    if (_selectedIndexes.isEmpty) {
      return [];
    }
    List<String> tags = [];
    for (int i in _selectedIndexes) {
      tags.addAll(widget.transcription.segments[i].tags);
    }
    return tags.toSet().toList();
  }

  void _applyTagToSelection(String tag) {
    if (_selectedIndexes.isEmpty) {
      return;
    }
    for (int i in _selectedIndexes) {
      if (!widget.transcription.segments[i].tags.contains(tag)) {
        widget.transcription.segments[i].tags.add(tag);
      }
    }
    getIt<TranscribeCubit>().updateTranscription(widget.transcription);
    setState(() {

    });
  }

  void _removeTagFromSelection(String tag) {
    if (_selectedIndexes.isEmpty) {
      return;
    }
    for (int i in _selectedIndexes) {
      widget.transcription.segments[i].tags.remove(tag);
    }
    getIt<TranscribeCubit>().updateTranscription(widget.transcription);
    setState(() {

    });
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
      items: [
        PopupMenuItem(
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
        ),
        if (_selectedIndexes.isNotEmpty)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Eliminar'),
            ),
            onTap: () {
              if (_selectedIndexes.isNotEmpty) {
                for (int index in _selectedIndexes) {
                  getIt<TranscribeCubit>().deleteSegment(index);
                }
              }
            },
          ),
        ..._availableTags.entries.map((entry) {
          final String tag = entry.key;
          final Color color = entry.value;
          final bool isSelected = selectedTags.contains(tag);
          return PopupMenuItem<String>(
            value: tag,
            child: CheckboxListTile(
              title: Text(tag),
              activeColor: color,
              value: isSelected,
              onChanged: (bool? newValue) {
                _tagSelected = true;
                if (newValue == true) {
                  _applyTagToSelection(tag);
                } else {
                  _removeTagFromSelection(tag);
                }
                Navigator.pop(context);
              },
            ),
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
    final segment = widget.transcription.segments[index];
    showDialog(
      context: context,
      builder: (context) {
        return SegmentEditor(
          segment: segment,
          onSave: (newSegment) {
            getIt<TranscribeCubit>().editSegment(newSegment);
          },
        );
      },
    );
  }

  void _editSegments(BuildContext context, List<int> indexes) {
    if (indexes.isEmpty) return;
    String newText = widget.transcription.segments[indexes.first].word;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Segmentos'),
          content: TextField(
            controller: TextEditingController(text: newText),
            onChanged: (value) {
              newText = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                getIt<TranscribeCubit>().editSegments(indexes, newText);
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
