import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PdfReadingMode { standard, sepia, nightComfort, oledDark }

class PdfReaderState {
  final int currentPage;
  final int totalPages;
  final bool showControls;
  final PdfReadingMode readingMode;
  final Axis scrollDirection;
  final bool isReady;
  final String? errorMessage;

  const PdfReaderState({
    this.currentPage = 1,
    this.totalPages = 1,
    this.showControls = true,
    this.readingMode = PdfReadingMode.standard,
    this.scrollDirection = Axis.vertical,
    this.isReady = false,
    this.errorMessage,
  });

  double get progress => totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0.0;

  PdfReaderState copyWith({
    int? currentPage,
    int? totalPages,
    bool? showControls,
    PdfReadingMode? readingMode,
    Axis? scrollDirection,
    bool? isReady,
    String? errorMessage,
  }) {
    return PdfReaderState(
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      showControls: showControls ?? this.showControls,
      readingMode: readingMode ?? this.readingMode,
      scrollDirection: scrollDirection ?? this.scrollDirection,
      isReady: isReady ?? this.isReady,
      errorMessage: errorMessage,
    );
  }
}

final pdfReaderControllerProvider = StateNotifierProvider.autoDispose
    .family<PdfReaderController, PdfReaderState, String>((ref, bookId) {
  return PdfReaderController();
});

class PdfReaderController extends StateNotifier<PdfReaderState> {
  Timer? _hideControlsTimer;

  PdfReaderController() : super(const PdfReaderState()) {
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && state.showControls) {
        state = state.copyWith(showControls: false);
      }
    });
  }

  void toggleControls() {
    final next = !state.showControls;
    state = state.copyWith(showControls: next);
    if (next) {
      _startHideTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void showControlsTemporarily() {
    state = state.copyWith(showControls: true);
    _startHideTimer();
  }

  void onDocumentLoaded(int totalPages, int initialPage) {
    state = state.copyWith(
      totalPages: totalPages > 0 ? totalPages : 1,
      currentPage: initialPage > 0 ? initialPage : 1,
      isReady: true,
    );
  }

  void onPageChanged(int page) {
    if (page != state.currentPage) {
      state = state.copyWith(currentPage: page);
    }
  }

  void setReadingMode(PdfReadingMode mode) {
    state = state.copyWith(readingMode: mode);
  }

  void toggleScrollDirection() {
    final next = state.scrollDirection == Axis.vertical
        ? Axis.horizontal
        : Axis.vertical;
    state = state.copyWith(scrollDirection: next);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }
}
