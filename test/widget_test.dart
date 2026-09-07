import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:music_player/core/theme/app_theme.dart';

void main() {
  test('light and dark themes build with the expected brightness', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });
}
