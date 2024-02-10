import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
