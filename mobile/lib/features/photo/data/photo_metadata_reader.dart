import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:native_exif/native_exif.dart';

class PhotoMetadataSuggestion {
  const PhotoMetadataSuggestion({this.capturedAt, this.placeName});

  final DateTime? capturedAt;
  final String? placeName;

  bool get isEmpty => capturedAt == null && placeName == null;
}

class PhotoMetadataReader {
  const PhotoMetadataReader();

  Future<PhotoMetadataSuggestion> read(
    String filePath, {
    required Locale locale,
  }) async {
    Exif? exif;
    try {
      exif = await Exif.fromPath(filePath);
      final capturedAt = await exif.getOriginalDate();
      final coordinates = await exif.getLatLong();
      String? placeName;
      if (coordinates != null) {
        placeName =
            await _reverseGeocode(coordinates, locale) ??
            '${coordinates.latitude.toStringAsFixed(5)}, '
                '${coordinates.longitude.toStringAsFixed(5)}';
      }
      return PhotoMetadataSuggestion(
        capturedAt: capturedAt,
        placeName: placeName,
      );
    } catch (_) {
      return const PhotoMetadataSuggestion();
    } finally {
      await exif?.close();
    }
  }

  Future<String?> _reverseGeocode(
    ExifLatLong coordinates,
    Locale locale,
  ) async {
    try {
      final placemarks = await Geocoding(
        locale: locale,
      ).placemarkFromCoordinates(coordinates.latitude, coordinates.longitude);
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final parts = <String>[
        if (_present(place.name)) place.name!.trim(),
        if (_present(place.subLocality)) place.subLocality!.trim(),
        if (_present(place.locality)) place.locality!.trim(),
        if (_present(place.administrativeArea))
          place.administrativeArea!.trim(),
      ];
      return parts.toSet().take(2).join(', ').trim().nullIfEmpty;
    } catch (_) {
      return null;
    }
  }

  bool _present(String? value) => value?.trim().isNotEmpty == true;
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
