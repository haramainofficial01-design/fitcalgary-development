import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef EvidencePicker = Future<PlatformFile?> Function(bool video);

// File selection is an OS boundary; uploads always use the same API transport.
final evidencePickerProvider = Provider<EvidencePicker>(
  (ref) => (video) {
    return FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: video ? ['mp4', 'mov'] : ['gpx'],
    );
  },
);
