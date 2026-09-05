import 'package:flutter/material.dart';

class ValueEditor extends StatelessWidget {
  final String label;
  final int value;
  final void Function(int) onSet;

  const ValueEditor({
    super.key,
    required this.label,
    required this.value,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        IconButton(
          icon: const Icon(Icons.remove),
          visualDensity: VisualDensity.compact,
          onPressed: () => onSet(value - 1),
        ),
        Text('$value'),
        IconButton(
          icon: const Icon(Icons.add),
          visualDensity: VisualDensity.compact,
          onPressed: () => onSet(value + 1),
        ),
      ],
    );
  }
}
