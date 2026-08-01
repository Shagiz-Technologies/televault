import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<String?> showSecureTextDialog(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  required String actionLabel,
  String? description,
  String? hintText,
  String confirmLabel = 'Confirm',
  int minLength = 1,
  String? minLengthMessage,
  bool requireConfirmation = false,
  bool hideConfirmationWhenVisible = true,
  TextInputType keyboardType = TextInputType.visiblePassword,
  int? maxLength,
}) {
  return showDialog<String>(
    context: context,
    useSafeArea: true,
    builder: (_) => _SecureTextDialog(
      title: title,
      fieldLabel: fieldLabel,
      actionLabel: actionLabel,
      description: description,
      hintText: hintText,
      confirmLabel: confirmLabel,
      minLength: minLength,
      minLengthMessage: minLengthMessage,
      requireConfirmation: requireConfirmation,
      hideConfirmationWhenVisible: hideConfirmationWhenVisible,
      keyboardType: keyboardType,
      maxLength: maxLength,
    ),
  );
}

class _SecureTextDialog extends StatefulWidget {
  final String title;
  final String fieldLabel;
  final String actionLabel;
  final String? description;
  final String? hintText;
  final String confirmLabel;
  final int minLength;
  final String? minLengthMessage;
  final bool requireConfirmation;
  final bool hideConfirmationWhenVisible;
  final TextInputType keyboardType;
  final int? maxLength;

  const _SecureTextDialog({
    required this.title,
    required this.fieldLabel,
    required this.actionLabel,
    required this.confirmLabel,
    required this.minLength,
    required this.requireConfirmation,
    required this.hideConfirmationWhenVisible,
    required this.keyboardType,
    this.description,
    this.hintText,
    this.minLengthMessage,
    this.maxLength,
  });

  @override
  State<_SecureTextDialog> createState() => _SecureTextDialogState();
}

class _SecureTextDialogState extends State<_SecureTextDialog> {
  final _valueCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  bool get _confirmationVisible {
    if (!widget.requireConfirmation) return false;
    if (widget.hideConfirmationWhenVisible && !_obscure) return false;
    return true;
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      scrollable: true,
      icon: const CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.primarySoft,
        child: Icon(Icons.lock_outline_rounded, color: AppTheme.primary),
      ),
      title: Text(widget.title, textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.description != null) ...[
                Text(
                  widget.description!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _valueCtrl,
                autofocus: true,
                obscureText: _obscure,
                keyboardType: widget.keyboardType,
                maxLength: widget.maxLength,
                textInputAction: _confirmationVisible
                    ? TextInputAction.next
                    : TextInputAction.done,
                decoration: _fieldDecoration(
                  label: widget.fieldLabel,
                  hint: widget.hintText,
                  suffix: IconButton(
                    tooltip: _obscure ? 'Show' : 'Hide',
                    onPressed: () {
                      setState(() {
                        _obscure = !_obscure;
                        _error = null;
                      });
                    },
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  if (!_confirmationVisible) _submit();
                },
              ),
              if (_confirmationVisible) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  keyboardType: widget.keyboardType,
                  maxLength: widget.maxLength,
                  textInputAction: TextInputAction.done,
                  decoration: _fieldDecoration(label: widget.confirmLabel),
                  onSubmitted: (_) => _submit(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 12),
                ),
              ],
              if (widget.requireConfirmation &&
                  widget.hideConfirmationWhenVisible &&
                  !_obscure) ...[
                const SizedBox(height: 10),
                const Text(
                  'Confirmation is hidden because the value is visible.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      counterText: '',
      filled: true,
      fillColor: AppTheme.paperMuted,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
    );
  }

  void _submit() {
    final value = _valueCtrl.text.trim();
    if (value.length < widget.minLength) {
      setState(() {
        _error =
            widget.minLengthMessage ??
            'Use at least ${widget.minLength} characters.';
      });
      return;
    }

    if (_confirmationVisible && value != _confirmCtrl.text.trim()) {
      setState(() => _error = 'Values do not match.');
      return;
    }

    Navigator.of(context).pop(value);
  }
}
