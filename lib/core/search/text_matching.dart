/// Low-level text matching primitives used by the discovery engine.
///
/// Pure Dart and allocation-conscious: these run on every keystroke against
/// the whole in-memory catalog, so they avoid regex and build no throwaway
/// collections in the hot path beyond what the algorithms require.
library;

import 'dart:math' as math;

/// Normalises text for indexing and querying.
///
/// Lowercases, strips diacritics for the Latin-1 range, and collapses any
/// run of non-alphanumeric characters into a single space. This makes
/// "Nova-Player", "nova player" and "NovaPlayer " all normalise compatibly.
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  var lastWasSpace = true;
  for (final rune in input.toLowerCase().runes) {
    final ch = _foldDiacritic(rune);
    final isAlnum = (ch >= 0x30 && ch <= 0x39) || (ch >= 0x61 && ch <= 0x7a);
    if (isAlnum) {
      buffer.writeCharCode(ch);
      lastWasSpace = false;
    } else if (ch > 0x7f) {
      // Preserve non-Latin scripts (CJK, Cyrillic, Arabic...) verbatim.
      buffer.writeCharCode(ch);
      lastWasSpace = false;
    } else if (!lastWasSpace) {
      buffer.write(' ');
      lastWasSpace = true;
    }
  }
  return buffer.toString().trim();
}

const String _accented = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
const String _plain = 'aaaaaaceeeeiiiinooooouuuuyy';

int _foldDiacritic(int rune) {
  final index = _accented.codeUnits.indexOf(rune);
  if (index == -1) return rune;
  return _plain.codeUnitAt(index);
}

/// Splits normalised [text] into unique tokens.
List<String> tokenize(String text) {
  final normalized = normalizeForSearch(text);
  if (normalized.isEmpty) return const [];
  final seen = <String>{};
  final tokens = <String>[];
  for (final token in normalized.split(' ')) {
    if (token.isEmpty) continue;
    if (seen.add(token)) tokens.add(token);
  }
  return tokens;
}

/// Bounded Damerau–Levenshtein distance between [a] and [b].
///
/// Returns a value greater than [maxDistance] as soon as the true distance is
/// known to exceed it, which keeps typo tolerance O(n * maxDistance) instead
/// of O(n * m) across a large catalog.
int boundedEditDistance(String a, String b, {int maxDistance = 2}) {
  if (identical(a, b) || a == b) return 0;
  if ((a.length - b.length).abs() > maxDistance) return maxDistance + 1;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previousPrevious = List<int>.filled(b.length + 1, 0);
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    final from = math.max(1, i - maxDistance);
    final to = math.min(b.length, i + maxDistance);
    if (from > 1) current[from - 1] = maxDistance + 1;

    var rowMinimum = maxDistance + 1;
    for (var j = from; j <= to; j++) {
      final substitutionCost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var value = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + substitutionCost,
      );
      // Transposition (Damerau): "gogle" -> "google" style swaps.
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        value = math.min(value, previousPrevious[j - 2] + 1);
      }
      current[j] = value;
      if (value < rowMinimum) rowMinimum = value;
    }
    if (to < b.length) current[to + 1] = maxDistance + 1;
    if (rowMinimum > maxDistance) return maxDistance + 1;

    final swap = previousPrevious;
    previousPrevious = previous;
    previous = current;
    current = swap;
  }

  final distance = previous[b.length];
  return distance > maxDistance ? maxDistance + 1 : distance;
}

/// Score in `[0, 1]` describing how well [query] matches [candidate].
///
/// Combines exact, prefix, subsequence (acronym/abbreviation) and fuzzy
/// signals so that "vlc", "v l c", "vcl" and "VLC Media" all reach the same
/// app with sensible relative ranking.
double similarityScore(String query, String candidate) {
  if (query.isEmpty || candidate.isEmpty) return 0;
  final q = normalizeForSearch(query);
  final c = normalizeForSearch(candidate);
  if (q.isEmpty || c.isEmpty) return 0;

  if (q == c) return 1.0;
  if (c.startsWith(q)) return 0.92 - 0.1 * (1 - q.length / c.length);
  if (c.contains(q)) return 0.78 - 0.1 * (1 - q.length / c.length);

  // Word-prefix match: query matches the start of any word in the candidate.
  for (final word in c.split(' ')) {
    if (word.startsWith(q)) return 0.74;
  }

  // Initialism: "vlc" vs "video lan client".
  final initials = c
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0])
      .join();
  if (initials == q) return 0.7;
  if (initials.startsWith(q) && q.length > 1) return 0.62;

  // Typo tolerance scaled to query length: short queries get tighter bounds.
  final maxDistance = q.length <= 3
      ? 1
      : q.length <= 6
          ? 2
          : 3;
  final distance = boundedEditDistance(q, c, maxDistance: maxDistance);
  if (distance <= maxDistance) {
    return math.max(0.0, 0.6 - (distance / (maxDistance + 1)) * 0.35);
  }

  // Per-token fuzzy fallback so a typo in one word of a phrase still matches.
  var best = 0.0;
  for (final word in c.split(' ')) {
    if (word.isEmpty) continue;
    final d = boundedEditDistance(q, word, maxDistance: maxDistance);
    if (d <= maxDistance) {
      best = math.max(best, 0.55 - (d / (maxDistance + 1)) * 0.3);
    }
  }
  return best;
}
