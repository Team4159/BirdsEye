import 'dart:math' show min;
import 'dart:ui';

import 'package:flutter/material.dart';

/// [DropdownButton] alternative utilizing [InputDecoration]
class SensibleDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;

  final InputDecoration decoration;
  final double menuMaxHeight;

  const SensibleDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.decoration = const InputDecoration(),
    this.menuMaxHeight = 200.0,
  });

  @override
  State<SensibleDropdown<T>> createState() => _SensibleDropdownState<T>();
}

class _SensibleDropdownState<T> extends State<SensibleDropdown<T>> {
  _SensibleDropdownMenu<T>? _menu;

  T? value;

  @override
  void initState() {
    value = widget.value;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant SensibleDropdown<T> oldWidget) {
    value = widget.value;
    _forceCloseMenu();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (value != widget.value && widget.onChanged != null) widget.onChanged!(value);
  }

  @override
  void deactivate() {
    _forceCloseMenu();
    super.deactivate();
  }

  void _openMenu() {
    /// If the menu is already open, ignore
    if (_menu != null) return;

    /// If the widget is empty, ignore
    if (widget.items == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final navigator = Navigator.of(context);

    final buttonRect =
        renderBox.localToGlobal(Offset.zero, ancestor: navigator.context.findRenderObject()) &
        renderBox.size;

    navigator
        .push(
          _menu = _SensibleDropdownMenu(
            widget.items!,
            buttonRect: buttonRect,
            maxHeight: widget.menuMaxHeight,
          ),
        )
        .then((v) => value != v ? setState(() => value = v) : null)
        .then((_) => _menu = null);
  }

  void _forceCloseMenu() {
    if (_menu == null) return;
    Navigator.of(context).removeRoute(_menu!);
    _menu = null;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.items != null ? _openMenu : null,
    child: InputDecorator(
      decoration: widget.decoration.suffixIcon != null
          ? widget.decoration
          : widget.decoration.copyWith(suffixIcon: const Icon(Icons.arrow_drop_down, size: 24)),
      isEmpty: value == null,
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.titleMedium!,
        child:
            widget.items
                ?.cast<DropdownMenuItem<T>?>()
                .firstWhere((i) => i!.value == value, orElse: () => null)
                ?.child ??
            const SizedBox.expand(),
      ),
    ),
  );
}

class _SensibleDropdownMenu<T> extends PopupRoute<T> {
  final List<DropdownMenuItem<T>> items;
  final Rect buttonRect;
  final double maxHeight;
  _SensibleDropdownMenu(this.items, {required this.buttonRect, required this.maxHeight});

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => "Dismiss Dropdown";

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => FadeTransition(
    opacity: animation,
    child: CustomSingleChildLayout(
      delegate: _SensibleDropdownMenuLayout(buttonRect: buttonRect, maxHeight: maxHeight),
      child: Semantics(
        role: SemanticsRole.menu,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        child: Material(
          elevation: 8,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.titleMedium!,
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: kMaterialListPadding,
              shrinkWrap: true,
              children: [
                for (final item in items)
                  Semantics(
                    role: SemanticsRole.menuItem,
                    button: true,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, item.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: item,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Duration get transitionDuration => Durations.short3;
}

class _SensibleDropdownMenuLayout<T> extends SingleChildLayoutDelegate {
  _SensibleDropdownMenuLayout({required this.buttonRect, required this.maxHeight});

  final Rect buttonRect;
  final double maxHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // The width of a menu should be at most the view width. This ensures that
    // the menu does not extend past the left and right edges of the screen.
    final double width = min(constraints.maxWidth, buttonRect.width);
    return BoxConstraints(minWidth: width, maxWidth: width, maxHeight: maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    clampDouble(buttonRect.left, 0, size.width),
    clampDouble(buttonRect.bottom, 0, size.height),
  );

  @override
  bool shouldRelayout(_SensibleDropdownMenuLayout<T> oldDelegate) =>
      buttonRect != oldDelegate.buttonRect;
}
