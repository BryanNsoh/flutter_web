import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:file_selector/file_selector.dart';

class WebFolderPicker {
  static Future<List<XFile>> pickFolder() async {
    final completer = Completer<List<XFile>>();

    final input = html.FileUploadInputElement()
      ..setAttribute('webkitdirectory', '')
      ..setAttribute('directory', '')
      ..multiple = true;

    html.document.body?.append(input);

    input.onChange.listen((event) {
      final selectedFiles = <XFile>[];
      if (input.files != null) {
        for (final file in input.files!) {
          final relativePath = file.relativePath ?? file.name;
          selectedFiles.add(XFile(
            relativePath,
            mimeType: file.type,
            lastModified: file.lastModified != null
                ? DateTime.fromMillisecondsSinceEpoch(file.lastModified!)
                : null,
          ));
        }
      }
      input.remove();
      completer.complete(selectedFiles);
    });

    input.click();
    return completer.future;
  }
}
