import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import '../models/file_entry.dart';
import '../web_support/web_folder_support.dart';

class FileStore extends ChangeNotifier {
  static const String kStorageKey = 'context_builder_config_v3';

  List<FileEntry> entries = [];
  Set<String> excludedTypes = {
    '.exe',
    '.dll',
    '.so',
    '.pyc',
    '.pdf',
    '.doc',
    '.jpg',
    '.png'
  };
  Set<String> excludedPaths = {};
  String customInstructionsUrl = '';
  bool useCustomInstructions = false;
  String instructions = '';
  String errorOutput = '';

  final bool isWeb;

  FileStore({required this.isWeb}) {
    _loadConfig();
  }

  Future<void> addFiles() async {
    final files = await openFiles(
      acceptedTypeGroups: [XTypeGroup(label: 'Any')],
    );
    for (final file in files) {
      if (!_shouldExclude(file.name)) {
        addEntry(FileEntry(
          path: file.name,
          name: file.name.split('/').last,
          type: FileEntryType.file,
          file: file,
        ));
      }
    }
  }

  Future<void> addDirectory() async {
    if (isWeb) {
      // On web, use web folder picking
      await addWebFolder();
    } else {
      final dirPath = await getDirectoryPath();
      if (dirPath == null) return;
      addEntry(FileEntry(
        path: dirPath,
        name: dirPath.split('/').last,
        type: FileEntryType.directory,
        children: [],
      ));
    }
  }

  Future<void> addWebFolder() async {
    try {
      final files = await WebFolderPicker.pickFolder();
      for (final file in files) {
        if (!_shouldExclude(file.name)) {
          addEntry(FileEntry(
            path: file.path ?? file.name,
            name: file.name.split('/').last,
            type: FileEntryType.file,
            file: file,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error picking folder: ');
    }
  }

  bool _shouldExclude(String path) {
    final ext =
        path.contains('.') ? '.' + path.split('.').last.toLowerCase() : '';
    if (excludedTypes.contains(ext)) return true;
    return excludedPaths.any((excluded) => path.contains(excluded));
  }

  void setInstructions(String value) {
    instructions = value;
    notifyListeners();
  }

  void setErrorOutput(String value) {
    errorOutput = value;
    notifyListeners();
  }

  void removeEntry(int index) {
    entries.removeAt(index);
    notifyListeners();
    _saveConfig();
  }

  void updateExcludedTypes(Set<String> types) {
    excludedTypes = types;
    notifyListeners();
    _saveConfig();
  }

  void updateExcludedPaths(Set<String> paths) {
    excludedPaths = paths;
    notifyListeners();
    _saveConfig();
  }

  void updateCustomInstructions({
    required String url,
    required bool use,
  }) {
    customInstructionsUrl = url;
    useCustomInstructions = use;
    notifyListeners();
    _saveConfig();
  }

  void _loadConfig() {
    if (!isWeb) return;
    final stored = html.window.localStorage[kStorageKey];
    if (stored != null) {
      try {
        final data = jsonDecode(stored);
        // Since _saveConfig always sets these keys, we assume they are never null:
        excludedTypes = Set<String>.from(data['excludedTypes']);
        excludedPaths = Set<String>.from(data['excludedPaths']);
        customInstructionsUrl = data['customInstructionsUrl'];
        useCustomInstructions = data['useCustomInstructions'];
      } catch (e) {
        debugPrint('Error loading config: ');
      }
    }
  }

  void _saveConfig() {
    if (!isWeb) return;
    final data = {
      'excludedTypes': excludedTypes.toList(),
      'excludedPaths': excludedPaths.toList(),
      'customInstructionsUrl': customInstructionsUrl,
      'useCustomInstructions': useCustomInstructions,
    };
    html.window.localStorage[kStorageKey] = jsonEncode(data);
  }

  // New method to add an entry and notify
  void addEntry(FileEntry entry) {
    entries.add(entry);
    notifyListeners();
    _saveConfig();
  }
}
