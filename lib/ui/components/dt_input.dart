import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../theme/dt_theme.dart';

/// All product text inputs use Forui, including multi-line composers. Borders
/// stay modest and multiline inputs never inherit a pill-shaped Material theme.
class DtTextField extends StatelessWidget {
  const DtTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.minLines,
    this.maxLines = 1,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.enabled = true,
  });
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final int? minLines;
  final int maxLines;
  final bool autofocus,
      obscureText,
      autocorrect,
      enableSuggestions,
      readOnly,
      enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged, onSubmitted;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final multi = maxLines > 1;
    return FTextField(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChange: onChanged,
      onSubmit: onSubmitted,
      readOnly: readOnly,
      enabled: enabled,
      label: decoration.labelText == null ? null : Text(decoration.labelText!),
      hint: decoration.hintText,
      description: decoration.helperText == null
          ? null
          : Text(decoration.helperText!),
      error: decoration.errorText == null ? null : Text(decoration.errorText!),
      prefixBuilder: decoration.prefixIcon == null
          ? null
          : (_, __, ___) => Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: decoration.prefixIcon,
            ),
      suffixBuilder: decoration.suffixIcon == null
          ? null
          : (_, __, ___) => decoration.suffixIcon!,
      style: (style) => style.copyWith(
        filled: decoration.filled ?? true,
        fillColor: dark ? DtColors.darkElevated : DtColors.surfaceMuted,
        cursorColor: dark ? const Color(0xFFAA99FF) : DtColors.brand,
        contentPadding:
            decoration.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        contentTextStyle: FWidgetStateMap.all(
          TextStyle(
            fontSize: 15,
            height: 1.5,
            color: dark ? const Color(0xFFEEEEF2) : DtColors.ink,
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          ),
        ),
        hintTextStyle: FWidgetStateMap.all(
          TextStyle(fontSize: 15, height: 1.5, color: DtColors.textTertiary),
        ),
        border: FWidgetStateMap({
          WidgetState.focused: OutlineInputBorder(
            borderRadius: BorderRadius.circular(multi ? 10 : 8),
            borderSide: BorderSide(
              color: dark ? const Color(0xFF7562CE) : const Color(0xFFB5A8F5),
              width: 0.8,
            ),
          ),
          WidgetState.any: OutlineInputBorder(
            borderRadius: BorderRadius.circular(multi ? 10 : 8),
            borderSide: BorderSide.none,
          ),
        }),
      ),
    );
  }
}
