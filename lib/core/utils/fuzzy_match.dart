/// Case-insensitive, order-independent term matching: every whitespace-separated
/// term in [query] must appear somewhere across [fields], so "beatles yesterday"
/// matches a track regardless of which field each word came from.
bool fuzzyMatches(String query, List<String> fields) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;

  final haystack = fields.join(' ').toLowerCase();
  return normalized.split(RegExp(r'\s+')).every(haystack.contains);
}
