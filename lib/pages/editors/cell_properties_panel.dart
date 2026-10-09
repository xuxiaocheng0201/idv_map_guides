import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/l10n.dart';

class CellPropertiesPanel extends StatelessWidget {
  final Position position;
  final CellInfo cell;
  final ValueChanged<CellInfo> onChanged;
  final VoidCallback onDelete;

  final bool showStairs;
  final bool showResource;
  final bool showDoorQuickToggle;

  const CellPropertiesPanel({
    super.key,
    required this.position,
    required this.cell,
    required this.onChanged,
    required this.onDelete,
    this.showStairs = true,
    this.showResource = true,
    this.showDoorQuickToggle = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '单元格 (${position.x}, ${position.y})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: '删除此单元格',
                onPressed: onDelete,
              ),
            ],
          ),
          const Divider(),
          if (showStairs) _buildStairs(context),
          if (showResource) _buildResource(),
          const Text('边类型', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final direction in Direction.values)
            _buildEdgeRow(context, direction),
        ],
      ),
    );
  }

  Widget _buildStairs(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('楼梯', style: TextStyle(fontWeight: FontWeight.bold)),
          value: cell.isStair != null,
          onChanged: (v) => onChanged(
            cell.copyWith(isStair: v ? StairTransport.nothing : null),
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (cell.isStair != null)
          Row(
            children: [
              const Text('楼梯朝向'),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<StairTransport>(
                  value: cell.isStair,
                  items: StairTransport.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label(context))))
                    .toList(),
                  onChanged: (t) {
                    if (t != null) onChanged(cell.copyWith(isStair: t));
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResource() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('刷箱点', style: TextStyle(fontWeight: FontWeight.bold)),
          value: cell.isResource,
          onChanged: (v) => onChanged(cell.copyWith(isResource: v)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEdgeRow(BuildContext context, Direction direction) {
    final edgeType = cell.getEdgeType(direction);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(direction.label(context)),
          const SizedBox(width: 8),
          if (showDoorQuickToggle) ...[
            _DoorQuickToggle(
              edgeType: edgeType,
              onToggle: (v) => onChanged(cell.setEdgeType(
                direction,
                v ? EdgeType.door : EdgeType.nothing,
              )),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: DropdownButton<EdgeType>(
              value: edgeType,
              items: EdgeType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label(context))))
                .toList(),
              onChanged: (t) {
                if (t != null) onChanged(cell.setEdgeType(direction, t));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DoorQuickToggle extends StatelessWidget {
  final EdgeType edgeType;
  final ValueChanged<bool> onToggle;
  const _DoorQuickToggle({required this.edgeType, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDoor = edgeType == EdgeType.door;
    final isToggleable = isDoor || edgeType == EdgeType.nothing;
    return Tooltip(
      message: isToggleable
        ? (isDoor ? '门（点击设为无）' : '无（点击设为门）')
        : '当前为「${edgeType.label(context)}」',
      child: Switch(
        value: isDoor,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: isToggleable ? onToggle : null,
      ),
    );
  }
}
