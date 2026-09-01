import 'package:flutter/material.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/painter/world_painter.dart';

class WorldListPageArguments {
  final WorldsManager<dynamic> manager;
  final List<dynamic> worlds;
  const WorldListPageArguments({required this.manager, required this.worlds});
}

class WorldListPage extends StatefulWidget {
  const WorldListPage({super.key});

  @override
  State<WorldListPage> createState() => _WorldListPageState();
}

class _WorldListPageState extends State<WorldListPage> {
  late WorldsManager<dynamic> manager;
  late List<dynamic> worlds;
  bool _initialized = false;
  dynamic _currentWorld;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final argument = ModalRoute.of(context)?.settings.arguments as WorldListPageArguments?;
    if (argument == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return;
    }
    manager = argument.manager;
    worlds = argument.worlds;
    _currentWorld = worlds.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).worldsShowMap(_currentWorld.label(context) as String)),
        actions: [
          if (worlds.length > 1)
            DropdownButton<dynamic>(
              value: _currentWorld,
              items: worlds
                  .map((world) => DropdownMenuItem(value: world, child: Text(world.label(context) as String)))
                  .toList(),
              onChanged: (value) {
                if (value != null && value != _currentWorld) {
                  setState(() => _currentWorld = value);
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<World>(
        future: manager.getWorld(_currentWorld),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final world = snapshot.data!;
          return Row(
            children: [
              for (final layer in world.layers.toList()..sort((a, b) => a.index.compareTo(b.index)))
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(layer.label(context), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 350,
                        height: 350 * world.height / world.width,
                        child: InteractiveViewer(
                          constrained: false,
                          child: CustomPaint(
                            size: Size(350, 350 * world.height / world.width),
                            painter: WorldPainter(world: world, layer: layer),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
