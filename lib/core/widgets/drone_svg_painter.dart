import 'dart:math' as math;
import 'package:flutter/material.dart';

class DroneSvgPainter extends CustomPainter {
  final double animationValue;
  final Color lineColor;
  final Color accentColor;

  DroneSvgPainter({
    required this.animationValue,
    this.lineColor = Colors.white,
    this.accentColor = const Color(0xFF4F46E5),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;

    // Scale factor to map 0..400 coordinate space to the actual size
    double s(double val) => val * w / 400.0;

    // Paints
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = s(12.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = s(12.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final propellerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = s(12.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Left Motor Mount
    final path1 = Path()
      ..moveTo(s(94.65), s(91.35))
      ..lineTo(s(94.65), s(109.12))
      ..cubicTo(s(86.41), s(113.1), s(76.89), s(116.58), s(64.91), s(119.01))
      ..lineTo(s(64.91), s(91.35))
      ..cubicTo(s(64.91), s(83.14), s(71.57), s(76.48), s(79.78), s(76.48))
      ..cubicTo(s(83.88), s(76.48), s(87.6), s(78.14), s(90.29), s(80.83))
      ..cubicTo(s(92.98), s(83.52), s(94.65), s(87.23), s(94.65), s(91.35))
      ..close();
    canvas.drawPath(path1, linePaint);

    // 2. Left Motor Shaft
    canvas.drawLine(
      Offset(s(79.783), s(76.478)),
      Offset(s(79.783), s(50.0)),
      linePaint,
    );

    // 3. Right Motor Mount
    final path2 = Path()
      ..moveTo(s(322.99), s(91.35))
      ..lineTo(s(322.99), s(115.94))
      ..cubicTo(s(310.96), s(112.3), s(301.68), s(107.52), s(293.25), s(102.44))
      ..lineTo(s(293.25), s(91.35))
      ..cubicTo(s(293.25), s(83.14), s(299.91), s(76.48), s(308.12), s(76.48))
      ..cubicTo(s(312.22), s(76.48), s(315.94), s(78.14), s(318.63), s(80.83))
      ..cubicTo(s(321.32), s(83.52), s(323.0), s(87.23), s(323.0), s(91.35))
      ..close();
    canvas.drawPath(path2, linePaint);

    // 4. Right Motor Shaft
    canvas.drawLine(
      Offset(s(308.12), s(76.478)),
      Offset(s(308.12), s(50.0)),
      linePaint,
    );

    // 5. Lower body structure
    final path3 = Path()
      ..moveTo(s(271.217), s(155.102))
      ..lineTo(s(271.217), s(166.283))
      ..cubicTo(
        s(271.217),
        s(175.228),
        s(263.966),
        s(182.479),
        s(255.021),
        s(182.479),
      )
      ..lineTo(s(144.979), s(182.479))
      ..cubicTo(
        s(136.034),
        s(182.479),
        s(128.783),
        s(175.228),
        s(128.783),
        s(166.283),
      )
      ..lineTo(s(128.783), s(155.102));
    canvas.drawPath(path3, linePaint);

    // 6. Drone Main Aerodynamic Body
    final path4 = Path()
      ..moveTo(s(335.381), s(119.043))
      ..cubicTo(
        s(277.58),
        s(107.355),
        s(277.13),
        s(71.466),
        s(200.149),
        s(71.421),
      )
      ..cubicTo(
        s(123.168),
        s(71.466),
        s(122.719),
        s(107.355),
        s(64.919),
        s(119.043),
      )
      ..cubicTo(
        s(56.392),
        s(120.767),
        s(50.222),
        s(128.201),
        s(50.222),
        s(136.901),
      )
      ..cubicTo(
        s(50.222),
        s(146.953),
        s(58.371),
        s(155.102),
        s(68.423),
        s(155.102),
      )
      ..lineTo(s(332.022), s(155.102))
      ..cubicTo(
        s(342.074),
        s(155.102),
        s(350.223),
        s(146.953),
        s(350.223),
        s(136.901),
      )
      ..cubicTo(
        s(350.223),
        s(128.201),
        s(344.053),
        s(120.767),
        s(335.381),
        s(119.043),
      )
      ..close();
    canvas.drawPath(path4, linePaint);

    // 7. Center eye/camera
    canvas.drawCircle(Offset(s(200.0), s(113.261)), s(20.935), linePaint);

    // 8. Left Leg
    final path5 = Path()
      ..moveTo(s(94.297), s(155.102))
      ..lineTo(s(75.116), s(198.574))
      ..cubicTo(
        s(68.707),
        s(213.099),
        s(71.547),
        s(230.043),
        s(82.341),
        s(241.685),
      )
      ..lineTo(s(110.731), s(272.304));
    canvas.drawPath(path5, linePaint);

    // 9. Right Leg
    final path6 = Path()
      ..moveTo(s(305.703), s(155.102))
      ..lineTo(s(324.884), s(198.574))
      ..cubicTo(
        s(331.293),
        s(213.099),
        s(328.453),
        s(230.043),
        s(317.659),
        s(241.685),
      )
      ..lineTo(s(289.269), s(272.304));
    canvas.drawPath(path6, linePaint);

    // 10. Secondary/Back Box Part
    final path7 = Path()
      ..moveTo(s(174.735), s(220.319))
      ..lineTo(s(273.395), s(220.319))
      ..cubicTo(
        s(281.961),
        s(220.319),
        s(288.905),
        s(227.263),
        s(288.905),
        s(235.829),
      )
      ..lineTo(s(288.905), s(334.489))
      ..cubicTo(
        s(288.905),
        s(343.055),
        s(281.961),
        s(350.0),
        s(273.395),
        s(350.0),
      )
      ..lineTo(s(174.735), s(350.0));
    canvas.drawPath(path7, linePaint);

    // 11. Main Cargo Box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s(111.225), s(220.319), s(129.681), s(129.681)),
        Radius.circular(s(15.51)),
      ),
      linePaint,
    );

    // 12. Box Latch/Ribbon (Indigo in SVG)
    final path8 = Path()
      ..moveTo(s(159.289), s(220.319))
      ..lineTo(s(192.841), s(220.319))
      ..lineTo(s(192.841), s(260.106))
      ..cubicTo(
        s(192.841),
        s(264.987),
        s(188.878),
        s(268.95),
        s(183.997),
        s(268.95),
      )
      ..lineTo(s(168.132), s(268.95))
      ..cubicTo(
        s(163.251),
        s(268.95),
        s(159.289),
        s(264.987),
        s(159.289),
        s(260.106),
      )
      ..close();
    canvas.drawPath(path8, accentPaint);

    // 13. Spinning Propellers (Indigo in SVG)
    final double propellerRotation = animationValue * 8 * math.pi; // Fast spin

    // Left Propeller
    canvas.save();
    canvas.translate(s(79.783), s(50.0));
    canvas.rotate(propellerRotation);
    canvas.drawLine(
      Offset(-s(41.957), 0),
      Offset(s(41.957), 0),
      propellerPaint,
    );
    canvas.restore();

    // Right Propeller
    canvas.save();
    canvas.translate(s(308.12), s(50.0));
    canvas.rotate(propellerRotation);
    canvas.drawLine(
      Offset(-s(41.957), 0),
      Offset(s(41.957), 0),
      propellerPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DroneSvgPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor;
  }
}
