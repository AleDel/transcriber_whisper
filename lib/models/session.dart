import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

enum SessionStatus {
  pending,
  processingAudio,
  transcribing,
  completed,
  error,
}

class Session extends Equatable {
  final String id;
  final String audioFilename;
  final String? originalText;
  final Transcription? transcription;
  final SessionStatus status;
  final PlatformFile? platformFile;

  const Session({
    required this.id,
    required this.audioFilename,
    this.originalText,
    this.transcription,
    this.status = SessionStatus.pending,
    this.platformFile,
  });

  Session copyWith({
    String? id,
    String? audioFilename,
    String? originalText,
    Transcription? transcription,
    SessionStatus? status,
    PlatformFile? platformFile,
  }) {
    return Session(
      id: id ?? this.id,
      audioFilename: audioFilename ?? this.audioFilename,
      originalText: originalText ?? this.originalText,
      transcription: transcription ?? this.transcription,
      status: status ?? this.status,
      platformFile: platformFile ?? this.platformFile,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audioFilename': audioFilename,
      'originalText': originalText,
      'transcription': transcription?.toListMap(),
      'status': status.index,
      'platformFile': platformFile?.toMap(),
    };
  }

  static Session fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      audioFilename: map['audioFilename'] as String,
      originalText: map['originalText'] as String?,
      transcription: map['transcription'] != null ? Transcription.fromListMap(List<Map<String, dynamic>>.from(map['transcription'])) : null,
      status: SessionStatus.values[map['status'] as int],
      platformFile: map['platformFile'] != null ? PlatformFile.fromMap(map['platformFile']) : null,
    );
  }

  @override
  List<Object?> get props => [id, audioFilename, originalText, transcription, status, platformFile];
}
extension PlatformFileExtension on PlatformFile {
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'bytes': bytes,
      'path': path,
      'size': size,
    };
  }

  static PlatformFile fromMap(Map<String, dynamic> map) {
    return PlatformFile(
      name: map['name'] as String,
      bytes: map['bytes'] != null ? Uint8List.fromList(List<int>.from(map['bytes'])) : null,
      path: map['path'] as String?,
      size: map['size'] as int,
    );
  }
}