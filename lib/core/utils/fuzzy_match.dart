/// Case-insensitive, order-independent term matching: every whitespace-separated
/// term in [query] must appear somewhere across [fields], so "beatles yesterday"
/// matches a track regardless of which field each word came from.
bool fuzzyMatches(String query, List<String> fields) =>
    matchesTerms(queryTerms(query), fields.join(' ').toLowerCase());

/// Splits a query into its lower-cased terms, once.
///
/// Callers filtering a list should hoist this out of the loop: normalising and
/// splitting the query inside the predicate repeats that work for every row,
/// which is the bulk of what made typing in a large library stutter.
List<String> queryTerms(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return const [];
  return normalized.split(_whitespace);
}

/// Whether every term appears in an already-lower-cased [haystack].
bool matchesTerms(List<String> terms, String haystack) => terms.every(haystack.contains);

final _whitespace = RegExp(r'\s+');
