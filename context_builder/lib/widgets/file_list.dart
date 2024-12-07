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
