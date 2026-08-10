import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide Layer;
import 'dart:convert';
import 'package:idv_map_guides/maps/structure.dart';
import 'package:idv_map_guides/maps/world.dart';
import 'package:idv_map_guides/maps/painter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '地图编辑器',
      theme: ThemeData.dark(),
      home: const EditorPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------- 编辑器页面 ----------
class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _jsonController = TextEditingController();
  MapModel? _map;
  List<String> _errors = [];
  Layer _currentLayer = Layer.lower; // 默认下层

  void _generate() {
    try {
      final map = parseJson(_jsonController.text);
      setState(() {
        _map = map;
        _errors = map.errors;
      });
    } catch (e) {
      setState(() {
        _map = null;
        _errors = ['解析失败: $e'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图编辑器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '结构预览帮助',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpPage()),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _jsonController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '在此粘贴 JSON 数据...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('生成地图'),
                  ),
                  if (_errors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.red.shade900,
                      child: Text(
                        _errors.join('\n'),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Text('当前层级：'),
                      const SizedBox(width: 8),
                      SegmentedButton<Layer>(
                        segments: const [
                          ButtonSegment(value: Layer.upper, label: Text('上层')),
                          ButtonSegment(value: Layer.lower, label: Text('下层')),
                        ],
                        selected: {_currentLayer},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _currentLayer = selection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _map == null
                      ? const Center(child: Text('左侧输入 JSON 并点击生成'))
                      : LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        painter: MapPainter(_map!, _currentLayer),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      );
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

// ---------- 帮助页面 ----------
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  static final List<({String type, StructureDef def})> structureList = [
    (type: 'stair_2x2', def: Stair2x2Def()),
    (type: 'stair_3x3_t', def: Stair3x3TDef()),
    (type: 'stair_3x3_o', def: Stair3x3ODef()),
    (type: 'y_corridor', def: YCorridorDef()),
    (type: 'center_corridor', def: CenterCorridorDef()),
    (type: 'main_entrance', def: MainEntranceDef()),
    (type: 'muse_room', def: MuseRoomDef()),
    (type: 'bed_room', def: BedRoomDef()),
    (type: 'five_bed_room', def: FiveBedRoomDef()),
    (type: 'meeting_room', def: MeetingRoomDef()),
    (type: 'restaurant_room', def: RestaurantRoomDef()),
    (type: 'corner_room_a', def: CornerRoomADef()),
    (type: 'corner_room_b', def: CornerRoomBDef()),
    (type: 'center_room', def: CenterRoomDef()),
    (type: 'safe_room', def: SafeRoomDef()),
    (type: 'stair_room', def: StairRoomDef()),
    (type: 't_room', def: TRoomDef()),
    (type: 'lantern_room', def: LanternRoomDef()),
  ];

  String? _selectedType;
  StructureDef? _selectedDef;
  Layer _previewLayer = Layer.lower; // 默认下层
  MapModel? _previewMap;

  (int, int) _calculateOrigin(StructureDef def) {
    const gridSize = 10;
    int ox = ((gridSize - def.boundCols) / 2).floor();
    int oy = ((gridSize - def.boundRows) / 2).floor();
    return (ox.clamp(0, gridSize), oy.clamp(0, gridSize));
  }

  MapModel _buildPreviewMap(StructureDef def) {
    final map = MapModel(10, 10);
    final (ox, oy) = _calculateOrigin(def);
    // 单层结构强制放在下层，上层为空
    final Layer? singleLayer = def.isDouble ? null : Layer.lower;
    final ps = PlacedStructure(
      1,
      def,
      ox,
      oy,
      rotation: 0,
      singleLayer: singleLayer,
    );
    map.placeStructure(ps);
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('结构预览帮助')),
      body: Row(
        children: [
          SizedBox(
            width: 200,
            child: ListView.builder(
              itemCount: structureList.length,
              itemBuilder: (context, index) {
                final item = structureList[index];
                final selected = _selectedType == item.type;
                return ListTile(
                  selected: selected,
                  selectedTileColor: Colors.blue.shade700,
                  title: Text(item.type, style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    setState(() {
                      _selectedType = item.type;
                      _selectedDef = item.def;
                      _previewMap = _buildPreviewMap(item.def);
                      _previewLayer = Layer.lower; // 切换结构时重置为下层
                    });
                  },
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selectedDef == null
                ? const Center(child: Text('请从左侧选择结构'))
                : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Text('预览层级：'),
                      const SizedBox(width: 8),
                      SegmentedButton<Layer>(
                        segments: const [
                          ButtonSegment(value: Layer.upper, label: Text('上层')),
                          ButtonSegment(value: Layer.lower, label: Text('下层')),
                        ],
                        selected: {_previewLayer},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _previewLayer = selection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        painter: MapPainter(_previewMap!, _previewLayer),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      );
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