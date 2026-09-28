import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toksave/core/utils/video_selection_utils.dart';

void main() {
  test('moves the start while preserving the end and minimum interval', () {
    expect(
      moveVideoSelectionStart(const RangeValues(20000, 40000), 30000, 180000),
      const RangeValues(30000, 40000),
    );
    expect(
      moveVideoSelectionStart(
        const RangeValues(179000, 180000),
        179900,
        180000,
      ),
      const RangeValues(179000, 180000),
    );
    expect(
      moveVideoSelectionStart(const RangeValues(50, 1050), -50, 180000),
      const RangeValues(0, 1050),
    );
  });

  test('moves the end while preserving the start and minimum interval', () {
    expect(
      moveVideoSelectionEnd(const RangeValues(20000, 40000), 30000, 180000),
      const RangeValues(20000, 30000),
    );
    expect(
      moveVideoSelectionEnd(const RangeValues(20000, 40000), 20001, 180000),
      const RangeValues(20000, 21000),
    );
    expect(
      moveVideoSelectionEnd(const RangeValues(20000, 40000), 200000, 180000),
      const RangeValues(20000, 180000),
    );
  });

  test('uses the full length for videos shorter than one second', () {
    expect(
      moveVideoSelectionStart(const RangeValues(0, 500), 300, 500),
      const RangeValues(0, 500),
    );
  });

  test('returns an empty selection for an unknown duration', () {
    expect(
      moveVideoSelectionEnd(const RangeValues(100, 200), 300, 0),
      const RangeValues(0, 0),
    );
  });
}
