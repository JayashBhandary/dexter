import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../connectors/data_source.dart';
import '../../state/active_source_provider.dart';
import '../../state/settings_provider.dart';
import '../../theme/tokens.dart';
import '../widgets/error_banner.dart';

enum _SortKey { name, size, modified }

/// Hierarchical file browser for any [FileBrowsable] source (S3/MinIO today;
/// Drive/Dropbox later). Talks only to the [FileBrowsable] contract and gates
/// actions on [FileBrowsable.fileOps].
class FileBrowserPane extends ConsumerStatefulWidget {
  const FileBrowserPane({super.key, required this.container});
  final ContainerRef container;

  @override
  ConsumerState<FileBrowserPane> createState() => _FileBrowserPaneState();
}

class _FileBrowserPaneState extends ConsumerState<FileBrowserPane> {
  String _path = ''; // current folder prefix, '' = bucket root
  List<FileEntry> _entries = const [];
  final Set<String> _selected = {};
  Set<FileOp> _ops = const {};
  bool _loading = false;
  Object? _error;
  String _query = '';
  _SortKey _sort = _SortKey.name;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<FileBrowsable?> _src() async {
    final src = await ref.read(activeDataSourceProvider.future);
    return src is FileBrowsable ? src : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected.clear();
    });
    try {
      final src = await _src();
      if (src == null) throw StateError('Source is not file-browsable');
      _ops = src.fileOps;
      final listing = await src.listEntries(widget.container, _path);
      _entries = listing.entries;
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateTo(String path) {
    setState(() => _path = path);
    _load();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- Filtering / sorting --------------------------------------------------

  List<FileEntry> get _visible {
    var list = _entries;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((e) => e.name.toLowerCase().contains(q)).toList();
    }
    final folders = list.where((e) => e.isFolder).toList();
    final files = list.where((e) => !e.isFolder).toList();
    int cmp(FileEntry a, FileEntry b) => switch (_sort) {
          _SortKey.name =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          _SortKey.size => (a.size ?? 0).compareTo(b.size ?? 0),
          _SortKey.modified => (a.modified ?? DateTime(0))
              .compareTo(b.modified ?? DateTime(0)),
        };
    folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    files.sort(cmp);
    return [...folders, ...files];
  }

  // --- Mutations ------------------------------------------------------------

  Future<void> _newFolder() async {
    final name = await _promptText('New folder', 'Folder name');
    if (name == null || name.trim().isEmpty) return;
    try {
      final src = await _src();
      await src!.createFolder(widget.container, '$_path${name.trim()}');
      _toast('Created ${name.trim()}/');
      await _load();
    } catch (e) {
      _toast('Create folder failed: $e');
    }
  }

  Future<void> _upload() async {
    final pick = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pick file to upload',
      allowMultiple: true,
      withData: false,
    );
    if (pick == null || pick.files.isEmpty) return;
    try {
      final src = await _src();
      for (final f in pick.files) {
        final path = f.path;
        if (path == null) continue;
        await src!.uploadFile(widget.container, '$_path${p.basename(path)}', path);
      }
      _toast('Uploaded ${pick.files.length} file(s)');
      await _load();
    } catch (e) {
      _toast('Upload failed: $e');
    }
  }

  Future<void> _download(FileEntry e) async {
    final outPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save as',
      fileName: e.name,
    );
    if (outPath == null) return;
    try {
      final src = await _src();
      await src!.downloadFile(widget.container, e.path, outPath);
      _toast('Saved to $outPath');
    } catch (err) {
      _toast('Download failed: $err');
    }
  }

  Future<void> _downloadSelected() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Save selected files into folder',
    );
    if (dir == null) return;
    try {
      final src = await _src();
      final files =
          _entries.where((e) => _selected.contains(e.path) && !e.isFolder);
      var n = 0;
      for (final e in files) {
        await src!.downloadFile(widget.container, e.path, p.join(dir, e.name));
        n++;
      }
      _toast('Saved $n file(s) to $dir');
    } catch (e) {
      _toast('Download failed: $e');
    }
  }

  Future<void> _delete(List<String> paths) async {
    if (paths.isEmpty) return;
    if (ref.read(settingsProvider).confirmDeletes) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete'),
          content: Text(paths.length == 1
              ? 'Delete "${paths.first}"?'
              : 'Delete ${paths.length} items? Folders remove all contents.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      final src = await _src();
      await src!.deleteEntries(widget.container, paths);
      _toast('Deleted ${paths.length} item(s)');
      await _load();
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  Future<void> _rename(FileEntry e) async {
    final newName = await _promptText('Rename', 'New name', initial: e.name);
    if (newName == null || newName.trim().isEmpty || newName == e.name) return;
    final from = e.path;
    final to = e.isFolder
        ? '$_path${newName.trim()}/'
        : '$_path${newName.trim()}';
    try {
      final src = await _src();
      await src!.moveEntry(widget.container, from, to);
      _toast('Renamed to ${newName.trim()}');
      await _load();
    } catch (err) {
      _toast('Rename failed: $err');
    }
  }

  Future<void> _moveOrCopy(FileEntry e, {required bool move}) async {
    final dest = await _promptText(
      move ? 'Move to' : 'Copy to',
      'Destination path (folder prefix or full key)',
      initial: e.path,
    );
    if (dest == null || dest.trim().isEmpty || dest.trim() == e.path) return;
    var to = dest.trim();
    if (e.isFolder && !to.endsWith('/')) to = '$to/';
    try {
      final src = await _src();
      if (move) {
        await src!.moveEntry(widget.container, e.path, to);
      } else {
        await src!.copyEntry(widget.container, e.path, to);
      }
      _toast(move ? 'Moved' : 'Copied');
      await _load();
    } catch (err) {
      _toast('${move ? 'Move' : 'Copy'} failed: $err');
    }
  }

  Future<void> _share(FileEntry e) async {
    try {
      final src = await _src();
      final url = await src!.shareLink(widget.container, e.path);
      if (url == null) {
        _toast('Sharing not supported');
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Share link'),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.of(context).pop();
                _toast('Link copied');
              },
              child: const Text('Copy'),
            ),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close')),
          ],
        ),
      );
    } catch (err) {
      _toast('Share failed: $err');
    }
  }

  Future<String?> _promptText(String title, String label,
      {String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
  }

  // --- Preview --------------------------------------------------------------

  Future<void> _preview(FileEntry e) async {
    if (!mounted) return;
    final kind = _kindOf(e.name);
    FileBytes? data;
    Object? readErr;
    if (kind == _Kind.image || kind == _Kind.text) {
      try {
        final src = await _src();
        data = await src!.readBytes(widget.container, e.path);
      } catch (err) {
        readErr = err;
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            Row(
              children: [
                Icon(_iconFor(e), size: 20),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(e.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            _metaRow('Path', e.path),
            if (e.size != null) _metaRow('Size', _humanSize(e.size!)),
            if (e.contentType != null) _metaRow('Type', e.contentType!),
            if (e.etag != null) _metaRow('ETag', e.etag!),
            if (e.modified != null)
              _metaRow('Modified', e.modified!.toLocal().toString()),
            const Divider(height: Spacing.xl),
            if (readErr != null)
              Text('Preview failed: $readErr',
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (data == null)
              _noPreview(e)
            else
              _previewBody(e, kind, data),
          ],
        ),
      ),
    );
  }

  Widget _previewBody(FileEntry e, _Kind kind, FileBytes data) {
    final bytes = Uint8List.fromList(data.bytes);
    Widget body;
    if (kind == _Kind.image) {
      body = InteractiveViewer(
        child: Image.memory(bytes,
            errorBuilder: (ctx, err, st) => _noPreview(e)),
      );
    } else {
      var text = utf8.decode(data.bytes, allowMalformed: true);
      if (e.name.toLowerCase().endsWith('.json')) {
        try {
          text = const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
        } catch (_) {/* leave raw */}
      }
      body = SelectableText(text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.truncated)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text('Preview truncated (large file).',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        body,
      ],
    );
  }

  Widget _noPreview(FileEntry e) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('No inline preview for this file type.'),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.sm,
          children: [
            if (_ops.contains(FileOp.download))
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _download(e);
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download'),
              ),
            if (_ops.contains(FileOp.share))
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _share(e);
                },
                icon: const Icon(Icons.link, size: 16),
                label: const Text('Share'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _metaRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 80,
                child: Text(k,
                    style: Theme.of(context).textTheme.labelMedium)),
            Expanded(child: SelectableText(v)),
          ],
        ),
      );

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Column(
      children: [
        _breadcrumbBar(),
        _toolbar(),
        if (_selected.isNotEmpty) _selectionBar(),
        if (_error != null)
          ErrorBanner(error: _error!, onDismiss: () => setState(() => _error = null)),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else
          const Divider(height: 1),
        Expanded(
          child: visible.isEmpty && _error == null
              ? Center(
                  child: Text(_query.isEmpty ? 'Empty folder' : 'No matches'))
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) => _row(visible[i]),
                ),
        ),
      ],
    );
  }

  Widget _breadcrumbBar() {
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList();
    final crumbs = <Widget>[
      _crumb(widget.container.name, ''),
    ];
    var acc = '';
    for (final s in segments) {
      acc = '$acc$s/';
      crumbs
        ..add(const Icon(Icons.chevron_right, size: 16))
        ..add(_crumb(s, acc));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: crumbs),
      ),
    );
  }

  Widget _crumb(String label, String path) => TextButton(
        onPressed: _path == path ? null : () => _navigateTo(path),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            minimumSize: Size.zero),
        child: Text(label),
      );

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.xs),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Up',
            icon: const Icon(Icons.arrow_upward),
            onPressed: _path.isEmpty || _loading
                ? null
                : () {
                    final segs =
                        _path.split('/').where((s) => s.isNotEmpty).toList()
                          ..removeLast();
                    _navigateTo(
                        segs.isEmpty ? '' : '${segs.join('/')}/');
                  },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          if (_ops.contains(FileOp.makeFolder))
            IconButton(
              tooltip: 'New folder',
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: _loading ? null : _newFolder,
            ),
          PopupMenuButton<_SortKey>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _SortKey.name, child: Text('Name')),
              PopupMenuItem(value: _SortKey.size, child: Text('Size')),
              PopupMenuItem(value: _SortKey.modified, child: Text('Modified')),
            ],
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Filter this folder…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          if (_ops.contains(FileOp.upload))
            FilledButton.icon(
              onPressed: _loading ? null : _upload,
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Upload'),
            ),
        ],
      ),
    );
  }

  Widget _selectionBar() {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.xs),
        child: Row(
          children: [
            Text('${_selected.length} selected'),
            const Spacer(),
            if (_ops.contains(FileOp.download))
              TextButton.icon(
                onPressed: _downloadSelected,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download'),
              ),
            if (_ops.contains(FileOp.delete))
              TextButton.icon(
                onPressed: () => _delete(_selected.toList()),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
              ),
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(FileEntry e) {
    final selected = _selected.contains(e.path);
    return ListTile(
      dense: true,
      selected: selected,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: selected,
            onChanged: (v) => setState(() {
              if (v == true) {
                _selected.add(e.path);
              } else {
                _selected.remove(e.path);
              }
            }),
          ),
          Icon(_iconFor(e), size: 18),
        ],
      ),
      title: Text(e.name, overflow: TextOverflow.ellipsis),
      subtitle: e.isFolder
          ? null
          : Text([
              if (e.size != null) _humanSize(e.size!),
              if (e.modified != null) e.modified!.toLocal().toString(),
            ].join('  ·  '),
              style: Theme.of(context).textTheme.bodySmall),
      onTap: () => e.isFolder ? _navigateTo(e.path) : _preview(e),
      trailing: e.isFolder ? _folderMenu(e) : _fileMenu(e),
    );
  }

  Widget _fileMenu(FileEntry e) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, size: 18),
        onSelected: (v) => _onAction(v, e),
        itemBuilder: (_) => [
          if (_ops.contains(FileOp.preview))
            const PopupMenuItem(value: 'preview', child: Text('Preview')),
          if (_ops.contains(FileOp.download))
            const PopupMenuItem(value: 'download', child: Text('Download')),
          if (_ops.contains(FileOp.share))
            const PopupMenuItem(value: 'share', child: Text('Share link')),
          if (_ops.contains(FileOp.rename))
            const PopupMenuItem(value: 'rename', child: Text('Rename')),
          if (_ops.contains(FileOp.move))
            const PopupMenuItem(value: 'move', child: Text('Move to…')),
          if (_ops.contains(FileOp.copy))
            const PopupMenuItem(value: 'copy', child: Text('Copy to…')),
          if (_ops.contains(FileOp.delete))
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );

  Widget _folderMenu(FileEntry e) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, size: 18),
        onSelected: (v) => _onAction(v, e),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'open', child: Text('Open')),
          if (_ops.contains(FileOp.rename))
            const PopupMenuItem(value: 'rename', child: Text('Rename')),
          if (_ops.contains(FileOp.move))
            const PopupMenuItem(value: 'move', child: Text('Move to…')),
          if (_ops.contains(FileOp.copy))
            const PopupMenuItem(value: 'copy', child: Text('Copy to…')),
          if (_ops.contains(FileOp.delete))
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );

  void _onAction(String v, FileEntry e) {
    switch (v) {
      case 'open':
        _navigateTo(e.path);
      case 'preview':
        _preview(e);
      case 'download':
        _download(e);
      case 'share':
        _share(e);
      case 'rename':
        _rename(e);
      case 'move':
        _moveOrCopy(e, move: true);
      case 'copy':
        _moveOrCopy(e, move: false);
      case 'delete':
        _delete([e.path]);
    }
  }

  // --- Display helpers ------------------------------------------------------

  IconData _iconFor(FileEntry e) {
    if (e.isFolder) return Icons.folder;
    return switch (_kindOf(e.name)) {
      _Kind.image => Icons.image_outlined,
      _Kind.text => Icons.description_outlined,
      _Kind.archive => Icons.folder_zip_outlined,
      _Kind.pdf => Icons.picture_as_pdf_outlined,
      _Kind.other => Icons.insert_drive_file_outlined,
    };
  }

  static String _humanSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var u = 0;
    while (size >= 1024 && u < units.length - 1) {
      size /= 1024;
      u++;
    }
    return '${size.toStringAsFixed(u == 0 ? 0 : 1)} ${units[u]}';
  }
}

enum _Kind { image, text, pdf, archive, other }

_Kind _kindOf(String name) {
  final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
  const image = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico'};
  const text = {
    'txt', 'json', 'csv', 'tsv', 'md', 'log', 'yaml', 'yml', 'xml', 'html',
    'htm', 'dart', 'js', 'ts', 'jsx', 'tsx', 'py', 'java', 'c', 'cpp', 'h',
    'hpp', 'go', 'rs', 'rb', 'sh', 'sql', 'ini', 'toml', 'conf', 'env', 'css',
  };
  const archive = {'zip', 'tar', 'gz', 'tgz', 'rar', '7z', 'bz2', 'xz'};
  if (image.contains(ext)) return _Kind.image;
  if (text.contains(ext)) return _Kind.text;
  if (ext == 'pdf') return _Kind.pdf;
  if (archive.contains(ext)) return _Kind.archive;
  return _Kind.other;
}
