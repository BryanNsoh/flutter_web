import 'package:flutter/material.dart';
import '../widgets/file_list.dart';
import '../widgets/instructions_panel.dart';
import '../widgets/context_actions.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/custom_dropzone.dart';

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
                const CustomDropZone(),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(child: FileList()),
                      SizedBox(width: 16),
                      Expanded(child: InstructionsPanel()),
                    ],
                  )
                else ...[
                  const FileList(),
                  const SizedBox(height: 16),
                  const InstructionsPanel(),
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
