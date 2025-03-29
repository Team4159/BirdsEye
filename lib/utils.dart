import 'dart:async' show Completer, Timer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

class DeleteConfirmation extends IconButton {
  DeleteConfirmation(
      {super.key,
      required void Function()? reset,
      required BuildContext context,
      String toConfirm = "reset"})
      : super(
            icon: Icon(Icons.delete, color: Colors.red[800]),
            tooltip: toConfirm,
            onPressed: reset == null
                ? null
                : () => showDialog(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                            title: Text(
                                "Confirm ${toConfirm[0].toUpperCase()}${toConfirm.substring(1)}"),
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

extension ErrorReportingFuture<T> on Future<T> {
  Future<T> reportError(BuildContext context) => catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      });

  Future<T?> get nullifyErrors => catchError(() => null);
}

extension SOD<T> on Iterable<T> {
  /// Just like [Iterable.single], but returns null for no elements.
  T? get singleOrDie {
    Iterator<T> it = iterator;
    if (!it.moveNext()) return null;
    T result = it.current;
    if (it.moveNext()) throw StateError("Too many elements");
    return result;
  }
}

extension GrayLuminance on Color {
  /// A crappy approximation for a real luminance value, much faster.
  double get grayLuminance => (r + g + b) / 3;
}

extension Awaitable on Listenable {
  Future<void> get nextChange {
    final c = Completer();
    addListener(c.complete);
    return c.future.then((v) {
      removeListener(c.complete);
      return v;
    });
  }
}

extension Optional<T> on Iterable<T> {
  Iterable<T?> get optional => this as Iterable<T?>;
}

class ListenableOrNot extends StatelessWidget {
  final Listenable? listenable;
  final Widget Function(BuildContext, Widget?) builder;
  const ListenableOrNot({super.key, required this.listenable, required this.builder});

  @override
  Widget build(BuildContext context) => listenable == null
      ? Builder(builder: (context) => builder(context, null))
      : ListenableBuilder(listenable: listenable!, builder: builder);
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

class NotifiableValueNotifier<T> extends ValueNotifier<T> {
  NotifiableValueNotifier(super.value);

  @override
  void notifyListeners() => super.notifyListeners();
}

class SliverAnimatedInList<T> extends StatefulWidget {
  final List<T> list;
  final Widget Function(BuildContext, T) builder;
  final GlobalKey<SliverAnimatedListState> animKey;
  SliverAnimatedInList(this.list,
      {required this.builder, GlobalKey<SliverAnimatedListState>? animKey, super.key})
      : animKey = animKey ?? GlobalKey();

  @override
  State<StatefulWidget> createState() => _SliverAnimatedInListState<T>();
}

class _SliverAnimatedInListState<T> extends State<SliverAnimatedInList<T>> {
  late Timer animation;

  @override
  void initState() {
    int i = 0;
    animation = Timer.periodic(Durations.short2, (t) {
      if (i < widget.list.length) {
        setState(() => widget.animKey.currentState!.insertItem(i++, duration: Durations.medium3));
      } else {
        t.cancel();
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    if (animation.isActive) animation.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SliverAnimatedList(
      key: widget.animKey,
      itemBuilder: (context, i, anim) => i >= widget.list.length
          ? const SizedBox()
          : AnimatedSlide(
              offset: Offset(0, (1 - anim.value) * (widget.list.length - i)),
              duration: Durations.medium3,
              child: widget.builder(context, widget.list[i])));
}

class SensibleDropdown<T> extends StatefulWidget {
  final String? label;
  final double width;

  final List<T>? values;
  final void Function(T?)? onChanged;
  const SensibleDropdown(this.values, {super.key, required this.width, this.label, this.onChanged});

  @override
  State<StatefulWidget> createState() => SensibleDropdownState<T>();
}

class SensibleDropdownState<T> extends State<SensibleDropdown<T>> {
  T? value;

  @override
  Widget build(BuildContext context) => ButtonTheme(
      alignedDropdown: true,
      minWidth: 16,
      padding: EdgeInsets.all(0),
      child: DropdownButton<T?>(
          alignment: Alignment.bottomCenter,
          menuWidth: widget.width,
          padding: const EdgeInsets.all(0),
          borderRadius: BorderRadius.circular(4),
          focusColor: Colors.transparent,
          isExpanded: false,
          hint: widget.label == null ? null : Text(widget.label!),
          value: value,
          items: widget.values == null
              ? null
              : [
                  DropdownMenuItem(value: null, child: SizedBox()),
                  for (final v in widget.values!)
                    DropdownMenuItem(
                        value: v,
                        alignment: Alignment.center,
                        child: Text(v.toString(), overflow: TextOverflow.ellipsis))
                ],
          onChanged: (v) {
            setState(() => value = v);
            if (widget.onChanged != null) widget.onChanged!(v);
          }));
}
