import 'package:flutter/material.dart';

/// Stand-in covers for tracks with no embedded artwork.
///
/// Listed by hand rather than read from the asset manifest: the manifest is
/// only reachable asynchronously, and a row needs its cover in the same frame
/// it is built, so an await here would put a grey flash in front of every
/// picture.
const List<String> fallbackCoverAssets = [
  'assets/covers/music_p.jpg',
  'assets/covers/music_p1.jpg',
  'assets/covers/music_p2.jpg',
  'assets/covers/music_p3.jpg',
  'assets/covers/music_p4.jpg',
  'assets/covers/music_p5.jpg',
];

/// Picks one of [fallbackCoverAssets] for [seed].
///
/// Random across a library but fixed per track: a genuinely random pick would
/// hand the same song a different sleeve every time its row was rebuilt, which
/// reads as the list glitching rather than as artwork. Keying on the track id
/// means a track keeps its cover for as long as MediaStore keeps its id.
String fallbackCoverAsset(int seed) =>
    fallbackCoverAssets[seed.abs() % fallbackCoverAssets.length];

/// One of the stand-in covers, drawn to fill its box.
class FallbackCover extends StatelessWidget {
  const FallbackCover({super.key, required this.seed, required this.size});

  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      fallbackCoverAsset(seed),
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}
