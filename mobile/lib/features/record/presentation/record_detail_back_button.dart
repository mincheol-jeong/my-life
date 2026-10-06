import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';

class RecordDetailBackButton extends StatelessWidget {
  const RecordDetailBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    return IconButton(
      tooltip: canPop
          ? MaterialLocalizations.of(context).backButtonTooltip
          : context.strings.get('goHome'),
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
    );
  }
}
