import 'package:flutter/material.dart';

class ValueEditor extends StatefulWidget {
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
  State<ValueEditor> createState() => _ValueEditorState();
}

class _ValueEditorState extends State<ValueEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(covariant ValueEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.text = '${widget.value}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(int newValue) {
    widget.onSet(newValue);
    _controller.text = '$newValue';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label),
        IconButton(
          icon: const Icon(Icons.remove),
          visualDensity: VisualDensity.compact,
          onPressed: () => _set(widget.value - 1),
        ),
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(kDefaultFontSize) * '${widget.value}'.length,
          child: TextField(
            controller: _controller,
            onSubmitted: (newValueS) {
              final newValue = int.parse(newValueS);
              _set(newValue);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          visualDensity: VisualDensity.compact,
          onPressed: () => _set(widget.value + 1),
        ),
      ],
    );
  }
}
