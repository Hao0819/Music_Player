enum CategorizedFilter { any, categorized, uncategorized }

enum RecencyFilter { any, recentlyAdded, recentlyPlayed }

class LibraryFilterState {
  const LibraryFilterState({
    this.formats = const {},
    this.minDuration = Duration.zero,
    this.maxDuration = maxDurationBound,
    this.categorized = CategorizedFilter.any,
    this.recency = RecencyFilter.any,
  });

  /// The top of the duration slider. A [maxDuration] sitting at this value
  /// means "no upper limit" rather than a literal 20-minute cap.
  static const maxDurationBound = Duration(minutes: 20);

  static const recencyWindow = Duration(days: 7);

  /// Empty means "any format".
  final Set<String> formats;
  final Duration minDuration;
  final Duration maxDuration;
  final CategorizedFilter categorized;
  final RecencyFilter recency;

  bool get hasUpperDurationLimit => maxDuration < maxDurationBound;

  bool get isActive =>
      formats.isNotEmpty ||
      minDuration > Duration.zero ||
      hasUpperDurationLimit ||
      categorized != CategorizedFilter.any ||
      recency != RecencyFilter.any;

  LibraryFilterState copyWith({
    Set<String>? formats,
    Duration? minDuration,
    Duration? maxDuration,
    CategorizedFilter? categorized,
    RecencyFilter? recency,
  }) {
    return LibraryFilterState(
      formats: formats ?? this.formats,
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      categorized: categorized ?? this.categorized,
      recency: recency ?? this.recency,
    );
  }
}
