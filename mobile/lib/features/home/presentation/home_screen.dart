import 'package:flutter/material.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/shared/widgets/section_placeholder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionPlaceholder(
      title: 'MY LIFE',
      message: context.strings.get('homeMessage'),
    );
  }
}
