import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Centered digit boxes — length **4** or **6** (default **6** to match “6-digit code” copy).
class SignaraOtpInput extends StatefulWidget {
  const SignaraOtpInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
  });

  final int length;
  final void Function(String value)? onChanged;
  final void Function(String code)? onCompleted;

  @override
  State<SignaraOtpInput> createState() => _SignaraOtpInputState();
}

class _SignaraOtpInputState extends State<SignaraOtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    final n = widget.length;
    _controllers = List.generate(n, (_) => TextEditingController());
    _focusNodes = List.generate(n, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _emit() {
    widget.onChanged?.call(_code);
    if (_code.length == widget.length) {
      widget.onCompleted?.call(_code);
    }
  }

  void _onDigit(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _controllers[index].text = '';
      _emit();
      return;
    }
    final d = digits.substring(digits.length - 1);
    _controllers[index].text = d;
    if (index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
    setState(() {});
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (i) {
        final has = _controllers[i].text.isNotEmpty;
        final borderColor = has
            ? AppColors.signaraGold.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.22);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < widget.length - 1 ? 8 : 0),
            child: AspectRatio(
              aspectRatio: 1,
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: TextStyle(
                  color: has ? AppColors.signaraGold : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.signaraGold.withValues(alpha: 0.9), width: 1.5),
                  ),
                ),
                onChanged: (v) => _onDigit(i, v),
              ),
            ),
          ),
        );
      }),
    );
  }
}
