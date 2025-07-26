import 'dart:async' show Completer;

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

class NotifiableChangeNotifier extends ChangeNotifier {
  @override
  void notifyListeners() => super.notifyListeners();
}

class SensibleDropdown<T> extends StatefulWidget {
  final String? label;
  final double? width;

  final List<T>? values;
  final T? initial;
  final void Function(T?)? onChanged;
  final DropdownMenuItem<T> Function(T value)? itemBuilder;
  const SensibleDropdown(this.values,
      {super.key, this.width, this.label, this.initial, this.onChanged, this.itemBuilder});

  @override
  State<StatefulWidget> createState() => SensibleDropdownState<T>();
}

class SensibleDropdownState<T> extends State<SensibleDropdown<T>> {
  T? value;

  @override
  void initState() {
    value = widget.initial;
    super.initState();
  }

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
                    (widget.itemBuilder ??
                        (v) => DropdownMenuItem(
                            value: v,
                            alignment: Alignment.center,
                            child: Text(v.toString(), overflow: TextOverflow.ellipsis)))(v)
                ],
          onChanged: (v) {
            setState(() => value = v);
            if (widget.onChanged != null) widget.onChanged!(v);
          }));
}

class SensibleFutureBuilder<T> extends FutureBuilder<T> {
  SensibleFutureBuilder(
      {super.key,
      required super.future,
      required AsyncWidgetBuilder<T> builder,
      ProgressIndicator progressIndicator = const CircularProgressIndicator()})
      : super(builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                  Text(snapshot.error?.toString() ?? "No Data")
                ]);
          }
          if (!snapshot.hasData) return Center(child: progressIndicator);
          return builder(context, snapshot);
        });
}
