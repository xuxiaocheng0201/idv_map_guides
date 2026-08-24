import 'dart:math';

import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/painter/editor_structure_painter.dart';

EdgeType getEdgeType(Structure structure, Position position, Direction direction) {
  if (structure.doors.any((d) => d.position == position && d.direction == direction)) return EdgeType.door;
  if (structure.innerWalls.any((d) => d.position == position && d.direction == direction)) return EdgeType.innerWall;
  if (structure.holes.any((d) => d.position == position && d.direction == direction)) return EdgeType.hole;
  return EdgeType.nothing;
}

void setEdgeType(Structure structure, Position position, Direction direction, EdgeType type) {
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

StairTransport? getStairInfo(Structure structure, Position position) {
  for (final stair in structure.stairs) {
    if (stair.position == position) {
      return stair.stairTransport;
    }
  }
  return null;
}

void setStairInfo(Structure structure, Position position, StairTransport? isStair) {
  structure.stairs.removeWhere((s) => s.position == position);
  if (isStair != null) {
    structure.stairs.add(Stair(position: position, stairTransport: isStair));
  }
}

void removeCell(Structure structure, Position position) {
  structure.cells.remove(position);
  structure.stairs.removeWhere((s) => s.position == position);
  structure.doors.removeWhere((d) => d.position == position);
  structure.innerWalls.removeWhere((d) => d.position == position);
  structure.holes.removeWhere((d) => d.position == position);
}

Future<List<(String, Structure)>> readStructures(String path) async {
  final map = await loadStructures(path);
  final structures = map.entries.map((e) => (e.key, e.value)).toList();
  structures.sort((a, b) => a.$1.compareTo(b.$1));
  return structures;
}

Future<String> writeStructures(List<(String, Structure)> structures, String path) async {
  final map = Map.fromEntries(structures.map((entry) => MapEntry(entry.$1, entry.$2)));
  return await saveStructures(map, path);
}

class StructuresEditorPage extends StatefulWidget {
  final String savePath;

  const StructuresEditorPage({super.key, String? savePath}): savePath = savePath ?? "structures.json";

  @override
  State<StructuresEditorPage> createState() => _StructuresEditorPageState();
}

class _StructuresEditorPageState extends State<StructuresEditorPage> {
  late List<(String, Structure)> _structures;
  int? _selectedIndex;
  String? _currentName;
  Structure? _currentStructure;

  final Map<String, int> _canvasWidths = {};
  final Map<String, int> _canvasHeights = {};
  static const int defaultCanvasWidth = 5;
  static const int defaultCanvasHeight = 5;

  Position? _selectedCell;

  @override
  void initState() {
    super.initState();
    _structures = [];
    readStructures(widget.savePath).then((value) {
      setState(() {
        _structures = value;
        for (var entry in _structures) {
          final (name, structure) = entry;
          _canvasWidths[name] = structure.cells.isEmpty ? defaultCanvasWidth : structure.cells.map((p) => p.x).reduce((a, b) => max(a, b)) + 1;
          _canvasHeights[name] = structure.cells.isEmpty ? defaultCanvasHeight : structure.cells.map((p) => p.y).reduce((a, b) => max(a, b)) + 1;
        }
        if (_structures.isNotEmpty) {
          _selectedIndex = 0;
          _currentName = _structures[_selectedIndex!].$1;
          _currentStructure = _structures[_selectedIndex!].$2;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('结构编辑器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: () => writeStructures(_structures, widget.savePath).then((path) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: SelectableText('保存成功 $path'),
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
                        onPressed: _selectedIndex == null ? null : _deleteStructure,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _structures.length,
                    itemBuilder: (context, index) {
                      final (name, structure) = _structures[index];
                      final width = _canvasWidths[name] ?? defaultCanvasWidth;
                      final height = _canvasHeights[name] ?? defaultCanvasHeight;
                      return ListTile(
                        selected: index == _selectedIndex,
                        title: Text(name),
                        subtitle: Text('宽$width x 高$height | ${structure.isCorridor ? '走廊' : '房间'}'),
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                            _currentName = name;
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
    final name = _currentName!;
    final structure = _currentStructure!;
    final canvasWidth = _canvasWidths[name]!;
    final canvasHeight = _canvasHeights[name]!;
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
                  onSubmitted: (newName) {
                    if (!_renameStructure(newName)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('重命名失败'),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              _buildDimensionControl('宽', canvasWidth, _setCanvasWidth),
              const SizedBox(width: 8),
              _buildDimensionControl('高', canvasHeight, _setCanvasHeight),
              const SizedBox(width: 16),
              const Text('走廊'),
              const SizedBox(width: 8),
              Switch(
                value: structure.isCorridor,
                onChanged: (value) => setState(() => structure.isCorridor = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
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
                              painter: EditorStructurePainter(
                                structure: structure,
                                width: canvasWidth,
                                height: canvasHeight,
                                selectedCell: _selectedCell,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(
                width: 220,
                padding: const EdgeInsets.all(12),
                child: _selectedCell == null
                    ? Center(
                        child: Text('点击画布空白格子添加单元格'),
                      )
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

  Widget _buildCellProperties(Structure structure, Position position) {
    final isStair = getStairInfo(structure, position);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              onPressed: _deleteSelectedCell,
            ),
          ],
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('楼梯'),
          value: isStair != null,
          onChanged: (value) => setState(() => setStairInfo(structure, position, value ? StairTransport.nothing : null)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (isStair != null)
          Row(
            children: [
              SizedBox(width: 50, child: Text('楼梯朝向')),
              Expanded(
                child: DropdownButton<StairTransport>(
                  value: isStair,
                  items: StairTransport.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_stairTransportName(type)),
                    );
                  }).toList(),
                  onChanged: (type) {
                    if (type != null) {
                      setState(() => setStairInfo(structure, position, type));
                    }
                  },
                ),
              ),
            ],
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
                    value: getEdgeType(structure, position, direction),
                    items: EdgeType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_edgeTypeName(type)),
                      );
                    }).toList(),
                    onChanged: (type) {
                      if (type != null) {
                        setState(() => setEdgeType(structure, position, direction, type));
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

  String _stairTransportName(StairTransport type) {
    switch (type) {
      case StairTransport.nothing: return '无';
      case StairTransport.goUp: return '上';
      case StairTransport.goDown: return '下';
    }
  }

  void _handleCanvasTap(Offset localPosition, Size size, int canvasWidth, int canvasHeight) {
    if (size.width == 0 || size.height == 0) return;
    final cellW = size.width / canvasWidth;
    final cellH = size.height / canvasHeight;
    final gx = (localPosition.dx / cellW).floor();
    final gy = canvasHeight - (localPosition.dy / cellH).floor() - 1;

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
                if (name.isNotEmpty && !_structures.any((entry) => entry.$1 == name)) {
                  final newStructure = Structure(
                    isCorridor: false,
                    cells: {},
                    doors: {},
                    innerWalls: {},
                    stairs: {},
                    holes: {},
                  );
                  setState(() {
                    _structures.add((name, newStructure));
                    _structures.sort((a, b) => a.$1.compareTo(b.$1));
                    _selectedIndex = _structures.indexWhere((entry) => entry.$1 == name);
                    _canvasWidths[name] = defaultCanvasWidth;
                    _canvasHeights[name] = defaultCanvasHeight;
                    _currentName = name;
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
    final index = _selectedIndex;
    if (index == null) return;
    final name = _structures[index].$1;
    setState(() {
      _structures.removeAt(index);
      _canvasWidths.remove(name);
      _canvasHeights.remove(name);
      _selectedIndex = null;
      _currentStructure = null;
      _selectedCell = null;
    });
  }

  bool _renameStructure(String newName) {
    final index = _selectedIndex;
    if (index == null) return true;
    final (oldName, structure) = _structures[index];
    if (newName.isEmpty || newName == oldName || _structures.any((entry) => entry.$1 == newName)) return false;
    setState(() {
      _structures[index] = (newName, structure);
      _structures.sort((a, b) => a.$1.compareTo(b.$1));
      _selectedIndex = _structures.indexWhere((entry) => entry.$1 == newName);
      final width = _canvasWidths.remove(oldName)!;
      final height = _canvasHeights.remove(oldName)!;
      _canvasWidths[newName] = width;
      _canvasHeights[newName] = height;
      _currentName = newName;
    });
    return true;
  }

  void _setCanvasWidth(int width) => setState(() => _canvasWidths[_currentName!] = width);
  void _setCanvasHeight(int height) => setState(() => _canvasHeights[_currentName!] = height);

  void _deleteSelectedCell() {
    if (_selectedCell == null || _currentStructure == null) return;
    final pos = _selectedCell!;
    setState(() {
      removeCell(_currentStructure!, pos);
      _selectedCell = null;
    });
  }
}