part of 'form.dart';

class CustomTextFormField extends TextFormField {
  CustomTextFormField({String? labelText, super.onSaved, super.key})
      : super(
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              labelText: labelText,
              filled: true,
              labelStyle: TextStyle(fontWeight: FontWeight.w500),
            ));
}

class CounterFormField extends FormField<int> {
  CounterFormField(
      {super.key,
      super.onSaved,
      super.initialValue = 0,
      String? labelText,
      int? season})
      : super(builder: (FormFieldState<int> state) {
          Color? customColor =
              labelText == null ? null : _getColor(labelText, season);
          return Material(
              type: MaterialType.button,
              borderRadius: BorderRadius.circular(4),
              color: customColor ??
                  Theme.of(state.context).colorScheme.tertiaryContainer,
              child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => state.didChange(state.value! + 1),
                  child: Stack(fit: StackFit.passthrough, children: [
                    Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(flex: 1, child: SizedBox()),
                          Expanded(
                              flex: 3,
                              child: FittedBox(
                                  child: labelText != null
                                      ? Text(labelText,
                                          style: TextStyle(
                                              color: customColor != null
                                                  ? customColor.grayLuminance >
                                                          0.5
                                                      ? Colors.grey[900]
                                                      : Colors.white
                                                  : Theme.of(state.context)
                                                      .colorScheme
                                                      .onTertiaryContainer))
                                      : null)),
                          Expanded(
                              flex: 5,
                              child: FittedBox(
                                  child: Text(state.value.toString(),
                                      style: TextStyle(
                                          color: customColor == null
                                              ? null
                                              : customColor.grayLuminance > 0.5
                                                  ? Colors.grey[900]
                                                  : Colors.white)))),
                          const Expanded(flex: 1, child: SizedBox()),
                        ]),
                    FractionallySizedBox(
                        widthFactor: 0.25,
                        alignment: Alignment.bottomRight,
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomRight,
                            child: IconButton(
                              iconSize: 64,
                              icon: const Icon(Icons.remove),
                              color: customColor != null &&
                                      customColor.grayLuminance > 0.5
                                  ? Colors.black54
                                  : Colors.white70,
                              onPressed: () => state.value! > 0
                                  ? state.didChange(state.value! - 1)
                                  : null,
                            )))
                  ])));
        });

  static Color? _getColor(String labelText, int? season) {
    final lower = labelText.toLowerCase();
    if (season != null && gamepiececolors.containsKey(season)) {
      for (final c in gamepiececolors[season]!.entries) {
        if (lower.startsWith(c.key)) return c.value;
      }
    }
    return null;
  }
}

/// A 0-5 star rating field
class RatingFormField extends FormField<double> {
  RatingFormField(
      {super.key, super.onSaved, super.initialValue, String? labelText})
      : super(
            builder: (FormFieldState<double> state) => Material(
                type: MaterialType.button,
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(state.context).colorScheme.secondaryContainer,
                child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(flex: 1, child: SizedBox(width: 4)),
                      Expanded(
                          flex: 3,
                          child: FittedBox(
                              child: labelText != null
                                  ? Text(labelText,
                                      style: TextStyle(
                                          color: Theme.of(state.context)
                                              .colorScheme
                                              .onSecondaryContainer))
                                  : null)),
                      Expanded(
                          flex: 5,
                          child: FittedBox(
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: List.generate(
                                      5,
                                      (index) => IconButton(
                                          onPressed: () => state
                                              .didChange(index / 5 + 1 / 5),
                                          iconSize: 36,
                                          tooltip: _labels[index],
                                          icon: index + 1 <=
                                                  (state.value ?? -1) * 5
                                              ? const Icon(Icons.star_rounded,
                                                  color: Colors.yellow)
                                              : const Icon(
                                                  Icons.star_border_rounded,
                                                  color: Colors.grey)))))),
                      const Expanded(flex: 1, child: SizedBox(width: 4)),
                    ])));

  static const List<String> _labels = ["poor", "bad", "okay", "good", "pro"];
}

class ToggleFormField extends FormField<bool> {
  ToggleFormField(
      {super.key, super.onSaved, super.initialValue = false, String? labelText})
      : super(
            builder: (FormFieldState<bool> state) => Material(
                type: MaterialType.button,
                borderRadius: BorderRadius.circular(4),
                color: state.value!
                    ? Theme.of(state.context).colorScheme.secondaryContainer
                    : Colors.grey,
                child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => state.didChange(!state.value!),
                    child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(flex: 1, child: SizedBox(width: 4)),
                          Expanded(
                              flex: 3,
                              child: FittedBox(
                                  child: labelText != null
                                      ? Text(labelText,
                                          style: TextStyle(
                                              color: state.value!
                                                  ? Theme.of(state.context)
                                                      .colorScheme
                                                      .onSecondaryContainer
                                                  : Colors.white))
                                      : null)),
                          Expanded(
                              flex: 5,
                              child: FittedBox(
                                  child: Text(state.value.toString()))),
                          const Expanded(flex: 1, child: SizedBox(width: 4)),
                        ]))));
}
