import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/core/localization/locale_controller.dart';
import 'package:my_life/features/settings/application/app_info_provider.dart';

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  bool _savingLanguage = false;
  int _languageRevision = 0;

  @override
  Widget build(BuildContext context) {
    final localeState = ref.watch(localeControllerProvider);
    final locale = localeState.value ?? const Locale('ko');
    final selected = locale.languageCode == 'en'
        ? AppLanguage.english
        : AppLanguage.korean;
    final appInfo = ref.watch(appInfoProvider);
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
          KeyedSubtree(
            key: ValueKey(
              'language-field-${selected.languageCode}-$_languageRevision',
            ),
            child: DropdownButtonFormField<AppLanguage>(
              key: const Key('language-selector'),
              isExpanded: true,
              initialValue: selected,
              decoration: InputDecoration(
                labelText: context.strings.get('language'),
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
              onChanged: _savingLanguage || localeState.isLoading
                  ? null
                  : (language) async {
                      if (language != null) {
                        setState(() => _savingLanguage = true);
                        final saved = await ref
                            .read(localeControllerProvider.notifier)
                            .setLanguage(language);
                        if (!mounted) return;
                        setState(() {
                          _savingLanguage = false;
                          if (!saved) _languageRevision++;
                        });
                        if (!saved && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.strings.get('languageSaveError'),
                              ),
                            ),
                          );
                        }
                      }
                    },
            ),
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
          ListTile(
            key: const Key('payment-import-entry'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(context.strings.get('paymentImport')),
            subtitle: Text(context.strings.get('paymentImportHint')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/payment-import'),
          ),
          const SizedBox(height: 28),
          Text(
            context.strings.get('localStorageTitle'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.strings.get('localStorageWarning'),
            key: const Key('local-storage-warning'),
          ),
          const SizedBox(height: 28),
          Text(
            context.strings.get('appInformation'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          appInfo.when(
            data: (info) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.strings.get('appVersion')),
              subtitle: Text(
                info.displayVersion,
                key: const Key('app-version'),
              ),
            ),
            loading: () =>
                const LinearProgressIndicator(key: Key('app-info-loading')),
            error: (_, _) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.strings.get('appInfoError')),
              trailing: IconButton(
                key: const Key('app-info-retry'),
                tooltip: context.strings.get('retry'),
                onPressed: () => ref.invalidate(appInfoProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          ListTile(
            key: const Key('open-source-licenses'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.strings.get('openSourceLicenses')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'MY LIFE',
              applicationVersion: appInfo.value?.displayVersion,
            ),
          ),
        ],
      ),
    );
  }
}
