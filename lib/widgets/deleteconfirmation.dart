import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeleteConfirmation extends IconButton {
  DeleteConfirmation(
      {super.key,
      required void Function() reset,
      required BuildContext context})
      : super(
            focusNode: FocusNode(skipTraversal: true),
            icon: Icon(Icons.delete, color: Colors.red[800]),
            tooltip: "Reset",
            onPressed: () => showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                        title: const Text("Confirm Reset"),
                        content: const Text("Are you sure you want to reset?"),
                        actions: [
                          OutlinedButton(
                              onPressed: () => GoRouter.of(context).pop(),
                              child: const Text("Cancel")),
                          FilledButton(
                              onPressed: () {
                                GoRouter.of(context).pop();
                                reset();
                              },
                              child: const Text("Reset"))
                        ])));
}
