import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic free-text query state, shared by any search box.
class TextQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;

  void clear() => state = '';
}
