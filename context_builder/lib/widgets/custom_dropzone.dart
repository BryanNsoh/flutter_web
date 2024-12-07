// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import '../services/file_store.dart';
import '../models/file_entry.dart';

class CustomDropZone extends StatefulWidget {
  const CustomDropZone({super.key});

  @override
  State<CustomDropZone> createState() => _CustomDropZoneState();
}

class _CustomDropZoneState extends State<CustomDropZone> {
  bool _isDragging = false;
  final _dropZoneKey = GlobalKey();
  html.DivElement? _dropZone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupDropZone();
    });
  }

  void _setupDropZone() {
    final renderBox =
        _dropZoneKey.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);

    _dropZone = html.DivElement()
      ..style.width = '${renderBox.size.width}px'
      ..style.height = '${renderBox.size.height}px'
      ..style.position = 'absolute'
      ..style.top = '${position.dy}px'
      ..style.left = '${position.dx}px'
      ..style.zIndex = '1';

    _dropZone!.onDragOver.listen((event) {
      event.preventDefault();
      event.dataTransfer.dropEffect = 'copy';
      if (!_isDragging) setState(() => _isDragging = true);
    });

    _dropZone!.onDragLeave.listen((event) {
      event.preventDefault();
      if (_isDragging) setState(() => _isDragging = false);
    });

    _dropZone!.onDrop.listen((event) {
      event.preventDefault();
      setState(() => _isDragging = false);

      final items = event.dataTransfer.items;
      if (items != null) {
        _handleDroppedItems(items);
      }
    });

    html.document.body?.append(_dropZone!);
  }

  void _handleDroppedItems(html.DataTransferItemList items) async {
    final store = context.read<FileStore>();

    // Convert DataTransferItemList to a List<html.DataTransferItem>
    final length = items.length;
    if (length == null) return;
    final itemsList = List.generate(length, (i) => items[i]);

    for (var item in itemsList) {
      if (item.kind == 'file') {
        final file = item.getAsFile();
        if (file != null &&
            !store.excludedTypes
                .contains('.${file.name.split('.').last.toLowerCase()}')) {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          await reader.onLoad.first;

          if (reader.result != null) {
            final bytes = reader.result as List<int>;
            final xFile = XFile.fromData(
              Uint8List.fromList(bytes),
              name: file.name,
              mimeType: file.type,
              lastModified: file.lastModified != null
                  ? DateTime.fromMillisecondsSinceEpoch(file.lastModified!)
                  : null,
            );

            // Use store.addEntry() so notifyListeners is called inside store
            store.addEntry(
              FileEntry(
                path: file.name,
                name: file.name,
                type: FileEntryType.file,
                file: xFile,
              ),
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _dropZone?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: _dropZoneKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDragging
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: _isDragging ? 2 : 1,
          ),
          color: _isDragging
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isDragging ? Icons.file_download : Icons.cloud_upload,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                _isDragging ? 'Drop Files Here' : 'Drag & Drop Files Here',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
