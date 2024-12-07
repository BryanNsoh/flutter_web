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
