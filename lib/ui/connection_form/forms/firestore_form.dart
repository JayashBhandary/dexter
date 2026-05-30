import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

class FirestoreFormResult {
  const FirestoreFormResult({
    required this.name,
    required this.projectId,
    required this.databaseId,
    required this.mode,
    this.emulatorHost,
    this.serviceAccountJson,
  });

  final String name;
  final String projectId;
  final String databaseId;
  final String mode; // serviceAccount | emulator
  final String? emulatorHost;
  final String? serviceAccountJson;
}

class FirestoreForm extends StatefulWidget {
  const FirestoreForm({super.key, required this.onSubmit, this.initial});

  final ValueChanged<FirestoreFormResult> onSubmit;
  final FirestoreFormResult? initial;

  @override
  State<FirestoreForm> createState() => _FirestoreFormState();
}

class _FirestoreFormState extends State<FirestoreForm> {
  late final TextEditingController _name;
  late final TextEditingController _projectId;
  late final TextEditingController _databaseId;
  late final TextEditingController _emulatorHost;
  late final TextEditingController _saJson;
  late String _mode;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? 'My Firestore');
    _projectId = TextEditingController(text: i?.projectId ?? '');
    _databaseId = TextEditingController(text: i?.databaseId ?? '(default)');
    _emulatorHost =
        TextEditingController(text: i?.emulatorHost ?? 'localhost:8080');
    _saJson = TextEditingController(text: i?.serviceAccountJson ?? '');
    _mode = i?.mode ?? 'serviceAccount';
  }

  @override
  void dispose() {
    _name.dispose();
    _projectId.dispose();
    _databaseId.dispose();
    _emulatorHost.dispose();
    _saJson.dispose();
    super.dispose();
  }

  Future<void> _pickJson() async {
    final r = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pick service-account JSON',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = r?.files.single.bytes;
    if (bytes != null) {
      _saJson.text = String.fromCharCodes(bytes);
      setState(() {});
    }
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name required');
      return;
    }
    if (_projectId.text.trim().isEmpty) {
      setState(() => _error = 'Project ID required');
      return;
    }
    if (_mode == 'serviceAccount' && _saJson.text.trim().isEmpty) {
      setState(() => _error = 'Service account JSON required');
      return;
    }
    widget.onSubmit(FirestoreFormResult(
      name: _name.text.trim(),
      projectId: _projectId.text.trim(),
      databaseId: _databaseId.text.trim().isEmpty
          ? '(default)'
          : _databaseId.text.trim(),
      mode: _mode,
      emulatorHost: _mode == 'emulator' ? _emulatorHost.text.trim() : null,
      serviceAccountJson:
          _mode == 'serviceAccount' ? _saJson.text : null,
    ));
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
          TextField(
            controller: _projectId,
            decoration: const InputDecoration(
              labelText: 'Project ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _databaseId,
            decoration: const InputDecoration(
              labelText: 'Database ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'serviceAccount', label: Text('Service account')),
              ButtonSegment(value: 'emulator', label: Text('Emulator')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: Spacing.md),
          if (_mode == 'emulator')
            TextField(
              controller: _emulatorHost,
              decoration: const InputDecoration(
                labelText: 'Emulator host (e.g. localhost:8080)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _saJson.text.isEmpty
                        ? 'No service-account JSON loaded.'
                        : 'JSON loaded (${_saJson.text.length} bytes)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickJson,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Load JSON'),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: _saJson,
              maxLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Service account JSON',
                border: OutlineInputBorder(),
                isDense: true,
                alignLabelWithHint: true,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
