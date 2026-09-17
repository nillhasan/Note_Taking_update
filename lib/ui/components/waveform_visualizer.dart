import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class WaveformVisualizer extends StatelessWidget {
  final List<double> amplitudes;
  final double height;
  final Color? barColor;
  final Color? waveColor;
  final bool isRecording;

  const WaveformVisualizer({
    super.key,
    required this.amplitudes,
    this.height = 80,
    this.barColor,
    this.waveColor,
    this.isRecording = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          amplitudes: amplitudes,
          color: waveColor ?? barColor ?? AppColors.accentDark,
          isRecording: isRecording,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final bool isRecording;

  _WaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) {
      final idlePaint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        idlePaint,
      );
      return;
    }

    const barWidth = 3.5;
    const barSpacing = 3.5;
    final totalBarWidth = barWidth + barSpacing;
    final maxBars = (size.width / totalBarWidth).floor();

    final visibleAmplitudes = amplitudes.length > maxBars
        ? amplitudes.sublist(amplitudes.length - maxBars)
        : amplitudes;

    final paint = Paint()
      ..color = isRecording ? color : color.withValues(alpha: 0.4)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    double startX = size.width - (visibleAmplitudes.length * totalBarWidth);
    if (startX < 0) startX = 0;

    final centerY = size.height / 2;

    for (int i = 0; i < visibleAmplitudes.length; i++) {
      final amp = visibleAmplitudes[i].clamp(0.06, 1.0);
      final barHeight = (size.height * amp * 0.95).clamp(4.0, size.height);
      final x = startX + (i * totalBarWidth) + (barWidth / 2);

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes || oldDelegate.isRecording != isRecording;
  }
}
