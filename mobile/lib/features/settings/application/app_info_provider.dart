import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppInfo {
  const AppInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  String get displayVersion => '$version+$buildNumber';
}

final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  const channel = MethodChannel('com.mincheol.mylife/app_info');
  final values = await channel.invokeMapMethod<String, String>('getAppInfo');
  final version = values?['version'];
  final build = values?['buildNumber'];
  if (version == null || version.isEmpty || build == null || build.isEmpty) {
    throw StateError('App information unavailable');
  }
  return AppInfo(version: version, buildNumber: build);
}, retry: (retryCount, error) => null);
