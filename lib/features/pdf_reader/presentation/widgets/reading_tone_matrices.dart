import 'package:flutter/material.dart';

import '../../controllers/pdf_reader_controller.dart';

/// Calibrated 4x5 color matrices for the reading tone suite.
///
/// All dark modes use luminance-weighted inversion (out = k - l * L where
/// L = 0.299R + 0.587G + 0.114B) instead of a raw RGB negative. Raw per-channel
/// negation (255 - R, 255 - G, 255 - B) turns red content into cyan and skin
/// tones into blue-green X-ray colors; the luminance approach keeps images as
/// natural monochrome and guarantees no fluorescent artifacts.

/// Warm Sepia: parchment background, dark brown text, warm-tinted content.
///
/// Maps white -> (255, 250, 194) and black -> (14, 8, 0).
const List<double> kSepiaToneMatrix = <double>[
  1.0, 0.0, 0.0, 0, 14,
  0.0, 0.95, 0.0, 0, 8,
  0.0, 0.0, 0.80, 0, -10,
  0.0, 0.0, 0.0, 1.0, 0,
];

/// Night Charcoal: soft `#1A1A1A` background with `#E2E2E2` text.
///
/// Compressed luminance inversion with slope -0.784 and offset 226 so white
/// pages land on `#1A1A1A` and black text on `#E2E2E2`. Mid-tones roll off
/// smoothly instead of flipping, keeping dark-mode contrast comfortable.
const List<double> kCharcoalToneMatrix = <double>[
  -0.2344, -0.4602, -0.0894, 0, 226,
  -0.2344, -0.4602, -0.0894, 0, 226,
  -0.2344, -0.4602, -0.0894, 0, 226,
  0.0, 0.0, 0.0, 1.0, 0,
];

/// E-Ink OLED: brightness-dim with contrast boost — no luminance inversion.
///
/// Reduces brightness by ~30 % and drops a flat −30 offset so white pages
/// land on a comfortable dim gray while black text stays black.  Critically,
/// every channel is scaled equally (`0.7` × original − 30), which means
/// coloured images simply get darker instead of flipping into negatives or
/// losing saturation — zero blue/green artifacts.
///
/// The pure-black scaffold behind the viewer provides the OLED-friendly dark
/// surround; the viewer itself stays non-inverted for natural images.
const List<double> kOledDarkToneMatrix = <double>[
  0.7, 0.0, 0.0, 0, -30,
  0.0, 0.7, 0.0, 0, -30,
  0.0, 0.0, 0.7, 0, -30,
  0.0, 0.0, 0.0, 1.0, 0,
];

/// The identity matrix for the standard (Original) mode.
const List<double> kStandardToneMatrix = <double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// Looks up the matrix for a reading mode.
List<double> toneMatrixFor(PdfReadingMode mode) {
  return switch (mode) {
    PdfReadingMode.standard => kStandardToneMatrix,
    PdfReadingMode.sepia => kSepiaToneMatrix,
    PdfReadingMode.charcoal => kCharcoalToneMatrix,
    PdfReadingMode.oledDark => kOledDarkToneMatrix,
  };
}

/// Applies a 4x5 color matrix to an RGBA pixel, clamping each channel to
/// [0, 255]. Exposed for unit-testing the matrix constants.
List<double> applyColorMatrix(List<double> matrix, List<double> rgba) {
  final out = List<double>.filled(4, 0);
  for (var row = 0; row < 4; row++) {
    var v = matrix[row * 5 + 4];
    for (var col = 0; col < 4; col++) {
      v += matrix[row * 5 + col] * rgba[col];
    }
    out[row] = v.clamp(0.0, 255.0);
  }
  return out;
}

/// Convenience for building a `ColorFilter` from a matrix constant.
ColorFilter colorFilterFor(PdfReadingMode mode) {
  return ColorFilter.matrix(toneMatrixFor(mode));
}
