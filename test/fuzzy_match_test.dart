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
}
