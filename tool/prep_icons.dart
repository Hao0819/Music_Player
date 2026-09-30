// One-off helper: turns assets/icon/source.jpeg into the PNGs that
// flutter_launcher_icons and flutter_native_splash consume.
import 'dart:io';

import 'package:image/image.dart' as img;

/// JPEG compression leaves the "black" backdrop a few points off pure black,
/// which would show up as a faint square against the #000000 adaptive-icon
/// and splash backgrounds. Snap those pixels back to true black.
img.Image _normalizeBlack(img.Image src) {
  for (final p in src) {
    if (p.r < 40 && p.g < 40 && p.b < 40) {
      p.setRgb(0, 0, 0);
    }
  }
  return src;
}

/// Centres [src] on a transparent [canvas]x[canvas] square at [inner] px.
img.Image _inset(img.Image src, {required int canvas, required int inner}) {
  final out = img.Image(width: canvas, height: canvas, numChannels: 4);
  img.compositeImage(
    out,
    img.copyResize(src, width: inner, height: inner, interpolation: img.Interpolation.cubic),
    dstX: (canvas - inner) ~/ 2,
    dstY: (canvas - inner) ~/ 2,
  );
  return out;
}

void main() {
  final source = img.decodeJpg(File('assets/icon/source.jpeg').readAsBytesSync());
  if (source == null) {
    stderr.writeln('could not decode assets/icon/source.jpeg');
    exit(1);
  }
  stdout.writeln('source: ${source.width}x${source.height}');

  final square = _normalizeBlack(
    img.copyResize(source, width: 1024, height: 1024, interpolation: img.Interpolation.cubic),
  );
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(square));

  // flutter_launcher_icons already insets the foreground by 16% to clear the
  // adaptive-icon safe zone, so this layer stays full-bleed.
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(square));

  // Android 12's splash icon is 1152px with only the inner 768px inside the
  // circular mask, so this one does need the artwork inset.
  File('assets/icon/splash_android12.png')
      .writeAsBytesSync(img.encodePng(_inset(square, canvas: 1152, inner: 768)));

  File('assets/icon/splash_logo.png')
      .writeAsBytesSync(img.encodePng(img.copyResize(square, width: 768, height: 768)));

  stdout.writeln('wrote app_icon.png, app_icon_foreground.png, '
      'splash_android12.png, splash_logo.png');
}
