import 'dart:io';
import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../theme.dart';

class FolderPicker extends StatefulWidget {
  final bool showImagePreview;

  const FolderPicker({super.key, this.showImagePreview = true});

  @override
  State<FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<FolderPicker> {
  String? _currentPath;
  List<Map<String, String>> _dirs = [];
  List<String> _images = [];
  final List<String> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await FileService.ensurePermissions();
    final results = await Future.wait([
      FileService.getRootPath(),
      FileService.listDirs(null),
    ]);
    setState(() {
      _currentPath = results[0] as String;
      _dirs        = results[1] as List<Map<String, String>>;
      _history.add(_currentPath!);
      _loading     = false;
    });
  }

  Future<void> _enter(String path) async {
    setState(() => _loading = true);
    final results = await Future.wait([
      FileService.listDirs(path),
      if (widget.showImagePreview) FileService.scanFolder(path),
    ]);
    setState(() {
      _currentPath = path;
      _dirs        = results[0] as List<Map<String, String>>;
      _images      = widget.showImagePreview
          ? results[1] as List<String>
          : [];
      _history.add(path);
      _loading     = false;
    });
  }

  Future<void> _back() async {
    if (_history.length <= 1) return;
    _history.removeLast();
    final prev = _history.last;
    setState(() => _loading = true);
    final results = await Future.wait([
      FileService.listDirs(_history.length == 1 ? null : prev),
      if (widget.showImagePreview) FileService.scanFolder(prev),
    ]);
    setState(() {
      _currentPath = prev;
      _dirs        = results[0] as List<Map<String, String>>;
      _images      = widget.showImagePreview
          ? results[1] as List<String>
          : [];
      _loading     = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final folderName = _currentPath?.split('/').last ?? 'Storage';

    return Scaffold(
      backgroundColor: FotoColors.background,
      appBar: AppBar(
        title: Text(folderName, style: FotoText.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined),
          onPressed: () {
            if (_history.length > 1) {
              _back();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _currentPath != null
                  ? () => Navigator.of(context).pop(_currentPath)
                  : null,
              child: const Text('Use this',
                  style: TextStyle(
                      color: FotoColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: FotoColors.textSecondary))
          : Column(children: [

              // Image preview grid — 2 rows × 4 cols
              if (widget.showImagePreview && _images.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      FotoSpacing.md, FotoSpacing.md,
                      FotoSpacing.md, 0),
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      const cols     = 4;
                      const gap      = FotoSpacing.xs;
                      final cellSize =
                          (constraints.maxWidth - gap * (cols - 1)) / cols;
                      final shown = _images.length.clamp(0, 8);
                      final extra = _images.length - 8;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: List.generate(shown, (i) => ClipRRect(
                              borderRadius: FotoRadius.chip,
                              child: Opacity(
                                opacity: 0.85,
                                child: Image.file(
                                  File(_images[i]),
                                  width: cellSize,
                                  height: cellSize,
                                  fit: BoxFit.cover,
                                  cacheWidth: (cellSize * 2).toInt(),
                                  errorBuilder: (_, __, ___) => Container(
                                    width: cellSize,
                                    height: cellSize,
                                    decoration: BoxDecoration(
                                      color: FotoColors.surfaceAlt,
                                      borderRadius: FotoRadius.chip,
                                    ),
                                  ),
                                ),
                              ),
                            )),
                          ),
                          if (extra > 0) ...[
                            const SizedBox(height: FotoSpacing.xs),
                            Text(
                              '+$extra more photo${extra != 1 ? 's' : ''}',
                              style: FotoText.micro,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: FotoSpacing.md),
                const Divider(height: 1, color: FotoColors.divider),
              ],

              // Folder list
              Expanded(
                child: _dirs.isEmpty
                    ? Center(
                        child: Text('No subfolders here.',
                            style: FotoText.caption),
                      )
                    : ListView.separated(
                        itemCount: _dirs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: FotoColors.divider),
                        itemBuilder: (_, i) => ListTile(
                          leading: const Icon(Icons.folder_rounded,
                              color: FotoColors.textSecondary, size: 20),
                          title: Text(_dirs[i]['name'] ?? '',
                              style: FotoText.body),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: FotoColors.textHint, size: 18),
                          onTap: () => _enter(_dirs[i]['path']!),
                        ),
                      ),
              ),
            ]),
    );
  }
}