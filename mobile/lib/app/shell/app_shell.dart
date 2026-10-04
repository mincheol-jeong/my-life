import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/record/presentation/record_entry_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        key: const Key('record-fab'),
        onPressed: () => showRecordCreationSheet(context),
        tooltip: context.strings.get('recordAdd'),
        child: const Icon(Icons.add_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _Destination(
                label: context.strings.get('home'),
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                selected: location == '/',
                onTap: () => context.go('/'),
              ),
              _Destination(
                label: context.strings.get('timeline'),
                icon: Icons.auto_stories_outlined,
                selectedIcon: Icons.auto_stories_rounded,
                selected: location == '/timeline',
                onTap: () => context.go('/timeline'),
              ),
              const SizedBox(width: 72),
              _Destination(
                label: context.strings.get('finance'),
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet_rounded,
                selected: location == '/finance',
                onTap: () => context.go('/finance'),
              ),
              _Destination(
                label: context.strings.get('me'),
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                selected: location == '/me',
                onTap: () => context.go('/me'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
