import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as images;
import 'package:image_picker/image_picker.dart';
import 'package:my_life/features/photo/application/photo_providers.dart';
import 'package:my_life/features/photo/data/photo_metadata_reader.dart';
import 'package:my_life/features/photo/presentation/photo_form_screen.dart';

void main() {
  late Directory directory;
  late File first;
  late File second;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('my_life_metadata_test_');
    final bytes = images.encodePng(images.Image(width: 8, height: 8));
    first = await File('${directory.path}/first.png').writeAsBytes(bytes);
    second = await File('${directory.path}/second.png').writeAsBytes(bytes);
  });
  tearDown(() => directory.delete(recursive: true));

  Future<_DelayedMetadata> open(WidgetTester tester) async {
    final reader = _DelayedMetadata();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recoveredPhotoPathsProvider.overrideWith(_NoRecoveredPhotos.new),
          photoPickerProvider.overrideWithValue(
            _Picker([XFile(first.path), XFile(second.path)]),
          ),
          photoMetadataReaderProvider.overrideWithValue(reader),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('ko'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PhotoFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-gallery-button')));
    await tester.pump();
    expect(reader.requests.keys, contains(first.path));
    return reader;
  }

  testWidgets('late metadata preserves the manually edited date and place', (
    tester,
  ) async {
    final reader = await open(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('photo-place-field')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('photo-place-field')),
      'My place',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    final dateTile = find.widgetWithIcon(
      ListTile,
      Icons.calendar_today_outlined,
    );
    await tester.ensureVisible(dateTile);
    await tester.tap(dateTile);
    await tester.pump();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 10, 9));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pump();
    reader.requests[first.path]!.complete(
      PhotoMetadataSuggestion(
        capturedAt: DateTime(2020, 1, 1, 12),
        placeName: 'EXIF place',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2026.10.09'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('photo-place-field')))
          .controller!
          .text,
      'My place',
    );
    expect(find.text('12:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'removing the first photo ignores its late metadata and uses the new first photo',
    (tester) async {
      final reader = await open(tester);
      await tester.tap(find.byTooltip('Remove selection').first);
      await tester.pump();
      expect(reader.requests.keys, contains(second.path));
      reader.requests[second.path]!.complete(
        PhotoMetadataSuggestion(
          capturedAt: DateTime(2022, 2, 2),
          placeName: 'Second place',
        ),
      );
      await tester.pumpAndSettle();
      reader.requests[first.path]!.complete(
        PhotoMetadataSuggestion(
          capturedAt: DateTime(2020, 1, 1),
          placeName: 'First place',
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('photo-place-field')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('photo-place-field')))
            .controller!
            .text,
        'Second place',
      );
      expect(find.text('2022.02.02'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _NoRecoveredPhotos extends RecoveredPhotoPaths {
  @override
  Future<List<String>> build() async => [];
}

class _DelayedMetadata extends PhotoMetadataReader {
  final requests = <String, Completer<PhotoMetadataSuggestion>>{};
  @override
  Future<PhotoMetadataSuggestion> read(
    String filePath, {
    required Locale locale,
  }) => (requests[filePath] = Completer<PhotoMetadataSuggestion>()).future;
}

class _Picker extends ImagePicker {
  _Picker(this.files);
  final List<XFile> files;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => files;
}
