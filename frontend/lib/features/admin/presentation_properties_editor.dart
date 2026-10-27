import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/config/app_properties.dart';
import 'package:frontend/core/constants/strings.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';

/// Loaded on expansion so the operational settings remain independently usable.
class PresentationPropertiesEditor extends StatefulWidget {
  const PresentationPropertiesEditor({
    super.key,
    required this.repository,
    required this.canManage,
  });
  final AdminRepository repository;
  final bool canManage;
  @override
  State<PresentationPropertiesEditor> createState() =>
      _PresentationPropertiesEditorState();
}

class _PresentationPropertiesEditorState
    extends State<PresentationPropertiesEditor> {
  Map<String, dynamic>? _snapshot;
  final _controllers = <String, TextEditingController>{};
  final _search = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _dirty = false;
  int _page = 0;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _search.dispose();
    super.dispose();
  }

  void _setSnapshot(Map<String, dynamic> data) {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    final defaults = Map<String, dynamic>.from(data['defaults'] as Map);
    final draft = Map<String, dynamic>.from(data['draft'] as Map? ?? {});
    for (final entry in defaults.entries) {
      _controllers[entry.key] = TextEditingController(
        text: (draft[entry.key] ?? entry.value).toString(),
      );
    }
    _snapshot = data;
    _dirty = false;
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    if (_dirty && !await _confirm('Discard unsaved property edits?')) return;
    await _perform(() async {
      final data = await widget.repository.getPresentationProperties();
      if (mounted) setState(() => _setSnapshot(data));
    });
  }

  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(
            AppCopy.text(
              'text.published_properties_apply_to_all_users_when_the_56658d4e',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppCopy.text('text.cancel_35afca3b')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppCopy.text('text.continue_ab43d664')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _mutate(String action, {int? revision}) async {
    if (action != 'save' &&
        !await _confirm(
          action == 'publish'
              ? 'Publish saved draft?'
              : 'Restore revision $revision?',
        )) {
      return;
    }
    await _perform(() async {
      final data = await widget.repository.updatePresentationProperties({
        'action': action,
        'expectedVersion': _snapshot!['version'],
        if (action == 'save')
          'properties': {
            for (final entry in _controllers.entries)
              entry.key: entry.value.text,
          },
        if (revision != null) 'revision': revision,
      });
      if (!mounted) return;
      setState(() => _setSnapshot(data));
      if (action != 'save') await AppProperties.instance.refresh(force: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'save'
                  ? AppCopy.text(
                      'text.draft_saved_publish_to_make_it_available_to_user_27133b8',
                    )
                  : AppCopy.text('text.properties_published_b902d848'),
            ),
          ),
        );
      }
    });
  }

  Future<void> _upload(String key) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (selection == null || !mounted) return;
    final bytes = selection.files.single.bytes;
    if (bytes == null || bytes.length > 512 * 1024) {
      setState(() => _error = 'Choose a PNG or JPEG no larger than 512 KiB.');
      return;
    }
    await _perform(() async {
      final result = await widget.repository.uploadBrandImage(
        base64Encode(bytes),
      );
      if (mounted) {
        setState(() {
          _controllers[key]!.text = result['asset'] as String;
          _dirty = true;
        });
      }
    });
  }

  Widget _preview() {
    final name = _controllers['branding.appName']?.text ?? 'VitaLink';
    final hex = _controllers['theme.primary']?.text ?? '#648FFF';
    final color = RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(hex)
        ? Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16))
        : Theme.of(context).colorScheme.primary;
    var logo = _controllers['asset.hospitalLogo']?.text ?? '';
    if (logo.startsWith('brand-asset:')) {
      logo =
          '${AppStrings.apiBaseUrl}${AppStrings.apiPathPrefix}/app-properties/assets/${logo.substring(12)}';
    }
    final uri = Uri.tryParse(logo);
    return Semantics(
      label: AppCopy.text('text.draft_branding_preview_edf53b57'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (logo.startsWith('assets/'))
              Image.asset(logo, height: 48, width: 100, fit: BoxFit.contain),
            if (uri != null && (uri.scheme == 'https' || logo.startsWith('/')))
              Image.network(
                logo,
                height: 48,
                width: 100,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.broken_image_outlined,
                  semanticLabel: AppCopy.text(
                    'text.image_preview_unavailable_516e1158',
                  ),
                ),
              ),
            Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: color),
            ),
            Text(AppCopy.text('text.draft_preview_27961280')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final filter = _search.text.toLowerCase();
    final keys =
        _controllers.keys
            .where(
              (key) =>
                  key.toLowerCase().contains(filter) ||
                  _controllers[key]!.text.toLowerCase().contains(filter),
            )
            .toList()
          ..sort();
    final pages = (keys.length / 20).ceil();
    final page = _page.clamp(0, pages > 0 ? pages - 1 : 0);
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        title: Text(AppCopy.text('text.application_properties_8cea236')),
        subtitle: Text(
          AppCopy.text('text.screen_text_logos_and_branding_1f4854a8'),
        ),
        onExpansionChanged: (expanded) {
          if (expanded && _snapshot == null) _load();
        },
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_snapshot == null && !_busy)
            OutlinedButton(
              onPressed: _load,
              child: Text(AppCopy.text('text.load_properties_ffe57402')),
            ),
          if (_snapshot != null) ...[
            Text(
              AppCopy.text(
                'text.published_revision_value1_value2_properties_valu_788545ff',
                arguments: {
                  'value1': (_snapshot!['published_revision']).toString(),
                  'value2': (_controllers.length).toString(),
                  'value3': (_dirty ? ' · Unsaved edits' : '').toString(),
                },
              ),
            ),
            const SizedBox(height: 12),
            _preview(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppCopy.text('text.reload_1a43a2ac')),
                ),
                if (widget.canManage) ...[
                  OutlinedButton(
                    onPressed: _busy || !_dirty ? null : () => _mutate('save'),
                    child: Text(AppCopy.text('text.save_draft_193e264b')),
                  ),
                  FilledButton(
                    onPressed: _busy || _dirty
                        ? null
                        : () => _mutate('publish'),
                    child: Text(
                      AppCopy.text('text.publish_saved_draft_25b1b90'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: AppCopy.text('text.find_a_property_3379c8f6'),
                hintText: AppCopy.text(
                  'text.search_by_name_or_current_text_2ca70a9e',
                ),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() => _page = 0),
            ),
            const SizedBox(height: 12),
            for (final key in keys.skip(page * 20).take(20))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: ValueKey(key),
                      controller: _controllers[key],
                      enabled: widget.canManage && !_busy,
                      maxLines: key.startsWith('text.') ? 3 : 1,
                      minLines: 1,
                      decoration: InputDecoration(
                        labelText: key,
                        helperText: key.startsWith('asset.')
                            ? AppCopy.text(
                                'text.bundled_default_https_url_or_uploaded_image_maxi_c2fb926f',
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                    if (widget.canManage)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _controllers[key]!.text =
                                        '${(_snapshot!['defaults'] as Map)[key]}';
                                    _dirty = true;
                                  }),
                            child: Text(
                              AppCopy.text('text.use_default_1a9ec191'),
                            ),
                          ),
                          if (key.startsWith('asset.'))
                            TextButton.icon(
                              onPressed: _busy ? null : () => _upload(key),
                              icon: const Icon(Icons.upload_outlined),
                              label: Text(
                                AppCopy.text('text.upload_image_414d2181'),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: AppCopy.text('text.previous_properties_83d8a5fd'),
                  onPressed: page == 0
                      ? null
                      : () => setState(() => _page = page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    keys.isEmpty
                        ? AppCopy.text('text.no_matching_properties_22d6125a')
                        : AppCopy.text(
                            'text.page_value1_of_value2_bd90d60a',
                            arguments: {
                              'value1': (page + 1).toString(),
                              'value2': (pages).toString(),
                            },
                          ),
                  ),
                ),
                IconButton(
                  tooltip: AppCopy.text('text.next_properties_f2684b3d'),
                  onPressed: page + 1 >= pages
                      ? null
                      : () => setState(() => _page = page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            ExpansionTile(
              title: Text(AppCopy.text('text.publication_history_9721b789')),
              children: [
                for (final entry
                    in ((_snapshot!['history'] as List?) ?? []).reversed)
                  ListTile(
                    title: Text(
                      AppCopy.text(
                        'text.revision_value1_1035fde8',
                        arguments: {
                          'value1': ((entry as Map)['revision']).toString(),
                        },
                      ),
                    ),
                    subtitle: Text('${entry['published_at']}'),
                    trailing: widget.canManage
                        ? TextButton(
                            onPressed: _busy || _dirty
                                ? null
                                : () => _mutate(
                                    'rollback',
                                    revision: entry['revision'] as int,
                                  ),
                            child: Text(AppCopy.text('text.restore_ff87f71')),
                          )
                        : null,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
