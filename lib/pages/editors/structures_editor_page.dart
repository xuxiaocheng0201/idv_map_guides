import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/serde.dart';
import 'package:idv_map_guides/pages/editors/value_editor.dart';
import 'package:idv_map_guides/painter/editor_structure_painter.dart';
import 'package:path/path.dart' as p;
import 'package:toastification/toastification.dart';

const int defaultCanvasWidth = 5;
const int defaultCanvasHeight = 5;

var dataStructures = serializeStructures(<String, Structure>{});
String? saveDirectory;
String? saveFilename;

class _StructuresRegistry {
  Map<String, Structure> structures = <String, Structure>{};
  Map<String, (int, int)> canvas = <String, (int, int)>{};
  List<String> names = <String>[];

  _StructuresRegistry();

  void read(void Function(void Function()) setState) {
    final structures = deserializeStructures(dataStructures);
    final names = structures.keys.toList();
    names.sort();
    final canvas = structures.map((name, structure) {
      return MapEntry(name, structure.cells.isEmpty ? (defaultCanvasWidth, defaultCanvasHeight) : (
        structure.cells.keys.map((p) => p.x).reduce(max) + 1,
        structure.cells.keys.map((p) => p.y).reduce(max) + 1,
      ));
    });
    setState(() {
      this.structures = structures;
      this.names = names;
      this.canvas = canvas;
    });
  }

  void write() {
    final content = serializeStructures(structures);
    dataStructures = content;
  }

  int? addStructure(String name, void Function(void Function()) setState) {
    if (structures.containsKey(name)) return null;
    final newNames = names.toList();
    newNames.add(name);
    newNames.sort();
    final index = newNames.indexOf(name);
    final structure = Structure(
      name: name,
      isCorridor: false,
      isNoDirection: false,
      cells: <Position, CellInfo>{},
    );
    setState(() {
      names = newNames;
      structures[name] = structure;
      canvas[name] = (defaultCanvasWidth, defaultCanvasHeight);
    });
    return index;
  }

  int? renameStructure(int index, String newName, void Function(void Function()) setState) {
    if (structures.containsKey(newName)) return null;
    final name = names[index];
    final newNames = names.toList();
    newNames[index] = newName;
    newNames.sort();
    final newIndex = newNames.indexOf(newName);
    setState(() {
      names = newNames;
      final structure = structures.remove(name)!;
      final newStructure = structure.copyWith(name: newName);
      structures[newName] = newStructure;
      final canva = canvas[name]!;
      canvas[newName] = canva;
    });
    return newIndex;
  }

  void removeStructure(int index, void Function(void Function()) setState) {
    setState(() {
      final name = names.removeAt(index);
      structures.remove(name);
      canvas.remove(name);
    });
  }

  void modifyCanvas(int index, (int, int) Function(int, int) modifier, void Function(void Function()) setState) {
    final name = names[index];
    final (width, height) = canvas[name]!;
    final (newWidth, newHeight) = modifier(width, height);
    setState(() => canvas[name] = (newWidth, newHeight));
  }
}

class StructuresEditorPage extends StatefulWidget {
  const StructuresEditorPage({super.key});

  @override
  State<StructuresEditorPage> createState() => _StructuresEditorPageState();
}

class _StructuresEditorPageState extends State<StructuresEditorPage> {
  late _StructuresRegistry _registry;
  int? _selectedIndex;
  Position? _selectedCell;

  @override
  void initState() {
    super.initState();
    _registry = _StructuresRegistry();
    _registry.read(setState);
    _selectedIndex = null;
    _selectedCell = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('结构编辑器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '导入',
            onPressed: () async {
              final file = await FilePicker.pickFile(
                initialDirectory: saveDirectory,
              );
              if (file == null) return;
              final path = file.path;
              if (path == null) {
                saveDirectory = null;
                saveFilename = null;
              } else {
                saveDirectory = p.dirname(path);
                saveFilename = p.basename(path);
              }
              final content = await file.readAsBytes();
              dataStructures = content;
              _registry.read(setState);
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: () => _registry.write(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '导出',
            onPressed: () => FilePicker.saveFile(
              initialDirectory: saveDirectory,
              fileName: saveFilename ?? 'structures.data',
              bytes: dataStructures,
            ),
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
                        label: const Text('新建'),
                        onPressed: () => _addStructure(context),
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
                    itemCount: _registry.names.length,
                    itemBuilder: (context, index) {
                      final name = _registry.names[index];
                      final structure = _registry.structures[name]!;
                      final (width, height) = _registry.canvas[name]!;
                      return ListTile(
                        selected: index == _selectedIndex,
                        title: Text(name),
                        subtitle: Text('宽$width x 高$height | ${structure.isCorridor ? '走廊' : '房间'} | ${structure.isNoDirection ? '无向' : '有向'}'),
                        onTap: () => setState(() {
                          _selectedIndex = index;
                          _selectedCell = null;
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
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildEditor(context),
            ),
          ),
        ],
      ),
    );
  }

  void _addStructure(BuildContext context) {
    showDialog<void>(
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
                final index = _registry.addStructure(name, setState);
                if (index == null) {
                  toastification.show(
                    autoCloseDuration: const Duration(seconds: 3),
                    showProgressBar: true,
                    title: const Text('创建失败，结构名已存在'),
                  );
                } else {
                  Navigator.pop(context);
                  setState(() {
                    _selectedIndex = index;
                    _selectedCell = null;
                  });
                }
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
    _registry.removeStructure(index, setState);
    setState(() {
      _selectedIndex = null;
      _selectedCell = null;
    });
  }

  Widget _buildEditor(BuildContext context) {
    final index = _selectedIndex;
    if (index == null) {
      return const Center(child: Text('请选择或创建一个结构'));
    }
    final name = _registry.names[index];
    final structure = _registry.structures[name]!;
    final (width, height) = _registry.canvas[name]!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: '结构名称',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: name),
                onSubmitted: (newName) => _renameStructure(newName.trim()),
              ),
            ),
            const SizedBox(width: 16),
            ValueEditor(
              label: '宽',
              value: width,
              onSet: (newWidth) => _registry.modifyCanvas(index, (w, h) => (newWidth, h), setState),
            ),
            const SizedBox(width: 8),
            ValueEditor(
              label: '高',
              value: height,
              onSet: (newHeight) => _registry.modifyCanvas(index, (w, h) => (w, newHeight), setState),
            ),
            const SizedBox(width: 16),
            Text(structure.isCorridor ? '走廊' : '房间'),
            const SizedBox(width: 8),
            Switch(
              value: structure.isCorridor,
              onChanged: (value) => setState(() => structure.isCorridor = value),
            ),
            const SizedBox(width: 16),
            Text(structure.isNoDirection ? '无方向' : '有方向'),
            const SizedBox(width: 8),
            Switch(
              value: structure.isNoDirection,
              onChanged: (value) => setState(() => structure.isNoDirection = value),
            ),
          ],
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cellSize = min(constraints.maxWidth / width, constraints.maxHeight / height);
                      final paintSize = Size(width * cellSize, height * cellSize);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _handleCanvasTap(details.localPosition, paintSize, cellSize, width, height, structure),
                        child: CustomPaint(
                          size: paintSize,
                          painter: EditorStructurePainter(
                            structure: structure,
                            width: width,
                            height: height,
                            selectedCell: _selectedCell,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 240,
                child: SingleChildScrollView(
                  child: _buildCellProperties(context, structure),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _renameStructure(String newName) {
    final index = _selectedIndex;
    if (index == null) return;
    final newIndex = _registry.renameStructure(index, newName, setState);
    if (newIndex == null) {
      toastification.show(
        autoCloseDuration: const Duration(seconds: 3),
        showProgressBar: true,
        title: const Text('重命名失败，结构名已存在'),
      );
    } else {
      setState(() {
        _selectedIndex = newIndex;
      });
    }
  }

  void _handleCanvasTap(Offset localPosition, Size paintSize, double cellSize, int width, int height, Structure structure) {
    if (paintSize.width == 0 || paintSize.height == 0) return;
    final x = (localPosition.dx / cellSize).floor();
    final y = height - (localPosition.dy / cellSize).floor() - 1;
    if (x < 0 || width <= x || y < 0 || height <= y) return;
    final position = Position(x: x, y: y);
    setState(() {
      if (_selectedCell == position) {
        _selectedCell = null;
      } else {
        _selectedCell = position;
        structure.cells.putIfAbsent(position, () => const CellInfo());
      }
    });
  }

  Widget _buildCellProperties(BuildContext context, Structure structure) {
    final position = _selectedCell;
    if (position == null) {
      return Center(
        child: Text('点击画布空白格子添加单元格'),
      );
    }
    final cell = structure.cells[position]!;
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
                  structure.cells.remove(position);
                  _selectedCell = null;
                }),
              ),
            ],
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('楼梯', style: TextStyle(fontWeight: FontWeight.bold)),
            value: cell.isStair != null,
            onChanged: (value) => setState(() => structure.cells[position] = cell.copyWith(isStair: value ? StairTransport.nothing : null)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          if (cell.isStair != null)
            Row(
              children: [
                const Text('楼梯朝向'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton(
                    value: cell.isStair,
                    items: StairTransport.values.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.label(context)),
                    )).toList(),
                    onChanged: (type) {
                      if (type != null) setState(() => structure.cells[position] = cell.copyWith(isStair: type));
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('刷箱点', style: TextStyle(fontWeight: FontWeight.bold)),
            value: cell.isResource,
            onChanged: (value) => setState(() => structure.cells[position] = cell.copyWith(isResource: value)),
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
                  Text(direction.label(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton(
                      value: cell.getEdgeType(direction),
                      items: EdgeType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.label(context)),
                        );
                      }).toList(),
                      onChanged: (type) {
                        if (type != null) setState(() => structure.cells[position] = cell.setEdgeType(direction, type));
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
