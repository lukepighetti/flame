import 'package:flame/src/text/styles/style.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

@immutable
class BackgroundStyle extends Style {
  BackgroundStyle({
    Color? color,
    Paint? paint,
    Color? borderColor,
    double? borderRadius,
    double? borderWidth,
  })  : assert(
          paint == null || color == null,
          'Parameters `paint` and `color` are exclusive',
        ),
        borderWidths = EdgeInsets.all(borderWidth ?? 0),
        borderRadius = borderRadius ?? 0,
        backgroundPaint =
            paint ?? (color != null ? (Paint()..color = color) : null),
        borderPaint = borderColor != null
            ? (Paint()
              ..color = borderColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = borderWidth ?? 0)
            : null;

  final Paint? backgroundPaint;
  final Paint? borderPaint;
  final double borderRadius;
  final EdgeInsets borderWidths;

  BackgroundStyle copyWith({
    Color? color,
    Paint? paint,
    Color? borderColor,
    double? borderRadius,
    double? borderWidth,
  }) {
    return BackgroundStyle(
      color: color ?? (paint == null ? backgroundPaint?.color : null),
      paint: paint ?? backgroundPaint,
      borderColor: borderColor ?? borderPaint?.color,
      borderRadius: borderRadius ?? this.borderRadius,
      borderWidth: borderWidth ?? borderWidths.left,
    );
  }
}
