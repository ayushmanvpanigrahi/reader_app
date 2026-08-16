import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/features/pdf_reader/controllers/pdf_reader_controller.dart';
import 'package:reader_app/features/pdf_reader/presentation/widgets/reading_tone_matrices.dart';

void main() {
  const epsilon = 1.0;

  void expectPixel(List<double> matrix, List<double> rgba, List<double> expected) {
    final actual = applyColorMatrix(matrix, rgba);
    for (var i = 0; i < 4; i++) {
      expect(
        actual[i],
        closeTo(expected[i], epsilon),
        reason: 'channel $i: expected ${expected[i]} but got ${actual[i]}',
      );
    }
  }

  group('Reading Tone Matrices', () {
    test('standard mode is the identity matrix', () {
      expectPixel(
        kStandardToneMatrix,
        [255, 255, 255, 255],
        [255, 255, 255, 255],
      );
      expectPixel(
        kStandardToneMatrix,
        [0, 0, 0, 255],
        [0, 0, 0, 255],
      );
      expectPixel(
        kStandardToneMatrix,
        [200, 100, 50, 255],
        [200, 100, 50, 255],
      );
    });

    test('warm sepia maps white to parchment and black to dark brown', () {
      expectPixel(
        kSepiaToneMatrix,
        [255, 255, 255, 255],
        [255, 250, 194, 255],
      );
      expectPixel(
        kSepiaToneMatrix,
        [0, 0, 0, 255],
        [14, 8, 0, 255],
      );
    });

    test('night comfort dims white without inverting — images stay natural', () {
      // White page should dim to ~159 (comfortable gray), not flip to black.
      final white = applyColorMatrix(kNightComfortToneMatrix, [255, 255, 255, 255]);
      for (var ch = 0; ch < 3; ch++) {
        expect(white[ch], closeTo(158.6, epsilon));
      }
      // Black text stays black (offset pushes toward 0, clamped).
      final black = applyColorMatrix(kNightComfortToneMatrix, [0, 0, 0, 255]);
      for (var ch = 0; ch < 3; ch++) {
        expect(black[ch], closeTo(0, epsilon));
      }
    });

    test('night comfort preserves image colors — no grayscale conversion', () {
      // Per-channel dimming keeps hues: red stays red, green stays green.
      final red = applyColorMatrix(kNightComfortToneMatrix, [255, 0, 0, 255]);
      expect(red[0], closeTo(158.6, epsilon));
      expect(red[1], closeTo(0, epsilon));
      expect(red[2], closeTo(0, epsilon));
      final green = applyColorMatrix(kNightComfortToneMatrix, [0, 255, 0, 255]);
      expect(green[0], closeTo(0, epsilon));
      expect(green[1], closeTo(158.6, epsilon));
      expect(green[2], closeTo(0, epsilon));
    });

    test('e-ink oled maps white to pure black and black to pure white', () {
      expectPixel(
        kOledDarkToneMatrix,
        [255, 255, 255, 255],
        [0, 0, 0, 255],
      );
      expectPixel(
        kOledDarkToneMatrix,
        [0, 0, 0, 255],
        [255, 255, 255, 255],
      );
    });

    test('e-ink oled renders saturated content as natural monochrome', () {
      final green = applyColorMatrix(kOledDarkToneMatrix, [0, 255, 0, 255]);
      final red = applyColorMatrix(kOledDarkToneMatrix, [255, 0, 0, 255]);
      for (final px in [green, red]) {
        expect(px[0], closeTo(px[1], epsilon));
        expect(px[1], closeTo(px[2], epsilon));
      }
    });

    test('toneMatrixFor returns a matrix for every mode', () {
      expect(toneMatrixFor(PdfReadingMode.standard), kStandardToneMatrix);
      expect(toneMatrixFor(PdfReadingMode.sepia), kSepiaToneMatrix);
      expect(toneMatrixFor(PdfReadingMode.nightComfort), kNightComfortToneMatrix);
      expect(toneMatrixFor(PdfReadingMode.oledDark), kOledDarkToneMatrix);
      for (final mode in PdfReadingMode.values) {
        expect(toneMatrixFor(mode), hasLength(20));
      }
    });
  });
}
