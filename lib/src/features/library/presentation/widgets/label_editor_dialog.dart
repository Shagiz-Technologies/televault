import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class LabelEditorResult {
  final String name;
  final String colorHex;

  const LabelEditorResult({required this.name, required this.colorHex});
}

Future<LabelEditorResult?> showLabelEditorDialog(BuildContext context) {
  return showDialog<LabelEditorResult>(
    context: context,
    useSafeArea: true,
    builder: (_) => const _LabelEditorDialog(),
  );
}

class _LabelEditorDialog extends StatefulWidget {
  const _LabelEditorDialog();

  @override
  State<_LabelEditorDialog> createState() => _LabelEditorDialogState();
}

class _LabelEditorDialogState extends State<_LabelEditorDialog> {
  static const _colors = <String>[
    '#168CE8',
    '#14A37F',
    '#F0564A',
    '#E79A18',
    '#8B5CF6',
    '#0F9FA8',
  ];

  final _nameController = TextEditingController();
  String _selectedColor = _colors.first;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      scrollable: true,
      icon: const CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.primarySoft,
        child: Icon(Icons.new_label_outlined, color: AppTheme.primary),
      ),
      title: const Text('Create label', textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('label-name-field'),
              controller: _nameController,
              autofocus: true,
              maxLength: 11,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Trip, Work, ★',
                helperText: 'Any text, symbol, or emoji. Up to 11 characters.',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Text(
              'Color',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppTheme.inkMuted),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors
                  .map((hex) {
                    final selected = _selectedColor == hex;
                    final color = _parseColor(hex);
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: 'Label color $hex',
                      child: InkResponse(
                        key: ValueKey('label-color-$hex'),
                        radius: 25,
                        onTap: () => setState(() => _selectedColor = hex),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? AppTheme.ink
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a label name');
      return;
    }
    Navigator.pop(
      context,
      LabelEditorResult(name: name, colorHex: _selectedColor),
    );
  }

  Color _parseColor(String value) {
    return Color(int.parse('FF${value.substring(1)}', radix: 16));
  }
}
