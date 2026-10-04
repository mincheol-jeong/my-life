import 'package:flutter/material.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/shared/widgets/section_placeholder.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionPlaceholder(
      title: context.strings.get('finance'),
      message: context.strings.get('financeMessage'),
    );
  }
}
