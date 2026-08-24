import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:idv_map_guides/generated/rust/api/editor.dart';
import 'package:idv_map_guides/generated/rust/api/map.dart';
import 'package:idv_map_guides/painter/map_painter.dart';

const gridColor = Color(0x44556677);
const selectedBorderColor = Color(0xFFFFD700);

final Paint gridPaint = Paint()
  ..color = gridColor
  ..strokeWidth = 0.5;
final Paint selectedBorderPaint = Paint()
  ..color = selectedBorderColor
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.0;

EdgeType getEdgeTypeFor(Structure structure, Position position, Direction direction) {
  final door = structure.doors.any((d) => d.position == position && d.direction == direction);
  final innerWall = structure.innerWalls.any((d) => d.position == position && d.direction == direction);
  final hole = structure.holes.any((d) => d.position == position && d.direction == direction);
  if (door) return EdgeType.door;
  if (innerWall) return EdgeType.innerWall;
  if (hole) return EdgeType.hole;
  return EdgeType.nothing;
}

(bool, bool) getStairInfo(Structure structure, Position position) {
  for (final stair in structure.stairs) {
    if (stair.position == position) {
      return (true, stair.isUp);
    }
  }
  return (false, false);
}

void removeCellData(Structure structure, Position position) {
  structure.cells.remove(position);
  structure.stairs.removeWhere((s) => s.position == position);
  structure.doors.removeWhere((d) => d.position == position);
  structure.innerWalls.removeWhere((d) => d.position == position);
  structure.holes.removeWhere((d) => d.position == position);
}

void setCellStair(Structure structure, Position position, bool isStair, bool isUp) {
  structure.stairs.removeWhere((s) => s.position == position);
  if (isStair) {
    structure.stairs.add(Stair(position: position, isUp: isUp));
  }
}

void setCellEdge(Structure structure, Position position, Direction direction, EdgeType type) {
  structure.doors.removeWhere((d) => d.position == position && d.direction == direction);
  structure.innerWalls.removeWhere((d) => d.position == position && d.direction == direction);
  structure.holes.removeWhere((d) => d.position == position && d.direction == direction);
  switch (type) {
    case EdgeType.door:
      structure.doors.add(Door(position: position, direction: direction));
      break;
    case EdgeType.innerWall:
      structure.innerWalls.add(Door(position: position, direction: direction));
      break;
    case EdgeType.hole:
      structure.holes.add(Hole(position: position, direction: direction));
      break;
    case EdgeType.nothing:
      break;
  }
}

class StructurePainter extends CustomPainter {
  final Structure structure;
  final int canvasWidth;
  final int canvasHeight;
  final Position? selectedCell;

  StructurePainter({
    required this.structure,
    required this.canvasWidth,
    required this.canvasHeight,
    this.selectedCell,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / canvasWidth;
    final cellH = size.height / canvasHeight;

    canvas.drawRect(Offset.zero & size, outsidePaint);

    for (int x = 0; x <= canvasWidth; x++) {
      final dx = x * cellW;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (int y = 0; y <= canvasHeight; y++) {
      final dy = y * cellH;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    for (final position in structure.cells) {
      final gx = position.x;
      final gy = position.y;
      if (gx < 0 || gx >= canvasWidth || gy < 0 || gy >= canvasHeight) continue;

      final screenX = gx * cellW;
      final screenY = size.height - (gy + 1) * cellH;
      final rect = Rect.fromLTWH(screenX, screenY, cellW, cellH);

      final (isStair, _) = getStairInfo(structure, position);
      drawCell(canvas, rect, structure.isCorridor, isStair);

      for (final direction in Direction.values) {
        final edgeType = getEdgeTypeFor(structure, position, direction);
        switch (edgeType) {
          case EdgeType.door:
            drawDoor(canvas, rect, direction, cellW, cellH);
            break;
          case EdgeType.innerWall:
            drawWall(canvas, rect, direction);
            break;
          case EdgeType.hole:
            drawHole(canvas, rect, direction);
            break;
          case EdgeType.nothing:
            break;
        }
      }
    }

    if (selectedCell != null) {
      final gx = selectedCell!.x;
      final gy = selectedCell!.y;
      if (gx >= 0 && gx < canvasWidth && gy >= 0 && gy < canvasHeight) {
        final screenX = gx * cellW;
        final screenY = size.height - (gy + 1) * cellH;
        final rect = Rect.fromLTWH(screenX, screenY, cellW, cellH);
        canvas.drawRect(rect, selectedBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StructurePainter oldDelegate) => true;
}

Future<Map<String, Structure>> readStructures(String path) async {
  final content = await File(path).readAsBytes();
  return await loadStructures(content: content);
}

Future<String> writeStructures(Map<String, Structure> structures, String path) async {
  final content = await saveStructures(structures: structures);
  await File(path).writeAsBytes(content);
  return File(path).absolute.path;
}

class StructuresEditorPage extends StatefulWidget {
  final String savePath;

  const StructuresEditorPage({super.key, String? savePath}): savePath = savePath ?? "structures.json";

  @override
  State<StructuresEditorPage> createState() => _StructuresEditorPageState();
}

class _StructuresEditorPageState extends State<StructuresEditorPage> {
  late Map<String, Structure> _structures;
  String? _selectedName;
  Structure? _currentStructure;

  final Map<String, int> _canvasWidths = {};
  final Map<String, int> _canvasHeights = {};
  static const int defaultCanvasWidth = 5;
  static const int defaultCanvasHeight = 5;

  Position? _selectedCell;
  final TextEditingController _addXController = TextEditingController();
  final TextEditingController _addYController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _structures = {};
    readStructures(widget.savePath).then((value) {
      setState(() {
        _structures = value;
        _structures.forEach((name, _) {
          _canvasWidths[name] = defaultCanvasWidth;
          _canvasHeights[name] = defaultCanvasHeight;
        });
        if (_structures.isNotEmpty) {
          _selectedName = _structures.keys.first;
          _currentStructure = _structures[_selectedName];
        }
      });
    });
  }

  @override
  void dispose() {
    _addXController.dispose();
    _addYController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('结构编辑器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '完成',
            onPressed: () => writeStructures(_structures, widget.savePath).then((path) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('保存成功 $path'),
                  ),
                );
              }
            }),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 260,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('新建'),
                        onPressed: _addStructure,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: '删除当前结构',
                        onPressed: _selectedName == null ? null : _deleteStructure,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _structures.length,
                    itemBuilder: (context, index) {
                      final name = _structures.keys.elementAt(index);
                      final structure = _structures[name]!;
                      final width = _canvasWidths[name] ?? defaultCanvasWidth;
                      final height = _canvasHeights[name] ?? defaultCanvasHeight;
                      final isSelected = name == _selectedName;
                      return ListTile(
                        selected: isSelected,
                        title: Text(name),
                        subtitle: Text('宽$width x 高$height | ${structure.isCorridor ? '走廊' : '房间'}'),
                        onTap: () {
                          setState(() {
                            _selectedName = name;
                            _currentStructure = structure;
                            _selectedCell = null;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _currentStructure == null
                ? const Center(child: Text('请选择或创建一个结构'))
                : _buildEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    final name = _selectedName!;
    final structure = _currentStructure!;
    final canvasWidth = _canvasWidths[name] ?? defaultCanvasWidth;
    final canvasHeight = _canvasHeights[name] ?? defaultCanvasHeight;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '结构名称',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: name),
                  onChanged: (newName) => _renameStructure(name, newName),
                ),
              ),
              const SizedBox(width: 16),
              _buildDimensionControl('宽', canvasWidth, (v) => _setCanvasWidth(name, v)),
              const SizedBox(width: 8),
              _buildDimensionControl('高', canvasHeight, (v) => _setCanvasHeight(name, v)),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('走廊'),
                  Switch(
                    value: structure.isCorridor,
                    onChanged: (value) => setState(() => structure.isCorridor = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final maxHeight = constraints.maxHeight;
                    final cellSize = min(maxWidth / canvasWidth, maxHeight / canvasHeight);
                    final paintSize = Size(canvasWidth * cellSize, canvasHeight * cellSize);
                    return InteractiveViewer(
                      constrained: false,
                      child: SizedBox(
                        width: paintSize.width,
                        height: paintSize.height,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) => _handleCanvasTap(
                            details.localPosition,
                            paintSize,
                            canvasWidth,
                            canvasHeight,
                          ),
                          child: CustomPaint(
                            size: paintSize,
                            painter: StructurePainter(
                              structure: structure,
                              canvasWidth: canvasWidth,
                              canvasHeight: canvasHeight,
                              selectedCell: _selectedCell,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: 220,
                padding: const EdgeInsets.all(12),
                child: _selectedCell == null
                    ? _buildAddCellPanel()
                    : _buildCellProperties(structure, _selectedCell!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionControl(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: () => onChanged(max(1, value - 1)),
        ),
        SizedBox(
          width: 40,
          child: TextField(
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(isDense: true),
            controller: TextEditingController(text: value.toString()),
            onSubmitted: (text) {
              final v = int.tryParse(text);
              if (v != null && v > 0) onChanged(v);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }

  Widget _buildAddCellPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('添加单元格', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addXController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'X', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _addYController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Y', isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _addCellFromPanel,
          child: const Text('添加'),
        ),
        const SizedBox(height: 16),
        const Text('提示：点击画布空白格子也可快速添加'),
      ],
    );
  }

  Widget _buildCellProperties(Structure structure, Position position) {
    final (isStair, isUp) = getStairInfo(structure, position);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('单元格 (${position.x}, ${position.y})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除此单元格',
              onPressed: _deleteSelectedCell,
            ),
          ],
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('楼梯'),
          value: isStair,
          onChanged: (value) => setState(() => setCellStair(structure, position, value, isUp)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (isStair)
          SwitchListTile(
            title: const Text('楼梯向上'),
            value: isUp,
            onChanged: (value) => setState(() => setCellStair(structure, position, true, value)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        const SizedBox(height: 8),
        const Text('边类型', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final direction in Direction.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 50, child: Text(_directionName(direction))),
                Expanded(
                  child: DropdownButton<EdgeType>(
                    value: getEdgeTypeFor(structure, position, direction),
                    items: EdgeType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_edgeTypeName(type)),
                      );
                    }).toList(),
                    onChanged: (type) {
                      if (type != null) {
                        setState(() => setCellEdge(structure, position, direction, type));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _directionName(Direction direction) {
    switch (direction) {
      case Direction.north: return '北(上)';
      case Direction.south: return '南(下)';
      case Direction.east: return '东(右)';
      case Direction.west: return '西(左)';
    }
  }

  String _edgeTypeName(EdgeType type) {
    switch (type) {
      case EdgeType.nothing: return '无';
      case EdgeType.door: return '门';
      case EdgeType.innerWall: return '内墙';
      case EdgeType.hole: return '洞';
    }
  }

  void _handleCanvasTap(Offset localPosition, Size size, int canvasWidth, int canvasHeight) {
    if (size.width == 0 || size.height == 0) return;
    final cellW = size.width / canvasWidth;
    final cellH = size.height / canvasHeight;
    final gx = (localPosition.dx / cellW).floor();
    final gy = (canvasHeight - 1 - (localPosition.dy / cellH).floor());

    if (gx < 0 || gx >= canvasWidth || gy < 0 || gy >= canvasHeight) return;

    final pos = Position(x: gx, y: gy);
    setState(() {
      if (_selectedCell == pos) {
        _selectedCell = null;
      } else {
        if (!_currentStructure!.cells.contains(pos)) {
          _currentStructure!.cells.add(pos);
        }
        _selectedCell = pos;
      }
    });
  }

  void _addCellFromPanel() {
    final x = int.tryParse(_addXController.text.trim());
    final y = int.tryParse(_addYController.text.trim());
    if (x == null || y == null || _currentStructure == null) return;

    final pos = Position(x: x, y: y);
    setState(() {
      _currentStructure!.cells.add(pos);
      _selectedCell = pos;
      _addXController.clear();
      _addYController.clear();
    });
  }

  void _addStructure() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('新建结构'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '结构名称'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty && !_structures.containsKey(name)) {
                  final newStructure = Structure(
                    isCorridor: false,
                    cells: HashSet<Position>(),
                    doors: HashSet<Door>(),
                    innerWalls: HashSet<Door>(),
                    stairs: HashSet<Stair>(),
                    holes: HashSet<Hole>(),
                  );
                  setState(() {
                    _structures[name] = newStructure;
                    _canvasWidths[name] = defaultCanvasWidth;
                    _canvasHeights[name] = defaultCanvasHeight;
                    _selectedName = name;
                    _currentStructure = newStructure;
                    _selectedCell = null;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  void _deleteStructure() {
    if (_selectedName == null) return;
    setState(() {
      _structures.remove(_selectedName);
      _canvasWidths.remove(_selectedName);
      _canvasHeights.remove(_selectedName);
      _selectedName = _structures.isNotEmpty ? _structures.keys.first : null;
      _currentStructure = _selectedName != null ? _structures[_selectedName] : null;
      _selectedCell = null;
    });
  }

  void _renameStructure(String oldName, String newName) {
    if (newName.isEmpty || newName == oldName || _structures.containsKey(newName)) return;
    setState(() {
      final structure = _structures.remove(oldName)!;
      _structures[newName] = structure;
      final width = _canvasWidths.remove(oldName) ?? defaultCanvasWidth;
      final height = _canvasHeights.remove(oldName) ?? defaultCanvasHeight;
      _canvasWidths[newName] = width;
      _canvasHeights[newName] = height;
      if (_selectedName == oldName) {
        _selectedName = newName;
        _currentStructure = structure;
      }
    });
  }

  void _setCanvasWidth(String name, int width) => setState(() => _canvasWidths[name] = width);
  void _setCanvasHeight(String name, int height) => setState(() => _canvasHeights[name] = height);

  void _deleteSelectedCell() {
    if (_selectedCell == null || _currentStructure == null) return;
    final pos = _selectedCell!;
    setState(() {
      removeCellData(_currentStructure!, pos);
      _selectedCell = null;
    });
  }
}