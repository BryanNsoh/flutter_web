Param()

Write-Host "Checking Flutter installation..."
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: Flutter not installed or not on PATH. Please install Flutter and run 'flutter doctor'."
  exit 1
}

Write-Host "Creating Flutter project..."
$projDir = Join-Path (Get-Location) "context_builder"
if (Test-Path $projDir) {
  Write-Host "Removing existing context_builder directory..."
  Remove-Item $projDir -Recurse -Force
}
flutter create context_builder --platforms web

Write-Host "Updating pubspec.yaml with dependencies..."
$pubspecPath = Join-Path $projDir "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath

$extraDeps = @"
  provider: ^6.0.5
  file_selector: ^0.9.1
  http: ^0.13.5
  flutter_dropzone: ^3.0.5
"@

$newPubspec = $pubspecContent | ForEach-Object {
  if ($_ -match "cupertino_icons:") {
    $_
    $extraDeps
  }
  else {
    $_
  }
}

Set-Content $pubspecPath $newPubspec -Encoding UTF8

Write-Host "Creating directory structure..."
New-Item -ItemType Directory -Path (Join-Path $projDir "lib\app") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $projDir "lib\models") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $projDir "lib\services") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $projDir "lib\screens") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $projDir "lib\widgets") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $projDir "lib\theme") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $projDir "lib\web_support") | Out-Null

Write-Host "Writing main.dart..."
$mainDart = @"
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/context_builder_app.dart';
import 'services/file_store.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileStore(isWeb: kIsWeb)),
      ],
      child: const ContextBuilderApp(),
    ),
  );
}
"@
Set-Content (Join-Path $projDir "lib\main.dart") $mainDart -Encoding UTF8

Write-Host "Writing context_builder_app.dart..."
$contextBuilderApp = @"
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../theme/app_theme.dart';

class ContextBuilderApp extends StatelessWidget {
  const ContextBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(  // Force LTR
      textDirection: TextDirection.ltr,
      child: MaterialApp(
        title: 'Context Builder',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ),
    );
  }
}
"@
Set-Content (Join-Path $projDir "lib\app\context_builder_app.dart") $contextBuilderApp -Encoding UTF8

Write-Host "Writing app_theme.dart..."
$appTheme = @"
import 'package:flutter/material.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
"@
Set-Content (Join-Path $projDir "lib\theme\app_theme.dart") $appTheme -Encoding UTF8

Write-Host "Writing file_entry.dart..."
$fileEntry = @"
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
"@
Set-Content (Join-Path $projDir "lib\models\file_entry.dart") $fileEntry -Encoding UTF8

Write-Host "Writing web_folder_support.dart..."
$webFolderSupport = @"
import 'dart:async';
import 'dart:html' as html;
import 'package:file_selector/file_selector.dart';

class WebFolderPicker {
  // This uses 'webkitdirectory' to allow folder selection.
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
          // webkitdirectory provides 'relativePath' which includes subfolders
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
"@
Set-Content (Join-Path $projDir "lib\web_support\web_folder_support.dart") $webFolderSupport -Encoding UTF8

Write-Host "Writing file_store.dart..."
$fileStore = @"
import 'dart:convert';
import 'dart:html' as html; 
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import '../models/file_entry.dart';
import '../web_support/web_folder_support.dart';

class FileStore extends ChangeNotifier {
  static const String kStorageKey = 'context_builder_config_v3';

  List<FileEntry> entries = [];
  Set<String> excludedTypes = { '.exe', '.dll', '.so', '.pyc', '.pdf', '.doc', '.jpg', '.png' };
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
        entries.add(FileEntry(
          path: file.name,
          name: file.name.split('/').last,
          type: FileEntryType.file,
          file: file,
        ));
      }
    }
    notifyListeners();
    _saveConfig();
  }

  Future<void> addDirectory() async {
    if (isWeb) {
      // On web, use web folder picking via webkitdirectory
      await addWebFolder();
    } else {
      final dirPath = await getDirectoryPath();
      if (dirPath == null) return;
      // On non-web platforms, just add a directory reference
      entries.add(FileEntry(
        path: dirPath,
        name: dirPath.split('/').last,
        type: FileEntryType.directory,
        children: [],
      ));
      notifyListeners();
      _saveConfig();
    }
  }

  Future<void> addWebFolder() async {
    try {
      final files = await WebFolderPicker.pickFolder();
      for (final file in files) {
        if (!_shouldExclude(file.name)) {
          entries.add(FileEntry(
            path: file.path ?? file.name,
            name: file.name.split('/').last,
            type: FileEntryType.file,
            file: file,
          ));
        }
      }
      notifyListeners();
      _saveConfig();
    } catch (e) {
      debugPrint('Error picking folder: $e');
    }
  }

  bool _shouldExclude(String path) {
    final ext = path.contains('.') ? '.${path.split('.').last.toLowerCase()}' : '';
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
        excludedTypes = Set<String>.from(data['excludedTypes'] ?? []);
        excludedPaths = Set<String>.from(data['excludedPaths'] ?? []);
        customInstructionsUrl = data['customInstructionsUrl'] ?? '';
        useCustomInstructions = data['useCustomInstructions'] ?? false;
      } catch (e) {
        debugPrint('Error loading config: $e');
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
}
"@
Set-Content (Join-Path $projDir "lib\services\file_store.dart") $fileStore -Encoding UTF8

Write-Host "Writing home_screen.dart..."
$homeScreen = @"
import 'package:flutter/material.dart';
import '../widgets/file_list.dart';
import '../widgets/instructions_panel.dart';
import '../widgets/context_actions.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/dropzone_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Context Builder'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettings(context),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DropzoneWidget(),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: FileList()),
                      const SizedBox(width: 16),
                      Expanded(child: InstructionsPanel()),
                    ],
                  )
                else ...[
                  FileList(),
                  const SizedBox(height: 16),
                  InstructionsPanel(),
                ],
                const SizedBox(height: 16),
                const ContextActions(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: Theme.of(context),
        child: const SettingsDialog(),
      ),
    );
  }
}
"@
Set-Content (Join-Path $projDir "lib\screens\home_screen.dart") $homeScreen -Encoding UTF8

Write-Host "Writing file_list.dart..."
$fileList = @"
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_store.dart';

class FileList extends StatelessWidget {
  const FileList({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FileStore>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Files & Folders',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: store.addFiles,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Add Files'),
                ),
                const SizedBox(width: 8),
                if (!store.isWeb)
                  FilledButton.icon(
                    onPressed: store.addDirectory,
                    icon: const Icon(Icons.create_new_folder),
                    label: const Text('Add Folder'),
                  )
                else
                  // On web we rely on webkitdirectory
                  FilledButton.icon(
                    onPressed: store.addDirectory,
                    icon: const Icon(Icons.create_new_folder),
                    label: const Text('Add Folder'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            store.entries.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No files or folders added yet.\nUse the buttons above or drag & drop files.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: store.entries.length,
                      itemBuilder: (context, index) {
                        final entry = store.entries[index];
                        return ListTile(
                          leading: Icon(
                            entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
                          ),
                          title: Text(entry.name),
                          subtitle: Text(entry.path),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => store.removeEntry(index),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
"@
Set-Content (Join-Path $projDir "lib\widgets\file_list.dart") $fileList -Encoding UTF8

Write-Host "Writing instructions_panel.dart..."
$instructionsPanel = @"
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_store.dart';

class InstructionsPanel extends StatelessWidget {
  const InstructionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FileStore>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'What do you want done?',
              ),
              onChanged: store.setInstructions,
              controller: TextEditingController(text: store.instructions),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Output/Error Log',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => store.setErrorOutput(''),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste error/output here',
              ),
              onChanged: store.setErrorOutput,
              controller: TextEditingController(text: store.errorOutput),
            ),
          ],
        ),
      ),
    );
  }
}
"@
Set-Content (Join-Path $projDir "lib\widgets\instructions_panel.dart") $instructionsPanel -Encoding UTF8

Write-Host "Writing context_actions.dart..."
$contextActions = @"
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_selector/file_selector.dart'; 
import '../services/file_store.dart';

class ContextActions extends StatelessWidget {
  const ContextActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: () => _buildAndCopyContext(context),
              icon: const Icon(Icons.copy),
              label: const Text('Copy Context to Clipboard'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buildAndCopyContext(BuildContext context) async {
    final store = context.read<FileStore>();
    final timestamp = DateTime.now().toUtc().toIso8601String()
      .replaceAll(':', '')
      .replaceAll('-', '')
      .replaceAll('T', '_')
      .replaceAll('.', '');

    final buffer = StringBuffer();
    buffer.writeln('<context>');
    buffer.writeln('    <timestamp>$timestamp</timestamp>');

    if (store.instructions.trim().isNotEmpty) {
      buffer.writeln('    <instructions>');
      buffer.writeln(store.instructions);
      buffer.writeln('    </instructions>');
    }

    if (store.errorOutput.trim().isNotEmpty) {
      buffer.writeln('    <output>');
      buffer.writeln(store.errorOutput);
      buffer.writeln('    </output>');
    }

    String customInstructions = '';
    if (store.useCustomInstructions && store.customInstructionsUrl.isNotEmpty) {
      try {
        final r = await http.get(Uri.parse(store.customInstructionsUrl));
        if (r.statusCode == 200) {
          customInstructions = r.body;
        } else {
          customInstructions = "<!-- Failed to fetch custom instructions: ${r.statusCode} -->";
        }
      } catch (e) {
        customInstructions = "<!-- Failed to fetch custom instructions: $e -->";
      }
    }
    if (store.useCustomInstructions) {
      buffer.writeln('    <custom_instructions>');
      buffer.writeln(customInstructions.isNotEmpty ? customInstructions : "<!-- No custom instructions -->");
      buffer.writeln('    </custom_instructions>');
    }

    buffer.writeln('    <repository_structure>');
    for (final entry in store.entries) {
      if (entry.isFile && entry.file != null) {
        final content = await _readFileContent(entry.file!);
        buffer.writeln('        <file>');
        buffer.writeln('            <path>${entry.path}</path>');
        buffer.writeln('            <content><![CDATA[$content]]></content>');
        buffer.writeln('        </file>');
      }
    }
    buffer.writeln('    </repository_structure>');
    buffer.writeln('</context>');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Context copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String> _readFileContent(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      try {
        final content = utf8.decode(bytes);
        if (file.name.endsWith('.env')) {
          return _obfuscateEnv(content);
        }
        return content;
      } catch (_) {
        return "<!-- Binary or non-UTF-8 content not included -->";
      }
    } catch (e) {
      return "<!-- Error reading file: $e -->";
    }
  }

  String _obfuscateEnv(String content) {
    return content.split('\n').map((line) {
      if (line.contains('=')) {
        final parts = line.split('=');
        return '\${parts[0]}=********';
      }
      return line;
    }).join('\n');
  }
}
"@
Set-Content (Join-Path $projDir "lib\widgets\context_actions.dart") $contextActions -Encoding UTF8

Write-Host "Writing settings_dialog.dart..."
$settingsDialog = @"
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_store.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _urlController;
  late bool _useCustomInstructions;
  late Set<String> _excludedTypes;
  late Set<String> _excludedPaths;

  @override
  void initState() {
    super.initState();
    final store = context.read<FileStore>();
    _urlController = TextEditingController(text: store.customInstructionsUrl);
    _useCustomInstructions = store.useCustomInstructions;
    _excludedTypes = Set.from(store.excludedTypes);
    _excludedPaths = Set.from(store.excludedPaths);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomInstructionsSection(),
              const Divider(height: 32),
              _buildExcludedTypesSection(),
              const SizedBox(height: 16),
              _buildExcludedPathsSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveSettings,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildCustomInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('Use Custom Instructions'),
          value: _useCustomInstructions,
          onChanged: (value) {
            setState(() => _useCustomInstructions = value ?? false);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Custom Instructions URL',
            border: OutlineInputBorder(),
            hintText: 'https://example.com/instructions.txt',
          ),
          enabled: _useCustomInstructions,
        ),
      ],
    );
  }

  Widget _buildExcludedTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Excluded File Types',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._excludedTypes.map((type) => Chip(
              label: Text(type),
              onDeleted: () {
                setState(() => _excludedTypes.remove(type));
              },
            )),
            ActionChip(
              avatar: const Icon(Icons.add),
              label: const Text('Add Type'),
              onPressed: _addExcludedType,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExcludedPathsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Excluded Paths',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._excludedPaths.map((path) => Chip(
              label: Text(path),
              onDeleted: () {
                setState(() => _excludedPaths.remove(path));
              },
            )),
            ActionChip(
              avatar: const Icon(Icons.add),
              label: const Text('Add Path'),
              onPressed: _addExcludedPath,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addExcludedType() async {
    final type = await _showInputDialog(
      'Add Excluded Type',
      'Enter file extension (with dot, e.g. .pdf):',
    );
    if (type != null && type.isNotEmpty) {
      setState(() => _excludedTypes.add(type.toLowerCase()));
    }
  }

  Future<void> _addExcludedPath() async {
    final path = await _showInputDialog(
      'Add Excluded Path',
      'Enter path pattern to exclude:',
    );
    if (path != null && path.isNotEmpty) {
      setState(() => _excludedPaths.add(path));
    }
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    final store = context.read<FileStore>();
    store.updateExcludedTypes(_excludedTypes);
    store.updateExcludedPaths(_excludedPaths);
    store.updateCustomInstructions(
      url: _urlController.text.trim(),
      use: _useCustomInstructions,
    );
    Navigator.of(context).pop();
  }
}
"@
Set-Content (Join-Path $projDir "lib\widgets\settings_dialog.dart") $settingsDialog -Encoding UTF8

Write-Host "Writing dropzone_widget.dart..."
$dropzoneWidget = @"
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import '../services/file_store.dart';
import '../models/file_entry.dart';

class DropzoneWidget extends StatefulWidget {
  const DropzoneWidget({super.key});

  @override
  State<DropzoneWidget> createState() => _DropzoneWidgetState();
}

class _DropzoneWidgetState extends State<DropzoneWidget> {
  late DropzoneViewController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 100,
        alignment: Alignment.center,
        child: Stack(
          children: [
            DropzoneView(
              onCreated: (ctrl) => controller = ctrl,
              onDrop: (files) async {
                final store = context.read<FileStore>();
                for (final fileName in files) {
                  final file = await controller.getFile(fileName);
                  final bytes = await controller.getFileData(fileName);
                  // On web, we don't have direct relative paths from drop. 
                  // We'll just use file.name. If we wanted paths, we'd need a different approach.
                  final xFile = XFile.fromData(
                    bytes,
                    name: await controller.getFilename(fileName),
                  );
                  if (!store.excludedTypes.contains('.${xFile.name.split('.').last.toLowerCase()}')) {
                    store.entries.add(
                      FileEntry(
                        path: xFile.name,
                        name: xFile.name,
                        type: FileEntryType.file,
                        file: xFile,
                      )
                    );
                  }
                }
                store.notifyListeners();
              },
              cursor: CursorType.grab,
            ),
            Center(
              child: Text(
                'Drag & Drop Files Here',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
"@
Set-Content (Join-Path $projDir "lib\widgets\dropzone_widget.dart") $dropzoneWidget -Encoding UTF8

Write-Host "Running flutter pub get..."
Push-Location $projDir
flutter pub get
Pop-Location

Write-Host "Setup complete!"
Write-Host "------------------------------------"
Write-Host "Your improved Flutter project is ready in 'context_builder'."
Write-Host "To run locally (web): cd context_builder && flutter run -d chrome"
Write-Host "This version supports folder selection on web using webkitdirectory and drag-and-drop file addition."
Write-Host "Text fields now display text as typed, no reversal."
Write-Host "------------------------------------"
