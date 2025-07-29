import 'package:flutter/material.dart';

class CustomDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final Widget? icon;
  final double iconSize;
  final double menuElevation;
  final double menuMaxHeight;

  const CustomDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.decoration = const InputDecoration(),
    this.icon,
    this.iconSize = 24.0,
    this.menuElevation = 8.0,
    this.menuMaxHeight = 200.0,
  });

  @override
  State<CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<CustomDropdown<T>> {
  final GlobalKey _widgetKey = GlobalKey();
  T? value;

  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    if (_isMenuOpen) return;

    final renderBox = _widgetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: offset.dx,
          top: offset.dy + size.height,
          width: size.width,
          child: _buildDropdownMenu(context),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isMenuOpen = true;
  }

  void _closeMenu() {
    if (!_isMenuOpen) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isMenuOpen = false;
  }

  Widget _buildDropdownMenu(BuildContext context) {
    return Material(
      elevation: widget.menuElevation,
      borderRadius: BorderRadius.circular(4.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.menuMaxHeight),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children:
              widget.items
                  ?.map(
                    (item) => InkWell(
                      onTap: () {
                        widget.onChanged?.call(item.value);
                        _closeMenu();
                      },
                      child: item,
                    ),
                  )
                  .toList(growable: false) ??
              List.empty(growable: false),
        ),
      ),
    );
  }

  Widget _buildSelectedItem() {
    if (widget.items != null) {
      for (final item in widget.items!) {
        if (item.value == widget.value) {
          return item.child;
        }
      }
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: (widget.onChanged != null && widget.items != null) ? _toggleMenu : null,
    child: InputDecorator(
      key: _widgetKey,
      decoration: widget.decoration.copyWith(
        suffixIcon:
            widget.decoration.suffixIcon ??
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8.0),
              child: Icon(
                Icons.arrow_drop_down,
                size: widget.iconSize,
                color: Theme.of(context).iconTheme.color,
              ),
            ),
      ),
      isEmpty: widget.value == null,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.titleMedium!,
          child: _buildSelectedItem(),
        ),
      ),
    ),
  );
}
