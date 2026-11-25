// Screenshot capture for the testing appendix.
//
// Off by default: normal `flutter test` runs are unchanged. When the
// AERODROP_CAPTURE_DIR environment variable is set, the real app fonts are
// loaded (from AERODROP_FONTS_DIR) and the last frames each test draws are
// saved as PNG files named after its Test Case ID, so the appendix can show
// the screen in the exact state the test checked.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// test_api ships with flutter_test (the SDK pins its version), so it is not
// listed in pubspec.yaml.
// ignore: implementation_imports, depend_on_referenced_packages
import 'package:test_api/src/backend/invoker.dart';

const _keep = 40;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final dir = Platform.environment['AERODROP_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) return testMain();

  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetsApp.debugAllowBannerOverride = false; // no DEBUG ribbon in the screenshots
  await _loadFonts(Platform.environment['AERODROP_FONTS_DIR'] ?? '');

  final frames = <ui.Image>[];
  var active = false;
  SchedulerBinding.instance.addPersistentFrameCallback((_) {
    if (!active) return;
    final view = RendererBinding.instance.renderViews.first;
    final layer = view.debugLayer;
    if (layer is! OffsetLayer) return;
    frames.add(layer.toImageSync(Offset.zero & view.size));
    while (frames.length > _keep) {
      frames.removeAt(0).dispose();
    }
  });

  setUp(() {
    // Reduce-motion on, so entrance animations show their content at once
    // (the app's own accessibility path) instead of mid-fade in the frames.
    TestWidgetsFlutterBinding.instance.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    for (final f in frames) {
      f.dispose();
    }
    frames.clear();
    active = true;
  });

  tearDown(() async {
    active = false;
    final name = Invoker.current?.liveTest.test.name ?? '';
    final id = RegExp(r'(CASE|INT)-\d+').firstMatch(name)?.group(0);
    if (id == null || frames.isEmpty) return;
    for (var k = 0; k < frames.length; k++) {
      final img = frames[frames.length - 1 - k];
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data != null) File('$dir/${id}_$k.png').writeAsBytesSync(data.buffer.asUint8List());
    }
  });

  await testMain();
}

/// Registers the app's Google Fonts under the family names google_fonts asks
/// for (e.g. "Inter_700"), plus Material Icons and Roboto, so text renders as
/// it does in the app instead of the test font.
Future<void> _loadFonts(String fontsDir) async {
  Future<void> load(String family, String path) async {
    final f = File(path);
    if (!f.existsSync()) return;
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(f.readAsBytesSync()))));
    await loader.load();
  }

  for (final fam in ['Inter', 'PlusJakartaSans', 'RobotoMono']) {
    for (var w = 100; w <= 900; w += 100) {
      final path = '$fontsDir/$fam-$w.ttf';
      await load('${fam}_${w == 400 ? 'regular' : w}', path);
      await load('${fam}_${w == 400 ? 'italic' : '${w}italic'}', path);
    }
  }
  final sdkFonts = '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts';
  await load('MaterialIcons', '$sdkFonts/materialicons-regular.otf');
  await load('Roboto', '$sdkFonts/roboto-regular.ttf');
}
