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

    test('night charcoal maps white to #1A1A1A and black to #E2E2E2', () {
      expectPixel(
        kCharcoalToneMatrix,
        [255, 255, 255, 255],
        [26, 26, 26, 255],
      );
      expectPixel(
        kCharcoalToneMatrix,
        [0, 0, 0, 255],
        [226, 226, 226, 255],
      );
    });

    test('night charcoal is luminance-based so colors never flip blue/green', () {
      // A saturated red page would become cyan under a raw RGB negative; the
      // charcoal matrix must keep every channel equal (monochrome) instead.
      final red = applyColorMatrix(kCharcoalToneMatrix, [255, 0, 0, 255]);
      final blue = applyColorMatrix(kCharcoalToneMatrix, [0, 0, 255, 255]);
      for (final px in [red, blue]) {
        expect(px[0], closeTo(px[1], epsilon));
        expect(px[1], closeTo(px[2], epsilon));
      }
      // Mid-grays roll over smoothly (no harsh full-range flip).
      final mid = applyColorMatrix(kCharcoalToneMatrix, [128, 128, 128, 255]);
      expect(mid[0], closeTo(126, epsilon));
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
      expect(toneMatrixFor(PdfReadingMode.charcoal), kCharcoalToneMatrix);
      expect(toneMatrixFor(PdfReadingMode.oledDark), kOledDarkToneMatrix);
      for (final mode in PdfReadingMode.values) {
        expect(toneMatrixFor(mode), hasLength(20));
      }
    });
  });
}
