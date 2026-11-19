import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate icons from canvas', () async {
    final sizes = [16, 32, 48, 64, 72, 96, 128, 144, 192, 256];
    for (final size in sizes) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      );

      final paintBg = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(size.toDouble(), size.toDouble()),
          [const Color(0xFF0F172A), const Color(0xFF020617)],
        );

      final scale = size / 512.0;
      final path = Path();
      path.moveTo(256 * scale, 24 * scale);
      path.lineTo(448 * scale, 104 * scale);
      path.lineTo(448 * scale, 328 * scale);
      path.cubicTo(
        448 * scale,
        408 * scale,
        360 * scale,
        464 * scale,
        256 * scale,
        492 * scale,
      );
      path.cubicTo(
        152 * scale,
        464 * scale,
        64 * scale,
        408 * scale,
        64 * scale,
        328 * scale,
      );
      path.lineTo(64 * scale, 104 * scale);
      path.close();

      canvas.drawPath(path, paintBg);

      final paintBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * scale
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(size.toDouble(), size.toDouble()),
          [
            const Color(0xFF38BDF8),
            const Color(0xFF818CF8),
            const Color(0xFFC084FC),
          ],
          [0.0, 0.5, 1.0],
        );
      canvas.drawPath(path, paintBorder);

      // Core Hexagon
      final corePath = Path();
      corePath.moveTo(256 * scale, 160 * scale);
      corePath.lineTo(330 * scale, 202 * scale);
      corePath.lineTo(330 * scale, 310 * scale);
      corePath.lineTo(256 * scale, 352 * scale);
      corePath.lineTo(182 * scale, 310 * scale);
      corePath.lineTo(182 * scale, 202 * scale);
      corePath.close();

      final corePaint = Paint()..color = const Color(0xFF030712);
      canvas.drawPath(corePath, corePaint);

      final coreBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * scale
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(size.toDouble(), size.toDouble()),
          [
            const Color(0xFF22D3EE),
            const Color(0xFF818CF8),
            const Color(0xFFA855F7),
          ],
          [0.0, 0.5, 1.0],
        );
      canvas.drawPath(corePath, coreBorder);

      // Center Node
      final nodePaint = Paint()..color = const Color(0xFF00F2FE);
      canvas.drawCircle(
        Offset(256 * scale, 256 * scale),
        20 * scale,
        nodePaint,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(size, size);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      File('assets/images/logo_$size.png').writeAsBytesSync(bytes);

      if (size == 48) {
        File('android/app/src/main/res/mipmap-mdpi/ic_launcher.png')
            .writeAsBytesSync(bytes);
      } else if (size == 72) {
        File('android/app/src/main/res/mipmap-hdpi/ic_launcher.png')
            .writeAsBytesSync(bytes);
      } else if (size == 96) {
        File('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png')
            .writeAsBytesSync(bytes);
      } else if (size == 144) {
        File('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png')
            .writeAsBytesSync(bytes);
      } else if (size == 192) {
        File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png')
            .writeAsBytesSync(bytes);
      }
    }
  });
}
