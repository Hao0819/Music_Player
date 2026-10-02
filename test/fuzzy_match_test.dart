import 'package:flutter_test/flutter_test.dart';

import 'package:music_player/core/utils/fuzzy_match.dart';

void main() {
  const fields = ['Yesterday', 'The Beatles', 'Help!'];

  test('empty query matches everything', () {
    expect(fuzzyMatches('', fields), isTrue);
    expect(fuzzyMatches('   ', fields), isTrue);
  });

  test('matches case-insensitively on a partial term', () {
    expect(fuzzyMatches('yEsTer', fields), isTrue);
  });

  test('matches terms spread across different fields, in any order', () {
    expect(fuzzyMatches('beatles yesterday', fields), isTrue);
    expect(fuzzyMatches('yesterday beatles', fields), isTrue);
  });

  test('requires every term to match', () {
    expect(fuzzyMatches('beatles zeppelin', fields), isFalse);
  });

  group('hoisted matching', () {
    test('queryTerms splits and lower-cases once', () {
      expect(queryTerms('  Beatles   Yesterday '), ['beatles', 'yesterday']);
      expect(queryTerms('   '), isEmpty);
      expect(queryTerms(''), isEmpty);
    });

    test('an empty query matches everything, same as before', () {
      expect(matchesTerms(queryTerms(''), 'anything at all'), isTrue);
    });

    test('agrees with the field-joining version it replaced', () {
      const fields = ['Yesterday', 'The Beatles', 'Help!'];
      final haystack = fields.join(' ').toLowerCase();

      for (final query in [
        'beatles yesterday',
        'BEATLES',
        'help',
        'yesterday beatles help',
        'nope',
        'beat les',
        '',
      ]) {
        expect(
          matchesTerms(queryTerms(query), haystack),
          fuzzyMatches(query, fields),
          reason: 'disagreed on "$query"',
        );
      }
    });
  });
}
