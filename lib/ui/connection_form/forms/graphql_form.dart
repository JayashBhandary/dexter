import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

class GraphqlFormResult {
  const GraphqlFormResult({
    required this.name,
    required this.endpoint,
    required this.authMode,
    this.apiKeyHeader,
    this.bearerToken,
    this.apiKey,
    this.basicAuth,
    required this.operationsJson,
  });

  final String name;
  final String endpoint;
  final String authMode;
  final String? apiKeyHeader;
  final String? bearerToken;
  final String? apiKey;
  final String? basicAuth;
  final String operationsJson;
}

class GraphqlForm extends StatefulWidget {
  const GraphqlForm({super.key, required this.onSubmit, this.initial});

  final ValueChanged<GraphqlFormResult> onSubmit;
  final GraphqlFormResult? initial;

  @override
  State<GraphqlForm> createState() => _GraphqlFormState();
}

class _GraphqlFormState extends State<GraphqlForm> {
  late final TextEditingController _name;
  late final TextEditingController _endpoint;
  late final TextEditingController _apiKeyHeader;
  late final TextEditingController _secret;
  late final TextEditingController _ops;
  late String _authMode;
  String? _error;

  static const _exampleOps = '''[
  {"name": "Countries",
   "query": "query { countries { code name emoji } }",
   "rowsPath": "countries"}
]''';

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? 'My GraphQL API');
    _endpoint = TextEditingController(
        text: i?.endpoint ?? 'https://countries.trevorblades.com/');
    _apiKeyHeader =
        TextEditingController(text: i?.apiKeyHeader ?? 'X-API-Key');
    _secret = TextEditingController(
        text: i?.bearerToken ?? i?.apiKey ?? i?.basicAuth ?? '');
    _ops = TextEditingController(text: i?.operationsJson ?? _exampleOps);
    _authMode = i?.authMode ?? 'none';
  }

  @override
  void dispose() {
    _name.dispose();
    _endpoint.dispose();
    _apiKeyHeader.dispose();
    _secret.dispose();
    _ops.dispose();
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
    String? bearer, apiKey, basic;
    switch (_authMode) {
      case 'bearer':
        bearer = _secret.text;
      case 'apiKey':
        apiKey = _secret.text;
      case 'basic':
        basic = _secret.text;
    }
    widget.onSubmit(GraphqlFormResult(
      name: _name.text.trim(),
      endpoint: _endpoint.text.trim(),
      authMode: _authMode,
      apiKeyHeader: _authMode == 'apiKey' ? _apiKeyHeader.text.trim() : null,
      bearerToken: bearer,
      apiKey: apiKey,
      basicAuth: basic,
      operationsJson: _ops.text,
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
            controller: _endpoint,
            decoration: const InputDecoration(
              labelText: 'GraphQL endpoint',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.md),
          DropdownButtonFormField<String>(
            initialValue: _authMode,
            decoration: const InputDecoration(
              labelText: 'Auth',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('none')),
              DropdownMenuItem(value: 'bearer', child: Text('Bearer token')),
              DropdownMenuItem(value: 'apiKey', child: Text('API key header')),
              DropdownMenuItem(value: 'basic', child: Text('Basic (base64)')),
            ],
            onChanged: (v) => setState(() => _authMode = v ?? 'none'),
          ),
          if (_authMode == 'apiKey') ...[
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _apiKeyHeader,
              decoration: const InputDecoration(
                labelText: 'API key header name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          if (_authMode != 'none') ...[
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _secret,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _authMode == 'basic'
                    ? 'base64(user:pass)'
                    : _authMode == 'bearer'
                        ? 'Bearer token'
                        : 'API key value',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          Text('Saved operations (JSON array)',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: _ops,
            maxLines: 10,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              alignLabelWithHint: true,
            ),
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
