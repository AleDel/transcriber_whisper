import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';

class AudioFileInfo extends Equatable {
  final PlatformFile file;
  final Duration? duration;

  const AudioFileInfo({required this.file, this.duration});

  AudioFileInfo copyWith({
    PlatformFile? file,
    Duration? duration,
  }) {
    return AudioFileInfo(
      file: file ?? this.file,
      duration: duration ?? this.duration,
    );
  }

  @override
  List<Object?> get props => [file, duration];
}