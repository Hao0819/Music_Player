import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/library_filter_state.dart';

/// Filter state shared by any screen that offers the filter panel. Each
/// screen declares its own provider instance so the Library and Search tabs
/// keep independent filters.
class LibraryFilterNotifier extends Notifier<LibraryFilterState> {
  @override
  LibraryFilterState build() => const LibraryFilterState();

  void toggleFormat(String format) {
    final formats = {...state.formats};
    if (!formats.remove(format)) formats.add(format);
    state = state.copyWith(formats: formats);
  }

  void setDurationRange(Duration min, Duration max) {
    state = state.copyWith(minDuration: min, maxDuration: max);
  }

  void setCategorized(CategorizedFilter value) => state = state.copyWith(categorized: value);

  void setRecency(RecencyFilter value) => state = state.copyWith(recency: value);

  void reset() => state = const LibraryFilterState();
}

typedef LibraryFilterProvider = NotifierProvider<LibraryFilterNotifier, LibraryFilterState>;
