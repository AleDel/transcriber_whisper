import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart'; // Asegúrate de importar tu TranscribeCubit

class MfaLogsWidget extends StatefulWidget {
  const MfaLogsWidget({Key? key}) : super(key: key);

  @override
  State<MfaLogsWidget> createState() => _MfaLogsWidgetState();
}

class _MfaLogsWidgetState extends State<MfaLogsWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Escuchar los cambios en la lista logs_mfa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      /*_scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );*/
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TranscribeCubit, TranscribeState>(
      listener: (context, state) {
        // Escuchar los cambios en la lista logs_mfa
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      },
      builder: (context, state) {
        if (state.logs_mfa == null || state.logs_mfa!.isEmpty) {
          return const Center(child: Text('No hay logs de MFA disponibles.'));
        } else {
          return Container(
            color: Colors.grey[200], // Fondo gris claro para el contenedor
            child: ListView.builder(
              controller: _scrollController,
              itemCount: state.logs_mfa!.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 0.0,
                  ), // Añade un pequeño padding horizontal y vertical
                  child: Text(
                    state.logs_mfa![index],
                    style: const TextStyle(
                      fontSize: 12, // Letra más pequeña
                      color: Colors.blue, // Letra azul
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}
