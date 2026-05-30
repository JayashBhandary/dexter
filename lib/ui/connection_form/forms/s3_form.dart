import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/tokens.dart';

class S3FormResult {
  const S3FormResult({
    required this.name,
    required this.endpoint,
    this.port,
    required this.region,
    required this.useSSL,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
  });

  final String name;
  final String endpoint;
  final int? port;
  final String region;
  final bool useSSL;
  final String accessKeyId;
  final String secretAccessKey;
  final String? sessionToken;
}

class S3Form extends StatefulWidget {
  const S3Form({super.key, required this.onSubmit, this.initial});

  final ValueChanged<S3FormResult> onSubmit;
  final S3FormResult? initial;

  @override
  State<S3Form> createState() => _S3FormState();
}

class _S3FormState extends State<S3Form> {
  late final TextEditingController _name;
  late final TextEditingController _endpoint;
  late final TextEditingController _port;
  late final TextEditingController _region;
  late final TextEditingController _access;
  late final TextEditingController _secret;
  late final TextEditingController _session;
  late bool _useSSL;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? 'My S3');
    _endpoint = TextEditingController(text: i?.endpoint ?? 's3.amazonaws.com');
    _port = TextEditingController(text: i?.port == null ? '' : '${i!.port}');
    _region = TextEditingController(text: i?.region ?? 'us-east-1');
    _access = TextEditingController(text: i?.accessKeyId ?? '');
    _secret = TextEditingController(text: i?.secretAccessKey ?? '');
    _session = TextEditingController(text: i?.sessionToken ?? '');
    // Default OFF for new connections: most local MinIO setups serve plain
    // HTTP, and `useSSL: true` against HTTP is the "wrong version number" trap.
    _useSSL = i?.useSSL ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _endpoint.dispose();
    _port.dispose();
    _region.dispose();
    _access.dispose();
    _secret.dispose();
    _session.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name required');
      return;
    }
    if (_endpoint.text.trim().isEmpty) {
      setState(() => _error = 'Endpoint required');
      return;
    }
    if (_access.text.trim().isEmpty || _secret.text.isEmpty) {
      setState(() => _error = 'Access key + secret required');
      return;
    }
    final port = _port.text.trim().isEmpty
        ? null
        : int.tryParse(_port.text.trim());
    widget.onSubmit(S3FormResult(
      name: _name.text.trim(),
      endpoint: _endpoint.text.trim(),
      port: port,
      region: _region.text.trim(),
      useSSL: _useSSL,
      accessKeyId: _access.text.trim(),
      secretAccessKey: _secret.text,
      sessionToken: _session.text.trim().isEmpty ? null : _session.text.trim(),
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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _endpoint,
                  decoration: const InputDecoration(
                    labelText: 'Endpoint (host)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Port (opt)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _region,
            decoration: const InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _access,
            decoration: const InputDecoration(
              labelText: 'Access key ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _secret,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Secret access key',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _session,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Session token (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.md),
          SwitchListTile(
            title: const Text('Use SSL'),
            value: _useSSL,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _useSSL = v),
          ),
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
