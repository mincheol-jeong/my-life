import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';

void closeRecordForm(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

class RecordValueTile extends StatelessWidget {
  const RecordValueTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value),
    onTap: onTap,
    trailing: onClear == null
        ? const Icon(Icons.chevron_right_rounded)
        : IconButton(
            tooltip: context.strings.get('clearSelection'),
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
  );
}
