import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SizedBox(
          height: 200,
          width: 200,
          child: Stack(
            children: [
              Center(
                child: LoadingAnimationWidget.progressiveDots(
                  color: Colors.red,
                  size: 100,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
