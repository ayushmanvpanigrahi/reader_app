import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lightweight markdown -> [TextSpan] builder used in chat bubbles.
///
/// Supports the subset of markdown that chat models emit most often:
/// bold, italic, inline code, links, headings, bullet/numbered lists,
/// quotes and horizontal rules. Unknown tokens are kept as literal text.
class MarkdownSpans {
  const MarkdownSpans._();

  static final _linkPattern = RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)');

  static List<InlineSpan> build(
    String text, {
    required TextStyle base,
    Color? accent,
    RecognizerRegistry? recognizers,
  }) {
    final styles = _Styles(
      base: base,
      accent: accent ?? (base.color ?? Colors.blueGrey),
    );
    return _blocks(text, styles, recognizers);
  }

  static List<InlineSpan> _blocks(String text, _Styles s, RecognizerRegistry? recognizers) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) {
        spans.add(TextSpan(text: '\n', style: s.base));
      }

      final trimmed = line.trimLeft();
      final ruleMatch = RegExp(r'^(-{3,}|\*{3,}|_{3,})$').firstMatch(trimmed);
      if (ruleMatch != null) {
        spans.add(TextSpan(text: '· · ·', style: s.rule));
        continue;
      }

      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        spans.add(TextSpan(text: headingMatch.group(2), style: s.heading(level)));
        continue;
      }

      final quoteMatch = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
      if (quoteMatch != null) {
        spans.addAll(_inline('▎ ${quoteMatch.group(1) ?? ''}', s, s.quoteStyle, recognizers));
        continue;
      }

      final bulletMatch = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        spans.add(TextSpan(text: '   •  ', style: s.bullet));
        spans.addAll(_inline(bulletMatch.group(1) ?? '', s, null, recognizers));
        continue;
      }

      final numMatch = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (numMatch != null) {
        spans.add(TextSpan(text: '  ${numMatch.group(1)}.  ', style: s.bullet));
        spans.addAll(_inline(numMatch.group(2) ?? '', s, null, recognizers));
        continue;
      }

      spans.addAll(_inline(line, s, null, recognizers));
    }
    return spans;
  }

  static List<InlineSpan> _inline(
    String text,
    _Styles s, [
    TextStyle? baseOverride,
    RecognizerRegistry? recognizers,
  ]) {
    final result = <InlineSpan>[];
    final buf = StringBuffer();
    var i = 0;
    var bold = false;
    var italic = false;
    var code = false;

    void flush() {
      if (buf.isEmpty) return;
      var style = baseOverride ?? s.base;
      if (code) {
        style = s.code;
      } else {
        if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
        if (bold) style = style.copyWith(fontWeight: FontWeight.w700);
      }
      result.add(TextSpan(text: buf.toString(), style: style));
      buf.clear();
    }

    while (i < text.length) {
      final ch = text[i];

      if (code) {
        if (ch == '`') {
          flush();
          code = false;
          i++;
          continue;
        }
        buf.write(ch);
        i++;
        continue;
      }

      if (ch == '`') {
        flush();
        code = true;
        i++;
        continue;
      }

      if (ch == '[') {
        final link = _linkPattern.matchAsPrefix(text, i);
        if (link != null) {
          flush();
          result.add(TextSpan(
            text: link.group(1),
            style: s.link,
            recognizer: _launchRecognizer(link.group(2)!, recognizers),
          ));
          i += link.group(0)!.length;
          continue;
        }
      }

      if (text.startsWith('***', i) || text.startsWith('___', i)) {
        flush();
        bold = !bold;
        italic = !italic;
        i += 3;
        continue;
      }

      if (text.startsWith('**', i) || text.startsWith('__', i)) {
        flush();
        bold = !bold;
        i += 2;
        continue;
      }

      if (ch == '*') {
        flush();
        italic = !italic;
        i++;
        continue;
      }

      buf.write(ch);
      i++;
    }
    flush();
    return result;
  }

  static TapGestureRecognizer _launchRecognizer(String rawUrl, RecognizerRegistry? registry) {
    if (registry != null) return registry.register(rawUrl);
    return TapGestureRecognizer()..onTap = () => _openUrl(rawUrl);
  }

  static Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https' && scheme != 'mailto' && scheme != 'tel') {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Never crash the chat over a bad link.
    }
  }
}

/// Owns the [TapGestureRecognizer]s attached to link [TextSpan]s so they can
/// be disposed when the owning widget is torn down. Link recognizers are
/// cached per URL, which also stops streaming rebuilds from allocating a new
/// recognizer (and a new arena listener) for every token.
class RecognizerRegistry {
  final Map<String, TapGestureRecognizer> _byUrl = {};

  TapGestureRecognizer? get(String rawUrl) => _byUrl[rawUrl];

  TapGestureRecognizer register(String rawUrl) {
    final existing = _byUrl[rawUrl];
    if (existing != null) return existing;
    final recognizer = TapGestureRecognizer()..onTap = () => MarkdownSpans._openUrl(rawUrl);
    _byUrl[rawUrl] = recognizer;
    return recognizer;
  }

  void dispose() {
    for (final recognizer in _byUrl.values) {
      recognizer.dispose();
    }
    _byUrl.clear();
  }
}

class _Styles {
  final TextStyle base;
  final Color accent;

  _Styles({required this.base, required this.accent});

  TextStyle get rule => base.copyWith(
        color: accent.withValues(alpha: 0.5),
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      );

  TextStyle get bullet => base.copyWith(
        color: accent.withValues(alpha: 0.85),
        fontWeight: FontWeight.w700,
      );

  TextStyle get quoteStyle => base.copyWith(
        color: base.color?.withValues(alpha: 0.85),
        fontStyle: FontStyle.italic,
      );

  TextStyle heading(int level) {
    final size = base.fontSize ?? 14;
    return base.copyWith(
      fontSize: switch (level) {
        1 => size + 5,
        2 => size + 3,
        _ => size + 1,
      },
      fontWeight: FontWeight.w800,
      color: accent,
    );
  }

  TextStyle get code => base.copyWith(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w500,
        fontSize: (base.fontSize ?? 14) - 1,
        background: Paint()
          ..color = accent.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );

  TextStyle get link => base.copyWith(
        color: accent,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: accent.withValues(alpha: 0.6),
      );
}
