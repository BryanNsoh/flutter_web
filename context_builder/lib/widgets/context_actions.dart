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

    // Move context-dependent calls before awaits
    final messenger = ScaffoldMessenger.of(context);

    final buffer = StringBuffer();
    buffer.writeln('<context>');
    buffer.writeln('    <timestamp></timestamp>');

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
          customInstructions = "<!-- Failed to fetch custom instructions:  -->";
        }
      } catch (e) {
        customInstructions = "<!-- Failed to fetch custom instructions:  -->";
      }
    }
    if (store.useCustomInstructions) {
      buffer.writeln('    <custom_instructions>');
      buffer.writeln(customInstructions.isNotEmpty
          ? customInstructions
          : "<!-- No custom instructions -->");
      buffer.writeln('    </custom_instructions>');
    }

    buffer.writeln('    <repository_structure>');
    for (final entry in store.entries) {
      if (entry.isFile && entry.file != null) {
        final contentData = await _readFileContent(entry.file!);
        buffer.writeln('        <file>');
        buffer.writeln('            <path>${entry.path}</path>');
        buffer
            .writeln('            <content><![CDATA[$contentData]]></content>');
        buffer.writeln('        </file>');
      }
    }
    buffer.writeln('    </repository_structure>');
    buffer.writeln('</context>');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    messenger.showSnackBar(
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
      return "<!-- Error reading file:  -->";
    }
  }

  String _obfuscateEnv(String content) {
    return content.split('\n').map((line) {
      if (line.contains('=')) {
        // Remove unnecessary escape
        return '=********';
      }
      return line;
    }).join('\n');
  }
}
