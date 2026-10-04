import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/core/localization/locale_controller.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale =
        ref.watch(localeControllerProvider).value ?? const Locale('ko');
    final selected = locale.languageCode == 'en'
        ? AppLanguage.english
        : AppLanguage.korean;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.get('me'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            context.strings.get('language'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            context.strings.get('languageHint'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AppLanguage>(
            key: const Key('language-selector'),
            initialValue: selected,
            decoration: InputDecoration(
              labelText: context.strings.get('language'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: AppLanguage.korean,
                child: Text(context.strings.get('korean')),
              ),
              DropdownMenuItem(
                value: AppLanguage.english,
                child: Text(context.strings.get('english')),
              ),
            ],
            onChanged: (language) {
              if (language != null) {
                ref
                    .read(localeControllerProvider.notifier)
                    .setLanguage(language);
              }
            },
          ),
          const SizedBox(height: 28),
          Text(
            context.strings.get('connections'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ListTile(
            key: const Key('calendar-import-entry'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(context.strings.get('calendarImport')),
            subtitle: Text(context.strings.get('calendarImportHint')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/calendar-import'),
          ),
        ],
      ),
    );
  }
}
