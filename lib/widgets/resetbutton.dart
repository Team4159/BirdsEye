import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeleteConfirmation extends IconButton {
  DeleteConfirmation(
      {super.key,
      required void Function() reset,
      required BuildContext context,
      String title = "Confirm Reset",
      String subtitle = "Are you sure you want to reset?"})
      : super(
            focusNode: FocusNode(skipTraversal: true),
            icon: Icon(Icons.delete, color: Colors.red[800]),
            tooltip: "Reset",
            onPressed: () => showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                        title: Text(title),
                        content: Text(subtitle),
                        actions: [
                          OutlinedButton(
                              onPressed: () => GoRouter.of(context).pop(),
                              child: const Text("Cancel",
                                  textAlign: TextAlign.end)),
                          FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                reset();
                              },
                              child:
                                  const Text("Reset", textAlign: TextAlign.end))
                        ])));
}
