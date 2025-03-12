import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/widgets/segmentEditor_widget.dart';

abstract class TranscriptionWidget extends StatefulWidget {
  const TranscriptionWidget({Key? key}) : super(key: key);

  @override
  TranscriptionWidgetState createState();
}

abstract class TranscriptionWidgetState<T extends TranscriptionWidget> extends State<T> {
  bool internalAutoScrollEnabled = true;
  final GetIt getIt = GetIt.instance;
  List<int> _selectedIndexes = [];
  bool _tagSelected = false;
  Map<String, Color> get _availableTags => SessionCubit.availableTags;
  //TODO Comprovar que esto esta llegando -------------->>>>>>
  Duration get audioPosition => getIt<SessionCubit>().state.sessionData?.audioPosition ?? const Duration(seconds: 0);
  int get currentWordIndex => getIt<SessionCubit>().state.sessionData?.currentWordIndex ?? -1;
  Function(int) get onWordTap => (int index) => getIt<SessionCubit>().forceCurrentWord(index);
  bool get autoScrollEnabled => getIt<SessionCubit>().state.sessionData?.autoScrollEnabled ?? false;
  ValueChanged<bool>? get onAutoScrollChanged => (bool value) => getIt<SessionCubit>().setAutoScroll(value);

  @override
  void initState() {
    super.initState();
    internalAutoScrollEnabled = autoScrollEnabled;
  }

  void setAutoScroll(bool value) {
    setState(() {
      internalAutoScrollEnabled = value;
    });
    getIt<SessionCubit>().setAutoScroll(value);
    if (onAutoScrollChanged != null) {
      onAutoScrollChanged!(value);
    }
  }

  Color getMixedTagColor(List<String> tags) {
    if (tags.isEmpty) {
      return Colors.transparent;
    }

    if (tags.length == 1) {
      return SessionCubit.availableTags[tags.first] ?? Colors.transparent;
    }

    List<Color> tagColors = tags.map((tag) => SessionCubit.availableTags[tag] ?? Colors.transparent).toList();
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
    final sessionCubit = getIt<SessionCubit>();
    if (sessionCubit.state.sessionData == null || sessionCubit.state.sessionData!.transcription == null) return [];
    for (int i in _selectedIndexes) {
      if (i >= 0 && i < sessionCubit.state.sessionData!.transcription!.segments.length) {
        tags.addAll(sessionCubit.state.sessionData!.transcription!.segments[i].tags);
      }
    }
    return tags.toSet().toList();
  }

  void _applyTagToSelection(String tag) {
    final sessionCubit = getIt<SessionCubit>();
    if (sessionCubit.state.sessionData == null || sessionCubit.state.sessionData!.transcription == null) return;
    if (_selectedIndexes.isEmpty) {
      return;
    }
    for (int i in _selectedIndexes) {
      if (i >= 0 && i < sessionCubit.state.sessionData!.transcription!.segments.length) {
        sessionCubit.addTagToSegment(sessionCubit.state.sessionData!, i, tag);
      }
    }
    setState(() {
      _selectedIndexes.clear();
    });
  }

  void _removeTagFromSelection(String tag) {
    final sessionCubit = getIt<SessionCubit>();
    if (sessionCubit.state.sessionData == null || sessionCubit.state.sessionData!.transcription == null) return;
    if (_selectedIndexes.isEmpty) {
      return;
    }
    for (int i in _selectedIndexes) {
      if (i >= 0 && i < sessionCubit.state.sessionData!.transcription!.segments.length) {
        sessionCubit.removeTagFromSegment(sessionCubit.state.sessionData!, i, tag);
      }
    }
    setState(() {});
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
            child: ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Eliminar'),
            ),
            onTap: () {
              if (_selectedIndexes.isNotEmpty) {
                for (int index in _selectedIndexes) {
                  getIt<SessionCubit>().deleteSegment(index);
                }
              }
            },
          ),
        ..._availableTags.entries.map((entry) {
          final String tag = entry.key;
          final String symbol = SessionCubit.tagToSymbol[tag] ?? tag;
          final Color color = entry.value;
          final bool isSelected = selectedTags.contains(tag);
          return PopupMenuItem<String>(
            value: tag,
            child: ListTile(
              leading: Icon(Icons.tag, color: color),
              title: Text(symbol),
              trailing: isSelected ? const Icon(Icons.check) : null,
            ),
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
    if (!_tagSelected) {setState(() {
      _selectedIndexes = [];
    });
    }
  }

  void _editSegment(BuildContext context, int index) {
    final sessionCubit = getIt<SessionCubit>();
    if (sessionCubit.state.sessionData == null || sessionCubit.state.sessionData!.transcription == null) return;
    final segment = sessionCubit.state.sessionData!.transcription!.segments[index];
    showDialog(
      context: context,
      builder: (context) {
        return SegmentEditor(
          segment: segment,
          onSave: (newSegment) {
            getIt<SessionCubit>().editSegment(sessionCubit.state.sessionData!, newSegment);
          },
        );
      },
    );
  }

  void _editSegments(BuildContext context, List<int> indexes) {
    final sessionCubit = getIt<SessionCubit>();
    if (sessionCubit.state.sessionData == null || sessionCubit.state.sessionData!.transcription == null) return;
    if (indexes.isEmpty) return;
    String newText = sessionCubit.state.sessionData!.transcription!.segments[indexes.first].word;
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
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                getIt<SessionCubit>().editSegments(indexes, newText);
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}