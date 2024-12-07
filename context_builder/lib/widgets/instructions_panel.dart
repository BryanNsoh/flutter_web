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
