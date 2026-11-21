import 'package:flutter/material.dart';

import 'dt_controls.dart';
import 'dt_input.dart';
import 'dt_sheet.dart';

/// Shared mobile editor/confirmation, including durable-save feedback and
/// inline errors. Controllers belong to the sheet's actual widget lifecycle.
Future<bool?> showDtEditSheet({
  required BuildContext context,
  required String title,
  required String description,
  required String actionLabel,
  required Future<void> Function(String text) onSubmit,
  String? initialText,
  bool danger = false,
  bool allowEmpty = false,
}) => showDtSheet<bool>(
  context: context,
  builder: (_) => _EditSheet(
    title: title,
    description: description,
    actionLabel: actionLabel,
    onSubmit: onSubmit,
    initialText: initialText,
    danger: danger,
    allowEmpty: allowEmpty,
  ),
);

class _EditSheet extends StatefulWidget {
  const _EditSheet({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onSubmit,
    required this.initialText,
    required this.danger,
    required this.allowEmpty,
  });
  final String title, description, actionLabel;
  final String? initialText;
  final bool danger, allowEmpty;
  final Future<void> Function(String text) onSubmit;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _text = TextEditingController(text: widget.initialText);
  DtButtonStatus _status = DtButtonStatus.idle;
  String? _error;
  bool get _busy => _status != DtButtonStatus.idle;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _status = DtButtonStatus.loading;
    });
    try {
      await widget.onSubmit(_text.text.trim());
      if (!mounted) return;
      setState(() => _status = DtButtonStatus.success);
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = DtButtonStatus.idle;
        _error = error is StateError
            ? error.message
            : error is FormatException
            ? error.message
            : error is ArgumentError
            ? '${error.message}'
            : '操作未完成，请重试。';
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              widget.description,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
            if (widget.initialText != null) ...[
              const SizedBox(height: 14),
              DtTextField(
                controller: _text,
                minLines: 3,
                maxLines: 7,
                autofocus: true,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '输入内容'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            DtButton(
              label: widget.actionLabel,
              loadingText: '正在处理…',
              successText: '已完成',
              variant: widget.danger
                  ? DtButtonVariant.danger
                  : DtButtonVariant.primary,
              status: _status,
              onPressed:
                  widget.initialText != null &&
                      _text.text.trim().isEmpty &&
                      !widget.allowEmpty
                  ? null
                  : _submit,
            ),
            const SizedBox(height: 6),
            DtButton(
              label: '取消',
              variant: DtButtonVariant.ghost,
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
}
