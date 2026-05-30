import 'package:flutter/material.dart';

class SqlEditor extends StatefulWidget {
  const SqlEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.hint = '-- write SQL here',
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<SqlEditor> createState() => _SqlEditorState();
}

class _SqlEditorState extends State<SqlEditor> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initial);
    _ctl.addListener(() => widget.onChanged(_ctl.text));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctl,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        hintText: widget.hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}
