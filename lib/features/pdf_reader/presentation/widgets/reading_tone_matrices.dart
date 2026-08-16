import 'package:flutter/material.dart';

import '../../controllers/pdf_reader_controller.dart';

/// Calibrated 4x5 color matrices for the reading tone suite.
///
/// Dark modes split into two strategies:
/// - **Night Comfort**: per-channel brightness dim (`0.72x − 25`) that keeps
///   every photo and illustration in 100 % natural positive polarity — ideal
///   for illustrated / photo-heavy books.
/// - **E-Ink OLED**: luminance-weighted inversion (`255 − L`) that flips
///   white pages to pure `#000000` and black text to `#FFFFFF` — ideal for
///   text-only novels.  The cover page (page 1) is bypassed so original
///   artwork always shows in full colour.

/// Warm Sepia: parchment background, dark brown text, warm-tinted content.
///
/// Maps white -> (255, 250, 194) and black -> (14, 8, 0).
const List<double> kSepiaToneMatrix = <double>[
  1.0, 0.0, 0.0, 0, 14,
  0.0, 0.95, 0.0, 0, 8,
  0.0, 0.0, 0.80, 0, -10,
  0.0, 0.0, 0.0, 1.0, 0,
];

/// Night Comfort: dimmed paper with 100 % natural positive photos.
///
/// Scales every channel to 72 % and drops a flat −25 offset so the bright
/// white page lands on a comfortable dim gray (~159) while black text stays
/// black.  Coloured images simply get darker — no hue shift, no negative,
/// no blue/green artifacts.  Best for illustrated and photo-heavy books.
const List<double> kNightComfortToneMatrix = <double>[
  0.72, 0.0, 0.0, 0, -25,
  0.0, 0.72, 0.0, 0, -25,
  0.0, 0.0, 0.72, 0, -25,
  0.0, 0.0, 0.0, 1.0, 0,
];

/// E-Ink OLED: full luminance inversion (out = 255 − L) with a per-page
/// cover-page bypass.
///
/// Reading pages (page 2+) get crisp white-on-black text and natural
/// monochrome illustrations — zero blue/green artifacts.  The cover page
/// (page 1) is rendered *without* this filter so original artwork / cover
/// photos appear in their true colours.
///
/// The bypass is implemented in `pdf_reader_screen.dart` by checking
/// `currentPage` and choosing between the identity matrix and this one.
const List<double> kOledDarkToneMatrix = <double>[
  -0.299, -0.587, -0.114, 0, 255,
  -0.299, -0.587, -0.114, 0, 255,
  -0.299, -0.587, -0.114, 0, 255,
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
    PdfReadingMode.nightComfort => kNightComfortToneMatrix,
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
