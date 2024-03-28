import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:go_router/go_router.dart';

class DeleteConfirmation extends IconButton {
  DeleteConfirmation(
      {super.key,
      required void Function() reset,
      required BuildContext context,
      String toConfirm = "reset"})
      : super(
            icon: Icon(Icons.delete, color: Colors.red[800]),
            tooltip: toConfirm,
            onPressed: () => showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                        title:
                            Text("Confirm ${toConfirm[0].toUpperCase()}${toConfirm.substring(1)}"),
                        content: Text("Are you sure you want to $toConfirm?"),
                        actions: [
                          OutlinedButton(
                              onPressed: () => GoRouter.of(context).pop(),
                              child: const Text("Cancel")),
                          FilledButton(
                              onPressed: () {
                                GoRouter.of(context).pop();
                                reset();
                              },
                              child: const Text("Confirm"))
                        ])));
}

/// A [ChangeNotifier] that holds a single lazily-initialized value.
///
/// When [value] is replaced with something that is not equal to the old
/// value as evaluated by the equality operator ==, this class notifies its
/// listeners, unless it's the first time value is set.
///
/// ## Limitations
///
/// Because this class only notifies listeners when the [value]'s _identity_
/// changes, listeners will not be notified when mutable state within the
/// value itself changes.
///
/// For example, a `ValueNotifier<List<int>>` will not notify its listeners
/// when the _contents_ of the list are changed.
///
/// As a result, this class is best used with only immutable data types.
///
/// For mutable data types, consider extending [ChangeNotifier] directly.
class LateValueNotifier<T extends Object> extends ChangeNotifier implements ValueListenable<T> {
  /// Creates a [ChangeNotifier] that wraps this value.
  LateValueNotifier() {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  /// The current value stored in this notifier.
  ///
  /// When the value is replaced with something that is not equal to the old
  /// value as evaluated by the equality operator ==, this class notifies its
  /// listeners.
  @override
  T get value => _value!;
  T? _value;
  set value(T newValue) {
    if (_value == null) {
      _value = newValue;
      return;
    }
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }

  bool get isInitialized => _value != null;

  @override
  String toString() => '${describeIdentity(this)}($value)';
}

class NotifiableTextEditingController extends TextEditingController {
  @override
  void notifyListeners() => super.notifyListeners();
}

class NotifiableChangeNotifier extends ChangeNotifier {
  @override
  void notifyListeners() {
    super.notifyListeners();
  }
}

/// A [ChangeNotifier] that holds a single double value.
///
/// When [value] is replaced with something that is not equal to the old
/// value as evaluated by the equality operator == and switches between
/// zero and nonzero, this class notifies its listeners.
class BinaryValueNotifier extends ChangeNotifier implements ValueListenable<double> {
  /// Creates a [ChangeNotifier] that wraps this value.
  BinaryValueNotifier(this._value) {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  /// The current value stored in this notifier.
  ///
  /// When the value is replaced with something that is not equal to the old
  /// value as evaluated by the equality operator ==, this class notifies its
  /// listeners.
  @override
  double get value => _value;
  double _value;
  set value(double newValue) {
    if (_value == newValue) return;
    double oldValue = _value;
    _value = newValue;
    if (oldValue == 0 || newValue == 0) notifyListeners();
  }

  @override
  String toString() => '${describeIdentity(this)}($value)';
}

/// Used with [TabBar.indicator] to draw a rounded line around the
/// top of the selected tab.
///
/// The selected tab border is inset from the tab's boundary by [insets].
/// The [borderSide] defines the line's color and weight.
///
/// The [TabBar.indicatorSize] property can be used to define the indicator's
/// bounds in terms of its (centered) widget with [TabBarIndicatorSize.label],
/// or the entire tab with [TabBarIndicatorSize.tab].
class HitchedTabIndicator extends Decoration {
  /// Create an underline style selected tab indicator.
  const HitchedTabIndicator({
    this.borderRadius,
    this.borderSide = const BorderSide(width: 2.0, color: Colors.white),
    this.insets = EdgeInsets.zero,
  });

  /// The radius of the indicator's corners.
  ///
  /// If this value is non-null, rounded rectangular tab indicator is
  /// drawn, otherwise rectangular tab indictor is drawn.
  final BorderRadius? borderRadius;

  /// The color and weight of the horizontal line drawn below the selected tab.
  final BorderSide borderSide;

  /// Locates the selected tab's underline relative to the tab's boundary.
  ///
  /// The [TabBar.indicatorSize] property can be used to define the tab
  /// indicator's bounds in terms of its (centered) tab widget with
  /// [TabBarIndicatorSize.label], or the entire tab with
  /// [TabBarIndicatorSize.tab].
  final EdgeInsetsGeometry insets;

  @override
  Decoration? lerpFrom(Decoration? a, double t) {
    if (a is HitchedTabIndicator) {
      return HitchedTabIndicator(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        insets: EdgeInsetsGeometry.lerp(a.insets, insets, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  Decoration? lerpTo(Decoration? b, double t) {
    if (b is HitchedTabIndicator) {
      return HitchedTabIndicator(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        insets: EdgeInsetsGeometry.lerp(insets, b.insets, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _HitchedPainter(this, borderRadius, onChanged);
  }

  Rect _indicatorRectFor(Rect rect, TextDirection textDirection) {
    final Rect indicator = insets.resolve(textDirection).deflateRect(rect);
    return Rect.fromLTRB(
        indicator.left, indicator.bottom - borderSide.width, indicator.right, indicator.bottom);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    if (borderRadius != null) {
      return Path()..addRRect(borderRadius!.toRRect(_indicatorRectFor(rect, textDirection)));
    }
    return Path()..addRect(_indicatorRectFor(rect, textDirection));
  }
}

class _HitchedPainter extends BoxPainter {
  _HitchedPainter(
    this.decoration,
    this.borderRadius,
    super.onChanged,
  );

  final HitchedTabIndicator decoration;
  final BorderRadius? borderRadius;

  Path _getPath(RRect rrect) {
    final double left = math.max(1, rrect.left);
    final double right = rrect.right;
    final double top = rrect.top;
    final double bottom = rrect.bottom;
    //  Radii will be clamped to the value of the shortest side
    // of rrect to avoid strange tie-fighter shapes.
    final double tlRadiusX = math.max(0.0, math.min(rrect.shortestSide, rrect.tlRadiusX));
    final double tlRadiusY = math.max(0.0, math.min(rrect.shortestSide, rrect.tlRadiusY));
    final double trRadiusX = math.max(0.0, math.min(rrect.shortestSide, rrect.trRadiusX));
    final double trRadiusY = math.max(0.0, math.min(rrect.shortestSide, rrect.trRadiusY));
    final double blRadiusX = math.max(0.0, math.min(rrect.shortestSide, rrect.blRadiusX));
    final double blRadiusY = math.max(0.0, math.min(rrect.shortestSide, rrect.blRadiusY));
    final double brRadiusX = math.max(0.0, math.min(rrect.shortestSide, rrect.brRadiusX));
    final double brRadiusY = math.max(0.0, math.min(rrect.shortestSide, rrect.brRadiusY));

    final double endWidth = rrect.width * 3 - 1;
    final Path p = Path();
    p.moveTo(1, bottom + blRadiusY);
    if (left - blRadiusX >= 0) {
      p.cubicTo(0, bottom, 0, bottom, blRadiusX, bottom);
      p.lineTo(left - blRadiusX, bottom);
      p.cubicTo(left, bottom, left, bottom, left, bottom - blRadiusY);
    }
    p.lineTo(left, top + tlRadiusX);
    p.cubicTo(left, top, left, top, left + tlRadiusY, top);
    p.lineTo(right - trRadiusX, top);
    p.cubicTo(right, top, right, top, right, top + trRadiusY);
    p.lineTo(right, bottom - brRadiusX);
    if (right + brRadiusY <= endWidth) {
      p.cubicTo(right, bottom, right, bottom, right + brRadiusY, bottom);
      p.lineTo(endWidth - brRadiusX, bottom);
      p.cubicTo(endWidth, bottom, endWidth, bottom, endWidth, bottom + brRadiusY);
    } else {
      p.lineTo(endWidth, bottom + brRadiusY);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final Rect rect = offset & configuration.size!;
    canvas.drawPath(_getPath(borderRadius!.resolve(configuration.textDirection!).toRRect(rect)),
        decoration.borderSide.toPaint());
  }
}

class ToplessHitchedBorder extends BoxBorder {
  /// Creates a border.
  ///
  /// All the sides of the border default to [BorderSide.none].
  const ToplessHitchedBorder(BorderSide side) : bottom = side;

  /// The sides default to black solid borders, one logical pixel wide.
  factory ToplessHitchedBorder.all({
    Color color = const Color(0xFF000000),
    double width = 1.0,
    BorderStyle style = BorderStyle.solid,
    double strokeAlign = BorderSide.strokeAlignInside,
  }) {
    final BorderSide side =
        BorderSide(color: color, width: width, style: style, strokeAlign: strokeAlign);
    return ToplessHitchedBorder(side);
  }

  /// Creates a [ToplessHitchedBorder] that represents the addition of the two given
  /// [ToplessHitchedBorder]s.
  ///
  /// It is only valid to call this if [BorderSide.canMerge] returns true for
  /// the pairwise combination of each side on both [ToplessHitchedBorder]s.
  static ToplessHitchedBorder merge(ToplessHitchedBorder a, ToplessHitchedBorder b) {
    assert(BorderSide.canMerge(a.bottom, b.bottom));
    return ToplessHitchedBorder(
      BorderSide.merge(a.bottom, b.bottom),
    );
  }

  @override
  final BorderSide top = BorderSide.none;

  @override
  final BorderSide bottom;

  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.fromLTRB(bottom.strokeInset, 0, bottom.strokeInset, bottom.strokeInset);

  @override
  bool get isUniform => true;

  @override
  ToplessHitchedBorder? add(ShapeBorder other, {bool reversed = false}) {
    if (other is ToplessHitchedBorder && BorderSide.canMerge(bottom, other.bottom)) {
      return ToplessHitchedBorder.merge(this, other);
    }
    return null;
  }

  @override
  ToplessHitchedBorder scale(double t) {
    return ToplessHitchedBorder(bottom.scale(t));
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is ToplessHitchedBorder) {
      return ToplessHitchedBorder.lerp(a, this, t);
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is ToplessHitchedBorder) {
      return ToplessHitchedBorder.lerp(this, b, t);
    }
    return super.lerpTo(b, t);
  }

  /// Linearly interpolate between two borders.
  ///
  /// If a border is null, it is treated as having four [BorderSide.none]
  /// borders.
  ///
  /// {@macro dart.ui.shadow.lerp}
  static ToplessHitchedBorder? lerp(ToplessHitchedBorder? a, ToplessHitchedBorder? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    return ToplessHitchedBorder(BorderSide.lerp(a.bottom, b.bottom, t));
  }

  Path _getPathNonRound(Rect rect) {
    final double left = rect.left;
    final double right = rect.right;
    final double top = rect.top;
    final double bottom = rect.bottom;

    return Path()
      ..moveTo(left, top)
      ..lineTo(left, bottom)
      ..lineTo(right, bottom)
      ..lineTo(right, top);
  }

  Path _getPath(RRect rrect) {
    final double left = rrect.left;
    final double right = rrect.right;
    final double top = rrect.top;
    final double bottom = rrect.bottom;
    //  Radii will be clamped to the value of the shortest side
    // of rrect to avoid strange tie-fighter shapes.
    final double blRadiusX = math.max(0.0, math.min(rrect.shortestSide, rrect.blRadiusX));
    final double blRadiusY = math.max(0.0, math.min(rrect.shortestSide, rrect.blRadiusY));
    final double brRadiusX = math.max(0.0, math.min(rrect.shortestSide, rrect.brRadiusX));
    final double brRadiusY = math.max(0.0, math.min(rrect.shortestSide, rrect.brRadiusY));

    return Path()
      ..moveTo(left, top + blRadiusY)
      ..lineTo(left, bottom - blRadiusY)
      ..cubicTo(left, bottom, left, bottom, left + blRadiusX, bottom)
      ..lineTo(right - brRadiusX, bottom)
      ..cubicTo(right, bottom, right, bottom, right, bottom - brRadiusY)
      ..lineTo(right, top + brRadiusY);
  }

  /// Paints the border within the given [Rect] on the given [Canvas].
  ///
  /// Uniform borders and non-uniform borders with similar colors and styles
  /// are more efficient to paint than more complex borders.
  ///
  /// You can provide a [BoxShape] to draw the border on. If the `shape` in
  /// [BoxShape.circle], there is the requirement that the border has uniform
  /// color and style.
  ///
  /// If you specify a rectangular box shape ([BoxShape.rectangle]), then you
  /// may specify a [BorderRadius]. If a `borderRadius` is specified, there is
  /// the requirement that the border has uniform color and style.
  ///
  /// The [getInnerPath] and [getOuterPath] methods do not know about the
  /// `shape` and `borderRadius` arguments.
  ///
  /// The `textDirection` argument is not used by this paint method.
  ///
  /// See also:
  ///
  ///  * [paintBorder], which is used if the border has non-uniform colors or styles and no borderRadius.
  ///  * <https://pub.dev/packages/non_uniform_border>, a package that implements
  ///    a Non-Uniform Border on ShapeBorder, which is used by Material Design
  ///    buttons and other widgets, under the "shape" field.
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    if (isUniform) {
      switch (bottom.style) {
        case BorderStyle.none:
          return;
        case BorderStyle.solid:
          switch (shape) {
            case BoxShape.circle:
              assert(borderRadius == null,
                  'A borderRadius cannot be given when shape is a BoxShape.circle.');
              final double radius = (rect.shortestSide + bottom.strokeOffset) / 2;
              canvas.drawCircle(rect.center, radius, bottom.toPaint());
            case BoxShape.rectangle:
              if (borderRadius != null && borderRadius != BorderRadius.zero) {
                canvas.drawPath(
                    _getPath(borderRadius.resolve(textDirection!).toRRect(rect)), bottom.toPaint());
                return;
              }
              canvas.drawPath(_getPathNonRound(rect), bottom.toPaint());
          }
          return;
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ToplessHitchedBorder && other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(top, bottom);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'ToplessHitchedBorder')}($bottom)';
  }
}

class SliverAnimatedInList<T> extends StatefulWidget {
  final List<T> list;
  final Widget Function(BuildContext, T) builder;
  const SliverAnimatedInList(this.list, {required this.builder, super.key});

  @override
  State<StatefulWidget> createState() => _SliverAnimatedInListState();
}

class _SliverAnimatedInListState extends State<SliverAnimatedInList> {
  final GlobalKey<SliverAnimatedListState> _animKey = GlobalKey();

  @override
  void initState() {
    _refresh();
    super.initState();
  }

  void _refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.forEach(
          widget.list.indexed,
          (e) => Future.delayed(
              Durations.short2,
              () => setState(() {
                    _animKey.currentState!.insertItem(e.$1, duration: Durations.medium3);
                  }))).then((_) => Future.delayed(Durations.medium3, () => setState(() {})));
    }, debugLabel: "AnimatedList Handler");
  }

  @override
  Widget build(BuildContext context) => SliverAnimatedList(
      key: _animKey,
      itemBuilder: (context, i, anim) => i >= widget.list.length
          ? const SizedBox()
          : AnimatedSlide(
              offset: Offset(0, (1 - anim.value) * (widget.list.length - i)),
              duration: Durations.medium3,
              child: widget.builder(context, widget.list[i])));
}
