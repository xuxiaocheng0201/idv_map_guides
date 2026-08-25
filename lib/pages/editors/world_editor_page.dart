import 'dart:io';
import 'dart:math';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/errors.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/pages/editors/structures_editor_page.dart';
import 'package:idv_map_guides/painter/editor_structure_painter.dart';
import 'package:idv_map_guides/painter/editor_world_painter.dart';
import 'package:toastification/toastification.dart';

const int defaultWorldMinX = -25;
const int defaultWorldMaxX = 25;
const int defaultWorldMinY = 0;
const int defaultWorldMaxY = 50;

const defaultWorldSavePath = 'world.json';

class _WorldEditorRegistry {
  Map<String, Structure> structures = {};
  final String structuresPath;
  final File file;
  WorldFile worldFile = WorldFile(
    layers: <GroundLayer>{GroundLayer.ground},
    minX: defaultWorldMinX,
    maxX: defaultWorldMaxX,
    minY: defaultWorldMinY,
    maxY: defaultWorldMaxY,
    instances: <StructureInstance>[],
    entrances: <GroundLayer, Set<Position>>{},
  );
  World world = World(
    layers: <GroundLayer>{GroundLayer.ground},
    minX: defaultWorldMinX,
    maxX: defaultWorldMaxX,
    minY: defaultWorldMinY,
    maxY: defaultWorldMaxY,
  );
  WorldErrors globalErrors = WorldErrors(errors: <WorldError>[]);
  Map<int, WorldErrors> errorsByInstanceIndex = {};
  Map<int, int> instanceIndexToStructureId = {};

  _WorldEditorRegistry({required this.structuresPath, required String path}): file = File(path).absolute;

  String get path => file.path;

  Future<void> read(void Function(void Function()) setState) async {
    final structuresFile = File(structuresPath);
    if (await structuresFile.exists()) {
      final bytes = await structuresFile.readAsBytes();
      structures = deserializeStructures(bytes);
    }
    if (!await file.exists()) {
      return;
    }
    final bytes = await file.readAsBytes();
    final worldFile = deserializeWorld(bytes);
    setState(() {
      this.worldFile = worldFile;
    });
  }

  Future<void> write() async {
    final content = serializeWorld(worldFile);
    await file.writeAsBytes(content);
  }

  void buildWorld(void Function(void Function()) setState) {
    final world = World(
      layers: worldFile.layers,
      minX: worldFile.minX,
      maxX: worldFile.maxX,
      minY: worldFile.minY,
      maxY: worldFile.maxY,
    );
    final globalErrors = WorldErrors(errors: <WorldError>[]);
    final errorsByInstanceIndex = <int, WorldErrors>{};
    final instanceIndexToStructureId = <int, int>{};
    if (worldFile.instances.isEmpty) {
      globalErrors.push(WorldError.emptyMap());
    }
    for (var i = 0; i < worldFile.instances.length; i++) {
      final instance = worldFile.instances[i];
      try {
        final structure = resolveStructure(instance, structures);
        final structureId = world.placeStructure(instance.layer, structure, instance.originX, instance.originY, instance.rotation);
        instanceIndexToStructureId[i] = structureId;
      } on WorldErrors catch (e) {
        errorsByInstanceIndex[i] = e;
      } on WorldError catch (e) {
        errorsByInstanceIndex[i] = WorldErrors(errors: [e]);
      }
    }
    for (final (layer, entrance) in worldFile.entrances.entries.expand((entry) => entry.value.map((p) => (entry.key, p)))) {
      try {
        world.addEntrance(layer, entrance);
      } on WorldError catch (e) {
        globalErrors.push(e);
      }
    }
    try {
      world.validate();
    } on WorldErrors catch (e) {
      globalErrors.merge(e);
    }
    setState(() {
      this.world = world;
      this.globalErrors = globalErrors;
      this.errorsByInstanceIndex = errorsByInstanceIndex;
      this.instanceIndexToStructureId = instanceIndexToStructureId;
    });
  }

  bool get hasErrors => !globalErrors.isEmpty || errorsByInstanceIndex.isNotEmpty;

  int addInstance(void Function(void Function()) setState) {
    final index = worldFile.instances.length;
    final instance = StructureInstance(
      typeName: corridorTypeName,
      layer: GroundLayer.ground,
      originX: 0,
      originY: 0,
    );
    setState(() => worldFile.instances.add(instance));
    return index;
  }

  void removeInstance(int index, void Function(void Function()) setState) {
    setState(() => worldFile.instances.removeAt(index));
  }
}

class WorldEditorPage extends StatefulWidget {
  final String structuresPath;
  final String worldPath;

  const WorldEditorPage({super.key, String? structuresPath, String? worldPath}):
        structuresPath = structuresPath ?? defaultStructuresSavePath,
        worldPath = worldPath ?? defaultWorldSavePath;

  @override
  State<WorldEditorPage> createState() => _WorldEditorPageState();
}

class _WorldEditorPageState extends State<WorldEditorPage> {
  late _WorldEditorRegistry _registry;
  GroundLayer _currentLayer = GroundLayer.ground;
  int? _selectedInstanceIndex;

  @override
  void initState() {
    super.initState();
    _registry = _WorldEditorRegistry(structuresPath: widget.structuresPath, path: widget.worldPath);
    Future(() async {
      await _registry.read(setState);
      _registry.buildWorld(setState);
    });
    _currentLayer = GroundLayer.ground;
    _selectedInstanceIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图编辑器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: () async {
              await _registry.write();
              toastification.show(
                autoCloseDuration: const Duration(seconds: 3),
                showProgressBar: true,
                title: Row(
                  children: [
                    Text('保存成功'),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: '复制保存路径',
                      onPressed: () async {
                        await FlutterClipboard.copy(_registry.path);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        backgroundColor: Theme.of(context).splashColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('添加'),
                        onPressed: _addInstance,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: '删除当前结构',
                        onPressed: _selectedInstanceIndex == null ? null : _removeInstance,
                      ),
                      const SizedBox(width: 8),
                      if (_registry.hasErrors)
                        IconButton(
                          icon: Icon(
                            Icons.error,
                            color: Colors.red,
                          ),
                          tooltip: '点击查看地图错误',
                          onPressed: _showErrorsDialog,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _registry.worldFile.instances.length,
                    itemBuilder: (context, index) {
                      final instance = _registry.worldFile.instances[index];
                      final hasError = _registry.errorsByInstanceIndex.containsKey(index);
                      return ListTile(
                        selected: index == _selectedInstanceIndex,
                        title: Text(
                          '#${index + 1} ${instance.typeName}',
                          style: TextStyle(color: hasError ? Colors.red : null),
                        ),
                        subtitle: Text(
                          '图层: ${instance.layer.label(context)}  位置: (${instance.originX}, ${instance.originY})',
                        ),
                        onTap: () => setState(() {
                          _selectedInstanceIndex = index;
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: _buildWorldViewer(context),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildInstanceProperties(context),
            ),
          ),
        ],
      ),
    );
  }

  void _addInstance() {
    final structureId = _registry.addInstance(setState);
    _registry.buildWorld(setState);
    setState(() => _selectedInstanceIndex = structureId);
  }

  void _removeInstance() {
    final index = _selectedInstanceIndex;
    if (index == null) return;
    _registry.removeInstance(index, setState);
    _registry.buildWorld(setState);
    setState(() => _selectedInstanceIndex = null);
  }

  void _showErrorsDialog() {
    final allErrors = <String>[];
    _registry.errorsByInstanceIndex.forEach((index, errors) {
      final instance = _registry.worldFile.instances[index];
      allErrors.add('结构 #${index + 1} ${instance.typeName}:');
      for (final e in errors.errors) {
        allErrors.add('  - $e');
      }
    });
    if (!_registry.globalErrors.isEmpty) {
      allErrors.add('跨结构验证');
      for (final e in _registry.globalErrors.errors) {
        allErrors.add('  - $e');
      }
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('地图错误'),
        content: SizedBox(
          width: MediaQuery.widthOf(context) * 0.5,
          height: MediaQuery.heightOf(context) * 0.5,
          child: ListView(
            children: allErrors.map((e) => Text(e)).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _buildWorldViewer(BuildContext context) {
    final currentLayerInWorld = _registry.worldFile.layers.contains(_currentLayer);
    return Column(
      children: [
        Row(
          children: [
            currentLayerInWorld ? IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () {
                setState(() => _registry.worldFile.layers.remove(_currentLayer));
                _registry.buildWorld(setState);
              },
            ) : IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() => _registry.worldFile.layers.add(_currentLayer));
                _registry.buildWorld(setState);
              },
            ),
            for (final layer in GroundLayer.values)
              Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(
                  label: Text(layer.label(context)),
                  selected: _currentLayer == layer,
                  onSelected: (selected) => setState(() => _currentLayer = layer),
                  backgroundColor: _registry.worldFile.layers.contains(layer) ? null : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            const SizedBox(width: 16),
            Text('X'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _registry.worldFile.minX -= 1);
                    _registry.buildWorld(setState);
                  },
                ),
                Text('${_registry.worldFile.minX}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _registry.worldFile.minX += 1);
                    _registry.buildWorld(setState);
                  },
                ),
              ],
            ),
            Text('～'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _registry.worldFile.maxX -= 1);
                    _registry.buildWorld(setState);
                  },
                ),
                Text('${_registry.worldFile.maxX}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _registry.worldFile.maxX += 1);
                    _registry.buildWorld(setState);
                  },
                ),
              ],
            ),
            const SizedBox(width: 16),
            Text('Y'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _registry.worldFile.minY -= 1);
                    _registry.buildWorld(setState);
                  },
                ),
                Text('${_registry.worldFile.minY}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _registry.worldFile.minY += 1);
                    _registry.buildWorld(setState);
                  },
                ),
              ],
            ),
            Text('～'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _registry.worldFile.maxY -= 1);
                    _registry.buildWorld(setState);
                  },
                ),
                Text('${_registry.worldFile.maxY}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _registry.worldFile.maxY += 1);
                    _registry.buildWorld(setState);
                  },
                ),
              ],
            ),
          ],
        ),
        Expanded(
          child: currentLayerInWorld ? Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellSize = min(constraints.maxWidth / _registry.world.width, constraints.maxHeight / _registry.world.height);
                final paintSize = Size(_registry.world.width * cellSize, _registry.world.height * cellSize);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleWorldTap(details.localPosition, paintSize, cellSize),
                  child: CustomPaint(
                    size: paintSize,
                    painter: EditorWorldPainter(
                      world: _registry.world,
                      layer: _currentLayer,
                      selectedStructure: _selectedInstanceIndex == null ? null : _registry.instanceIndexToStructureId[_selectedInstanceIndex!],
                    ),
                  ),
                );
              },
            ),
          ) : Center(
            child: const Text('当前层级不在地图中，请点击左上角添加'),
          ),
        ),
      ],
    );
  }

  void _handleWorldTap(Offset localPosition, Size paintSize, double cellSize) {
    if (paintSize.width == 0 || paintSize.height == 0) return;
    final world = _registry.world;
    final x = (localPosition.dx / cellSize).floor() + world.minX;
    final y = world.maxY - (localPosition.dy / cellSize).floor();
    final cell = world.cell(_currentLayer, x, y);
    if (cell == null || cell.id == null) {
      setState(() => _selectedInstanceIndex = null);
      return;
    }
    int? instanceIndex;
    for (final entry in _registry.instanceIndexToStructureId.entries) {
      final (index, id) = (entry.key, entry.value);
      if (id == cell.id) {
        instanceIndex = index;
        break;
      }
    }
    if (instanceIndex != null) {
      setState(() => _selectedInstanceIndex = instanceIndex);
    }
  }

  Widget _buildInstanceProperties(BuildContext context) {
    final index = _selectedInstanceIndex;
    if (index == null) {
      return const Center(
        child: Text('请选择一个结构实例'),
      );
    }
    final instance = _registry.worldFile.instances[index];
    return Column(
      children: [
        Row(
          children: [
            Text(
              '结构实例 #${index + 1} ${instance.typeName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除此结构实例',
              onPressed: () {
                _registry.removeInstance(index, setState);
                _registry.buildWorld(setState);
                setState(() => _selectedInstanceIndex = null);
              },
            ),
          ],
        ),
        const Divider(),
        DropdownButtonFormField<String>(
          initialValue: instance.typeName,
          decoration: const InputDecoration(labelText: '结构类型'),
          items: _registry.structures.keys
              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
              .toList()
            ..add(const DropdownMenuItem(value: corridorTypeName, child: Text(corridorTypeName))),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                instance.typeName = value;
                if (value != corridorTypeName) {
                  instance.cells = null;
                } else {
                  instance.cells ??= <Position, CellInfo>{};
                }
              });
              _registry.buildWorld(setState);
            }
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<GroundLayer>(
          initialValue: instance.layer,
          decoration: const InputDecoration(labelText: '所属层级'),
          items: GroundLayer.values
              .map((layer) => DropdownMenuItem(value: layer, child: Text(layer.label(context))))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => instance.layer = value);
              _registry.buildWorld(setState);
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('原点 X'),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.remove),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() => instance.originX -= 1);
                _registry.buildWorld(setState);
              },
            ),
            Text('${instance.originX}'),
            IconButton(
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() => instance.originX += 1);
                _registry.buildWorld(setState);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('原点 Y'),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.remove),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() => instance.originY -= 1);
                _registry.buildWorld(setState);
              },
            ),
            Text('${instance.originY}'),
            IconButton(
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() => instance.originY += 1);
                _registry.buildWorld(setState);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Rotation>(
          initialValue: instance.rotation,
          decoration: const InputDecoration(labelText: '旋转'),
          items: Rotation.values
              .map((rotation) => DropdownMenuItem(value: rotation, child: Text(rotation.label(context))))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => instance.rotation = value);
              _registry.buildWorld(setState);
            }
          },
        ),
        const SizedBox(height: 16),
        if (instance.typeName == corridorTypeName) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('打开走廊编辑器'),
            onPressed: () => _openCorridorCellsEditor(instance),
          ),
          const SizedBox(height: 16),
        ],
        if (_registry.errorsByInstanceIndex.containsKey(index)) ...[
          const Divider(),
          const Text('该实例存在错误：', style: TextStyle(color: Colors.red)),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _registry.errorsByInstanceIndex[index]!.errors.map((e) => Text('• $e')).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openCorridorCellsEditor(StructureInstance instance) async {
    final cells = instance.cells ?? <Position, CellInfo>{};
    final result = await showDialog<Map<Position, CellInfo>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CorridorCellsEditorDialog(cells: cells),
    );
    if (result != null) {
      setState(() {
        instance.cells = result;
        _registry.buildWorld(setState);
      });
    }
  }
}

class _CorridorCellsEditorDialog extends StatefulWidget {
  final Map<Position, CellInfo> cells;

  const _CorridorCellsEditorDialog({required this.cells});

  @override
  State<_CorridorCellsEditorDialog> createState() => _CorridorCellsEditorDialogState();
}

class _CorridorCellsEditorDialogState extends State<_CorridorCellsEditorDialog> {
  late Map<Position, CellInfo> _cells;
  int _width = defaultCanvasWidth;
  int _height = defaultCanvasHeight;
  Position? _selectedCell;

  @override
  void initState() {
    super.initState();
    _cells = Map.from(widget.cells);
    if (_cells.isNotEmpty) {
      _width = _cells.keys.map((p) => p.x).reduce(max) + 1;
      _height = _cells.keys.map((p) => p.y).reduce(max) + 1;
    }
    _selectedCell = null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑走廊单元格'),
      content: SizedBox(
        width: MediaQuery.widthOf(context) * 0.7,
        height: MediaQuery.heightOf(context) * 0.6,
        child: Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellSize = min(constraints.maxWidth / _width, constraints.maxHeight / _height);
                  final paintSize = Size(_width * cellSize, _height * cellSize);
                  return GestureDetector(
                    onTapUp: (details) {
                      final x = (details.localPosition.dx / cellSize).floor();
                      final y = _height - (details.localPosition.dy / cellSize).floor() - 1;
                      if (x < 0 || _width <= x || y < 0 || _height <= y) return;
                      final pos = Position(x: x, y: y);
                      setState(() {
                        if (_selectedCell == pos) {
                          _selectedCell = null;
                        } else {
                          _selectedCell = pos;
                          _cells.putIfAbsent(pos, () => const CellInfo());
                        }
                      });
                    },
                    child: CustomPaint(
                      size: paintSize,
                      painter: EditorStructurePainter(
                        structure: Structure(isCorridor: true, cells: _cells),
                        width: _width,
                        height: _height,
                        selectedCell: _selectedCell,
                      ),
                    ),
                  );
                },
              ),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 240,
              child: _buildCellProperties(),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('画布大小:'),
            const SizedBox(width: 8),
            const Text('宽'),
            IconButton(
              icon: const Icon(Icons.remove),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _width = max(1, _width - 1)),
            ),
            Text('$_width'),
            IconButton(
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _width++),
            ),
            const SizedBox(width: 8),
            const Text('高'),
            IconButton(
              icon: const Icon(Icons.remove),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _height = max(1, _height - 1)),
            ),
            Text('$_height'),
            IconButton(
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _height++),
            ),
          ],
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _cells),
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildCellProperties() {
    final position = _selectedCell;
    if (position == null) {
      return const Center(
        child: Text('点击画布空白格子添加单元格'),
      );
    }
    final cell = _cells[position]!;
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
                onPressed: () => setState(() {
                  _cells.remove(position);
                  _selectedCell = null;
                }),
              ),
            ],
          ),
          const Divider(),
          const Text('边类型', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final direction in Direction.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(direction.label(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<EdgeType>(
                      value: cell.getEdgeType(direction),
                      items: EdgeType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.label(context)),
                        );
                      }).toList(),
                      onChanged: (type) {
                        if (type != null) setState(() => _cells[position] = cell.setEdgeType(direction, type));
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
