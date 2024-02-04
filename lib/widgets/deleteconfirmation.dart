import 'package:flutter/material.dart';
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
