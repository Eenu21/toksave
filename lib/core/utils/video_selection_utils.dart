import 'package:flutter/material.dart';

RangeValues moveVideoSelectionStart(
  RangeValues selection,
  double startMs,
  int durationMs,
) {
  final duration = durationMs.clamp(0, 0x7fffffff).toDouble();
  if (duration == 0) return const RangeValues(0, 0);

  final minimumRange = duration >= 1000 ? 1000.0 : duration;
  final end = selection.end.clamp(minimumRange, duration).toDouble();
  final start = startMs.clamp(0, end - minimumRange).toDouble();
  return RangeValues(start, end);
}

RangeValues moveVideoSelectionEnd(
  RangeValues selection,
  double endMs,
  int durationMs,
) {
  final duration = durationMs.clamp(0, 0x7fffffff).toDouble();
  if (duration == 0) return const RangeValues(0, 0);

  final minimumRange = duration >= 1000 ? 1000.0 : duration;
  final start = selection.start.clamp(0, duration - minimumRange).toDouble();
  final end = endMs.clamp(start + minimumRange, duration).toDouble();
  return RangeValues(start, end);
}
