import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive_native/rive_native.dart';
import 'package:rive_native/src/rive.dart' show RiveImageDecodes;

/// A painter whose advance result and change flag are driven by the test,
/// and which counts how often the render box paints it.
final class _StubPainter extends ProceduralPainter
    with RivePointerEventMixin, RiveArtboardLayoutMixin {
  _StubPainter(
      {DrawOptimization drawOptimization = DrawOptimization.alwaysDraw}) {
    this.drawOptimization = drawOptimization;
    hitTestBehavior = RiveHitTestBehavior.opaque;
  }

  int paints = 0;
  bool keepGoing = true;
  bool changed = false;

  @override
  Artboard? get artboard => null;

  @override
  bool advance(double elapsedSeconds) => keepGoing;

  @override
  bool get didChange => changed;

  @override
  void paint(Renderer renderer, Size size, double paintPixelRatio) {
    paints++;
    changed = false;
  }

  @override
  bool hitTest(Offset position) => true;

  @override
  void pointerEvent(PointerEvent event, HitTestEntry entry) {}
}

const _frame = Duration(milliseconds: 16);

Widget _host(ProceduralPainter painter, {Size size = const Size(100, 100)}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox.fromSize(
        size: size,
        child: FlutterRiveRendererWidget(painter: painter),
      ),
    ),
  );
}

/// Pumps [count] frames and returns how many of them painted [painter].
Future<int> _paintsOver(
  WidgetTester tester,
  _StubPainter painter, {
  int count = 10,
}) async {
  final before = painter.paints;
  for (var i = 0; i < count; i++) {
    await tester.pump(_frame);
  }
  return painter.paints - before;
}

FlutterRiveRenderBox _renderBox(WidgetTester tester) => tester
    .renderObject<FlutterRiveRenderBox>(find.byType(FlutterRiveRendererWidget));

void main() {
  group('alwaysDraw', () {
    testWidgets('repaints every frame while the painter keeps going',
        (tester) async {
      final painter = _StubPainter();
      await tester.pumpWidget(_host(painter));

      expect(await _paintsOver(tester, painter), 10);
      expect(_renderBox(tester).isRepaintBoundary, isFalse);
    });
  });

  group('drawOnChanged', () {
    late _StubPainter painter;

    Future<void> mountSettled(WidgetTester tester) async {
      painter = _StubPainter(drawOptimization: DrawOptimization.drawOnChanged);
      await tester.pumpWidget(_host(painter));
      // The first frame always paints, then nothing changes.
      expect(painter.paints, greaterThanOrEqualTo(1));
      await tester.pump(_frame);
    }

    testWidgets('paints the first frame', (tester) async {
      painter = _StubPainter(drawOptimization: DrawOptimization.drawOnChanged);
      await tester.pumpWidget(_host(painter));

      expect(painter.paints, 1);
    });

    testWidgets('an artboard holding still causes no repaint', (tester) async {
      await mountSettled(tester);

      expect(await _paintsOver(tester, painter, count: 60), 0);
    });

    testWidgets('repaints the frames where the artboard changed',
        (tester) async {
      await mountSettled(tester);

      painter.changed = true;
      expect(await _paintsOver(tester, painter, count: 1), 1);
      expect(await _paintsOver(tester, painter), 0);
    });

    testWidgets('is a repaint boundary', (tester) async {
      await mountSettled(tester);

      expect(_renderBox(tester).isRepaintBoundary, isTrue);
    });

    testWidgets('repaints on resize', (tester) async {
      await mountSettled(tester);

      await tester.pumpWidget(_host(painter, size: const Size(120, 80)));

      expect(painter.paints, 2);
      expect(await _paintsOver(tester, painter), 0);
    });

    testWidgets('repaints when fit or alignment changes', (tester) async {
      await mountSettled(tester);

      painter.fit = Fit.cover;
      expect(await _paintsOver(tester, painter, count: 2), 1);

      painter.alignment = Alignment.topLeft;
      expect(await _paintsOver(tester, painter, count: 2), 1);
    });

    testWidgets('repaints when a repaint is scheduled', (tester) async {
      await mountSettled(tester);

      painter.scheduleRepaint();

      expect(await _paintsOver(tester, painter, count: 2), 1);
    });

    testWidgets('repaints when the painter is swapped', (tester) async {
      await mountSettled(tester);
      final next =
          _StubPainter(drawOptimization: DrawOptimization.drawOnChanged);

      await tester.pumpWidget(_host(next));
      await tester.pump(_frame);

      expect(next.paints, 1);
      expect(await _paintsOver(tester, next), 0);
    });

    testWidgets('repaints after a pointer event', (tester) async {
      await mountSettled(tester);

      await tester.tapAt(tester.getCenter(find.byType(SizedBox)));

      expect(await _paintsOver(tester, painter, count: 2), 1);
    });

    testWidgets('repaints after an image finished decoding', (tester) async {
      await mountSettled(tester);

      RiveImageDecodes.count++;

      expect(await _paintsOver(tester, painter, count: 2), 1);
    });

    testWidgets('paints the last advance before the animation settles',
        (tester) async {
      await mountSettled(tester);

      painter.keepGoing = false;

      expect(await _paintsOver(tester, painter, count: 1), 1);
      expect(await _paintsOver(tester, painter), 0);
    });

    testWidgets('switching back to alwaysDraw repaints every frame again',
        (tester) async {
      await mountSettled(tester);

      painter.drawOptimization = DrawOptimization.alwaysDraw;
      await tester.pump(_frame);

      expect(_renderBox(tester).isRepaintBoundary, isFalse);
      expect(await _paintsOver(tester, painter), 10);
    });
  });
}
