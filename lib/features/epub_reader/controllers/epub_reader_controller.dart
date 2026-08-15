import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class EpubChapterItem {
  final String title;
  final String href;
  final int index;

  const EpubChapterItem({
    required this.title,
    required this.href,
    required this.index,
  });
}

class EpubReaderState {
  final bool showControls;
  final double fontSize;
  final String themePreset; // 'paper', 'stage', 'sepia', 'dark', 'oled'
  final double progress;
  final String? currentChapterTitle;
  final List<EpubChapterItem> chapters;
  final bool isReady;
  final String? errorMessage;

  const EpubReaderState({
    this.showControls = true,
    this.fontSize = 18.0,
    this.themePreset = 'paper',
    this.progress = 0.0,
    this.currentChapterTitle,
    this.chapters = const [],
    this.isReady = false,
    this.errorMessage,
  });

  EpubReaderState copyWith({
    bool? showControls,
    double? fontSize,
    String? themePreset,
    double? progress,
    String? currentChapterTitle,
    List<EpubChapterItem>? chapters,
    bool? isReady,
    String? errorMessage,
  }) {
    return EpubReaderState(
      showControls: showControls ?? this.showControls,
      fontSize: fontSize ?? this.fontSize,
      themePreset: themePreset ?? this.themePreset,
      progress: progress ?? this.progress,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      chapters: chapters ?? this.chapters,
      isReady: isReady ?? this.isReady,
      errorMessage: errorMessage,
    );
  }
}

final epubReaderControllerProvider = StateNotifierProvider.autoDispose
    .family<EpubReaderController, EpubReaderState, String>((ref, bookId) {
  return EpubReaderController();
});

class EpubReaderController extends StateNotifier<EpubReaderState> {
  Timer? _hideControlsTimer;

  EpubReaderController() : super(const EpubReaderState()) {
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

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size.clamp(12.0, 32.0));
  }

  void setThemePreset(String preset) {
    state = state.copyWith(themePreset: preset);
  }

  void setProgress(double progress) {
    state = state.copyWith(progress: progress.clamp(0.0, 1.0));
  }

  void setChapters(List<EpubChapterItem> chapters) {
    state = state.copyWith(chapters: chapters, isReady: true);
  }

  void setCurrentChapter(String title) {
    state = state.copyWith(currentChapterTitle: title);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }
}
