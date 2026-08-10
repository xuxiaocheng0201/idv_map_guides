import 'package:flutter/material.dart';
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

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _jsonController = TextEditingController();
  MapModel? _map;
  List<String> _errors = [];
  Layer _currentLayer = Layer.upper;

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
      ),
      body: Row(
        children: [
          // 左侧：JSON 输入区
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
          // 右侧：地图预览区
          Expanded(
            child: Column(
              children: [
                // 层级切换栏
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Text('当前层级：'),
                      const SizedBox(width: 8),
                      SegmentedButton<Layer>(
                        segments: const [
                          ButtonSegment(value: Layer.lower, label: Text('下层')),
                          ButtonSegment(value: Layer.upper, label: Text('上层')),
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
                // 画布区域
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