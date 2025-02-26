import 'package:flutter/material.dart';

class MelSpectrogramPainter extends CustomPainter {
  final List<List<double>> melSpectrogramData;
  final double totalDuration;
  final double totalTextWidth;

  MelSpectrogramPainter({
    required this.melSpectrogramData,
    required this.totalDuration,
    required this.totalTextWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (melSpectrogramData.isEmpty) return;

    // Normalize the data to 0-1 range
    double maxVal = melSpectrogramData.expand((row) => row).reduce((a, b) => a > b ? a : b);
    double minVal = melSpectrogramData.expand((row) => row).reduce((a, b) => a < b ? a : b);

    // Calculate the number of time frames and frequency bins
    int numTimeFrames = melSpectrogramData.length;
    int numFreqBins = melSpectrogramData[0].length;

    // Calculate the width of each time frame
    double timeFrameWidth = totalTextWidth / numTimeFrames;

    // Calculate the height of each frequency bin
    double freqBinHeight = size.height / numFreqBins;

    // Iterate over the Mel spectrogram data
    for (int i = 0; i < numTimeFrames; i++) {
      for (int j = 0; j < numFreqBins; j++) {
        // Normalize the value to 0-1
        double normalizedValue = (melSpectrogramData[i][j] - minVal) / (maxVal - minVal);

        // Calculate the color based on the normalized value
        Color color = Color.lerp(Colors.black, Colors.white, normalizedValue)!;

        // Create a paint object with the calculated color
        Paint paint = Paint()..color = color;

        // Calculate the position and size of the rectangle
        double rectLeft = i * timeFrameWidth;
        double rectTop = size.height - (j + 1) * freqBinHeight;
        double rectWidth = timeFrameWidth;
        double rectHeight = freqBinHeight;

        // Draw the rectangle
        canvas.drawRect(Rect.fromLTWH(rectLeft, rectTop, rectWidth, rectHeight), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
