import 'package:flutter/material.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';

class SegmentContextMenu extends StatefulWidget {
  final List<String> availableTags;
  final List<String> selectedTags;
  final bool editMode;
  final Function(String) onTagAdded;
  final Function(String) onTagRemoved;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<int> selectedIndexes;

  const SegmentContextMenu({
    Key? key,
    required this.availableTags,
    required this.selectedTags,
    required this.editMode,
    required this.onTagAdded,
    required this.onTagRemoved,
    required this.onEdit,
    required this.onDelete,
    required this.selectedIndexes,
  }) : super(key: key);

  @override
  State<SegmentContextMenu> createState() => _SegmentContextMenuState();
}

class _SegmentContextMenuState extends State<SegmentContextMenu> {
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.selectedTags);
  }

  @override
  void didUpdateWidget(covariant SegmentContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTags != oldWidget.selectedTags) {
      setState(() {
        _selectedTags = List.from(widget.selectedTags);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.editMode) ...[
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar'),
            onTap: widget.onEdit,
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Eliminar'),
            onTap: widget.onDelete,
          ),
        ],
        ...widget.availableTags.map((tag) {
          return CheckboxListTile(
            title: Text(tag),
            value: _selectedTags.contains(tag),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedTags.add(tag);
                  if (widget.selectedIndexes.isNotEmpty) {
                    for (int index in widget.selectedIndexes) {
                      widget.onTagAdded(tag);
                    }
                  } else {
                    widget.onTagAdded(tag);
                  }
                } else {
                  _selectedTags.remove(tag);
                  if (widget.selectedIndexes.isNotEmpty) {
                    for (int index in widget.selectedIndexes) {
                      widget.onTagRemoved(tag);
                    }
                  } else {
                    widget.onTagRemoved(tag);
                  }
                }
              });
            },
            activeColor: TranscribeCubit.availableTags[tag],
            checkColor: Colors.white,
            tileColor: _selectedTags.contains(tag) ? TranscribeCubit.availableTags[tag]?.withOpacity(0.5) : null,
          );
        }).toList(),
      ],
    );
  }
}