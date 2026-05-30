import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

class SqliteFormResult {
  const SqliteFormResult({required this.name, required this.filePath});
  final String name;
  final String filePath;
}

class SqliteForm extends StatefulWidget {
  const SqliteForm({super.key, required this.onSubmit, this.initial});
  final ValueChanged<SqliteFormResult> onSubmit;
  final SqliteFormResult? initial;

  @override
  State<SqliteForm> createState() => _SqliteFormState();
}

class _SqliteFormState extends State<SqliteForm> {
  late final TextEditingController _name;
  late final TextEditingController _path;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? 'My SQLite DB');
    _path = TextEditingController(text: i?.filePath ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _path.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pick a SQLite database',
      type: FileType.any,
    );
    if (r != null && r.files.single.path != null) {
      setState(() => _path.text = r.files.single.path!);
    }
  }

  void _submit() {
    final name = _name.text.trim();
    final path = _path.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name required');
      return;
    }
    if (path.isEmpty) {
      setState(() => _error = 'Pick a database file');
      return;
    }
    widget.onSubmit(SqliteFormResult(name: name, filePath: path));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Connection name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _path,
                  decoration: const InputDecoration(
                    labelText: 'Database file path',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              IconButton.filledTonal(
                tooltip: 'Browse',
                icon: const Icon(Icons.folder_open),
                onPressed: _pickFile,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: Spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: Spacing.sm),
              FilledButton(onPressed: _submit, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
