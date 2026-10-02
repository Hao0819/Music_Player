# Archivo

Archivo (OFL, see `OFL.txt`) — one superfamily covering the whole app. The
width axis is what separates display type from UI type, so there is no second
typeface to keep in sync.

`Archivo-Variable.ttf` is the upstream source from google/fonts and is **not**
bundled into the app; only the static cuts declared in `pubspec.yaml` are.
The variable font's default instance is `wght` 600, which is why static cuts
are generated at all — relying on `fontVariations` instead would collide with
the plain `fontWeight:` styles used across the screens and render double-bold.

Regenerate the cuts after replacing the source:

    python -m pip install fonttools brotli
    python assets/fonts/build_instances.py
