import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/search/text_matching.dart';

void main() {
  group('normalizeForSearch', () {
    test('lowercases and collapses punctuation to single spaces', () {
      expect(normalizeForSearch('Nova--Player!!'), 'nova player');
      expect(normalizeForSearch('  Foo   Bar  '), 'foo bar');
    });

    test('folds Latin-1 diacritics', () {
      expect(normalizeForSearch('Café Münster'), 'cafe munster');
    });

    test('preserves non-Latin scripts', () {
      expect(normalizeForSearch('音楽'), '音楽');
    });

    test('keeps digits', () {
      expect(normalizeForSearch('VLC 3.0'), 'vlc 3 0');
    });
  });

  group('tokenize', () {
    test('splits into unique tokens', () {
      expect(tokenize('Open Source open'), ['open', 'source']);
    });

    test('returns empty for punctuation-only input', () {
      expect(tokenize('---'), isEmpty);
    });
  });

  group('boundedEditDistance', () {
    test('returns 0 for identical strings', () {
      expect(boundedEditDistance('vlc', 'vlc'), 0);
    });

    test('counts substitutions and insertions', () {
      expect(boundedEditDistance('kitten', 'sitten'), 1);
      expect(boundedEditDistance('cat', 'cats'), 1);
    });

    test('counts a transposition as one edit', () {
      expect(boundedEditDistance('gogle', 'golge', maxDistance: 2), 1);
    });

    test('short-circuits beyond the bound', () {
      expect(boundedEditDistance('abc', 'zzzzzzzz', maxDistance: 2),
          greaterThan(2));
    });

    test('handles empty inputs', () {
      expect(boundedEditDistance('', 'ab', maxDistance: 5), 2);
      expect(boundedEditDistance('ab', '', maxDistance: 5), 2);
    });
  });

  group('similarityScore', () {
    test('exact match scores 1.0', () {
      expect(similarityScore('Nova Player', 'nova player'), 1.0);
    });

    test('prefix beats substring beats fuzzy', () {
      final prefix = similarityScore('nova', 'Nova Player');
      final substring = similarityScore('player', 'Nova Player');
      final fuzzy = similarityScore('novaa', 'Nova');
      expect(prefix, greaterThan(substring));
      expect(substring, greaterThan(fuzzy));
      expect(fuzzy, greaterThan(0));
    });

    test('matches an initialism', () {
      expect(similarityScore('vlc', 'Video Lan Client'), greaterThan(0.6));
    });

    test('tolerates a typo', () {
      expect(similarityScore('firefx', 'Firefox'), greaterThan(0));
    });

    test('returns 0 for unrelated text', () {
      expect(similarityScore('spreadsheet', 'zz'), 0);
    });

    test('returns 0 for empty inputs', () {
      expect(similarityScore('', 'anything'), 0);
      expect(similarityScore('anything', ''), 0);
    });
  });
}
