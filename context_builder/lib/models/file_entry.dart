import 'package:file_selector/file_selector.dart';

enum FileEntryType { file, directory }

class FileEntry {
  final String path;
  final String name;
  final FileEntryType type;
  final List<FileEntry> children;
  final XFile? file;
  bool isExpanded;

  FileEntry({
    required this.path,
    required this.name,
    required this.type,
    this.children = const [],
    this.file,
    this.isExpanded = false,
  });

  bool get isDirectory => type == FileEntryType.directory;
  bool get isFile => type == FileEntryType.file;
}
