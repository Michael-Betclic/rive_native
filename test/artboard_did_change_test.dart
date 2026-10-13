@TestOn('!browser')
library;

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rive_native/rive_native.dart' as rive;
import 'package:rive_native/src/ffi/dynamic_library_helper.dart';

import 'src/utils.dart';

void main() {
  final exportsDidChange =
      DynamicLibraryHelper.nativeLib.providesSymbol('riveArtboardDidChange');

  group('Artboard.didChange', () {
    late rive.Artboard artboard;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final riveFile = await rive.File.decode(
        loadFile('assets/off_road_car.riv'),
        riveFactory: rive.Factory.flutter,
      ) as rive.File;
      artboard = riveFile.defaultArtboard()!;
    });

    void draw() {
      final renderer = rive.Renderer.make(ui.Canvas(ui.PictureRecorder()));
      artboard.draw(renderer);
      renderer.dispose();
    }

    test('is set before the first draw', () {
      expect(artboard.didChange, isTrue);
    });

    test('is cleared by a draw and stays clear while nothing changes', () {
      draw();
      expect(artboard.didChange, isFalse);

      artboard.advance(0);
      expect(artboard.didChange, isFalse);
    }, skip: exportsDidChange ? false : 'native library lacks the export');

    test('is set again when an animation moves the artboard', () {
      draw();

      artboard.animationAt(0).advanceAndApply(0.1);

      expect(artboard.didChange, isTrue);
    }, skip: exportsDidChange ? false : 'native library lacks the export');
  });
}
