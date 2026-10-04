import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';

Future<void> showRecordCreationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) =>
        const RecordCreationChoices(closeBeforeNavigation: true),
  );
}

class RecordEntryScreen extends StatelessWidget {
  const RecordEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.get('record'))),
      body: const SafeArea(child: RecordCreationChoices()),
    );
  }
}

class RecordCreationChoices extends StatelessWidget {
  const RecordCreationChoices({this.closeBeforeNavigation = false, super.key});

  final bool closeBeforeNavigation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.get('recordQuestion'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            key: const Key('create-memo-button'),
            onPressed: () {
              if (closeBeforeNavigation) {
                Navigator.of(context).pop();
              }
              context.push('/records/memo/new');
            },
            icon: const Icon(Icons.edit_note_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(context.strings.get('memo')),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('create-photo-button'),
            onPressed: () {
              if (closeBeforeNavigation) {
                Navigator.of(context).pop();
              }
              context.push('/records/photo/new');
            },
            icon: const Icon(Icons.photo_camera_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(context.strings.get('photo')),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('create-expense-button'),
            onPressed: () {
              if (closeBeforeNavigation) {
                Navigator.of(context).pop();
              }
              context.push('/records/expense/new');
            },
            icon: const Icon(Icons.payments_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(context.strings.get('expense')),
            ),
          ),
        ],
      ),
    );
  }
}
