import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic multi-select state (a set of selected track paths), shared by any
/// screen that needs long-press-to-select + a contextual action bar.
class SelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String key) {
    final next = {...state};
    if (!next.remove(key)) next.add(key);
    state = next;
  }

  void clear() => state = {};
}
