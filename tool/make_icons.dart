// Generates the launcher-icon source images from the AeroDrop artwork.
//
// Run with: dart run tool/make_icons.dart
//
// Produces three files under assets/images/:
//   app_icon.png             the full square mark, for iOS / web / legacy Android
//   app_icon_foreground.png  white line art on transparent, inset for Android's
//                            adaptive safe zone
//   (and prints the background colour to use behind that foreground)
//
// The foreground matters because Android crops an adaptive icon to whatever
// mask the launcher chooses, keeping only the centre 66%. Handing it the
// full-bleed square would clip the drone; handing it a padded cut-out lets the
// system mask the background instead of the artwork.
import 'dart:io';

import 'package:image/image.dart';

const _source = 'tool/icon/source.png';

/// Build-time outputs. These live outside `assets/` on purpose: they are inputs
/// to flutter_launcher_icons, not runtime assets, and at ~1.2MB they would
/// otherwise ship inside the app for nothing.
const _outDir = 'tool/icon';

/// The one icon file that *is* bundled, for the in-app brand mark. Small,
/// because it renders at 34-92pt and never larger.
const _appAsset = 'assets/images/brand_mark.png';
const _appAssetSize = 256;

/// Output edge for both generated files. 1024 is what the App Store wants and
/// is a clean power-of-two downscale for every Android bucket.
const _size = 1024;

/// Fraction of the *foreground drawable* the artwork occupies.
///
/// flutter_launcher_icons wraps the foreground in `<inset android:inset="16%">`,
/// which already scales the drawable to 68% of the icon canvas. Insetting again
/// here would compound the two and land the artwork near 42%, which reads as a
/// stamp floating in a blue square. 0.92 x 0.68 puts it at roughly 63% — inside
/// the 66% Android guarantees every mask shape preserves.
const _safeScale = 0.92;

void main() {
  final srcFile = File(_source);
  if (!srcFile.existsSync()) {
    stderr.writeln('Missing $_source');
    exit(1);
  }

  final src = decodePng(srcFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not decode $_source');
    exit(1);
  }
  stdout.writeln('source: ${src.width}x${src.height}');

  // --- 1. The full square mark -------------------------------------------
  final square = copyResize(
    src,
    width: _size,
    height: _size,
    interpolation: Interpolation.cubic,
  );
  File('$_outDir/app_icon.png').writeAsBytesSync(encodePng(square));
  stdout.writeln('wrote $_outDir/app_icon.png (${_size}x$_size)');

  final appMark = copyResize(
    src,
    width: _appAssetSize,
    height: _appAssetSize,
    interpolation: Interpolation.cubic,
  );
  File(_appAsset).writeAsBytesSync(encodePng(appMark));
  stdout.writeln('wrote $_appAsset (${_appAssetSize}x$_appAssetSize)');

  // --- 2. Sample the gradient --------------------------------------------
  // The artwork is white line work over a vertical blue gradient. Sampling the
  // corners gives the two ends of that gradient and, with them, a threshold
  // that separates ink from sky.
  final topLeft = square.getPixel(4, 4);
  final bottomRight = square.getPixel(_size - 5, _size - 5);
  String hex(Pixel p) =>
      '#${p.r.toInt().toRadixString(16).padLeft(2, '0')}'
              '${p.g.toInt().toRadixString(16).padLeft(2, '0')}'
              '${p.b.toInt().toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();
  stdout.writeln('gradient top:    ${hex(topLeft)}');
  stdout.writeln('gradient bottom: ${hex(bottomRight)}');

  // The background is saturated blue, so its smallest channel stays low; white
  // ink pushes every channel high. The minimum channel therefore separates the
  // two cleanly, with none of the haloing a per-channel key would produce.
  final bgMin = [
    _minChannel(topLeft),
    _minChannel(bottomRight),
  ].reduce((a, b) => a > b ? a : b);
  final lo = bgMin + 18; // just above the lightest sky
  const hi = 236.0; // solid ink
  stdout.writeln(
    'ink threshold: $lo..${hi.toInt()} (background min channel $bgMin)',
  );

  // --- 3. The adaptive foreground ----------------------------------------
  // Key the ink out of the sky at full resolution first, then centre on the
  // ink's own bounding box. The source is a crop, so the drone sits right of
  // centre; scaling the whole square would carry that offset into the icon,
  // where a circular launcher mask would bite unevenly into it.
  final keyed = Image(width: _size, height: _size, numChannels: 4);
  var minX = _size, minY = _size, maxX = -1, maxY = -1;

  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final m = _minChannel(square.getPixel(x, y));
      // A ramp rather than a hard cut, so the hand-drawn strokes keep their
      // anti-aliased edges instead of turning into stair-steps.
      final t = ((m - lo) / (hi - lo)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      keyed.setPixelRgba(x, y, 255, 255, 255, (t * 255).round());
      if (t > 0.5) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < 0) {
    stderr.writeln('No ink found — check the threshold.');
    exit(1);
  }

  final inkW = maxX - minX + 1;
  final inkH = maxY - minY + 1;
  stdout.writeln('ink bounds: ${inkW}x$inkH at ($minX,$minY)');

  final ink = copyCrop(keyed, x: minX, y: minY, width: inkW, height: inkH);

  // Fit the ink inside the safe zone, preserving its aspect ratio.
  final target = (_size * _safeScale).round();
  final scale = target / (inkW > inkH ? inkW : inkH);
  final drawW = (inkW * scale).round();
  final drawH = (inkH * scale).round();
  final fitted = copyResize(
    ink,
    width: drawW,
    height: drawH,
    interpolation: Interpolation.cubic,
  );

  final art = Image(width: _size, height: _size, numChannels: 4);
  compositeImage(
    art,
    fitted,
    dstX: ((_size - drawW) / 2).round(),
    dstY: ((_size - drawH) / 2).round(),
  );

  File('$_outDir/app_icon_foreground.png').writeAsBytesSync(encodePng(art));
  stdout.writeln(
    'wrote app_icon_foreground.png '
    '(ink centred, fitted to ${(_safeScale * 100).round()}% of the canvas)',
  );

  // --- 4. The adaptive background ----------------------------------------
  // A solid colour would flatten the icon against the real artwork, so the
  // background is the same vertical gradient, sampled from the source.
  final bg = Image(width: _size, height: _size, numChannels: 4);
  final t0r = topLeft.r.toInt(), t0g = topLeft.g.toInt(), t0b = topLeft.b.toInt();
  final t1r = bottomRight.r.toInt(),
      t1g = bottomRight.g.toInt(),
      t1b = bottomRight.b.toInt();
  for (var y = 0; y < _size; y++) {
    final t = y / (_size - 1);
    final r = (t0r + (t1r - t0r) * t).round();
    final g = (t0g + (t1g - t0g) * t).round();
    final b = (t0b + (t1b - t0b) * t).round();
    for (var x = 0; x < _size; x++) {
      bg.setPixelRgba(x, y, r, g, b, 255);
    }
  }
  File('$_outDir/app_icon_background.png').writeAsBytesSync(encodePng(bg));
  stdout.writeln('wrote app_icon_background.png (${hex(topLeft)} to ${hex(bottomRight)})');
}

int _minChannel(Pixel p) {
  final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
  return r < g ? (r < b ? r : b) : (g < b ? g : b);
}
