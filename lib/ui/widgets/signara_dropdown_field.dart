import 'package:flutter/material.dart';

/// Same outline style as [SignaraTextField] — use for gender / single-select fields.
///
/// [value] puede ser null para mostrar un hint (placeholder) cuando no hay
/// seleccion — util en dropdowns opcionales como Breed.
class SignaraDropdownField extends StatelessWidget {
  const SignaraDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelTextAlign = TextAlign.start,
    this.hintText,
  });

  final String label;
  final String? value;           // null = sin seleccion (muestra hintText)
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final TextAlign labelTextAlign;
  final String? hintText;        // placeholder cuando value == null

  static const double _radius = 10;

  @override
  Widget build(BuildContext context) {
    // Valor efectivo: null si no esta en la lista (muestra hint)
    final effectiveValue = (value != null && items.contains(value)) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: labelTextAlign,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 100),
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              isExpanded: true,
              borderRadius: BorderRadius.circular(_radius),
              dropdownColor: const Color(0xFF1E2A22),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              hint: hintText != null
                  ? Text(
                      hintText!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  : null,
              items: items
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
