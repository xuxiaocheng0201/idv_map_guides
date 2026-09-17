import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/navigator.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/painter/world_painter.dart';

class WorldListPageArguments {
  final WorldsManager<dynamic> manager;
  final List<dynamic> worlds;
  final EntranceType entrance;
  const WorldListPageArguments({required this.manager, required this.worlds, required this.entrance});
}

enum _NavigateEditMode {
  none,
  start,
  resource,
}

class WorldListPage extends StatefulWidget {
  const WorldListPage({super.key});

  @override
  State<WorldListPage> createState() => _WorldListPageState();
}

class _WorldListPageState extends State<WorldListPage> {
  late WorldsManager<dynamic> manager;
  late List<dynamic> worlds;
  late EntranceType entrance;
  bool _initialized = false;
  dynamic _currentWorld;

  final FocusNode _focusNode = FocusNode(debugLabel: 'WorldListPage');
  bool _isFullscreen = false;
  int _currentLayerIndex = 0;
  List<GroundLayer> _currentLayers = const [];

  bool _navigateMode = true;
  bool _showNavigateProperties = true;
  _NavigateEditMode _navigateEditMode = _NavigateEditMode.none;
  final Map<dynamic, NavigateArguments> _navigateArguments = <dynamic, NavigateArguments>{};

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
    entrance = argument.entrance;
    _currentWorld = worlds.first;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).worldsShowMap),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CheckboxMenuButton(
                value: _navigateMode,
                onChanged: (value) => setState(() => _navigateMode = value!),
                child: Text(S.of(context).worldsNavigateMode),
              ),
            ),
            IconButton(
              onPressed: _navigateMode ? () => setState(() => _showNavigateProperties = !_showNavigateProperties) : null,
              icon: Icon(_showNavigateProperties ? Icons.settings : Icons.settings_outlined),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SegmentedButton(
                selected: {_currentWorld},
                segments: [
                  for (final world in worlds)
                    ButtonSegment(
                      value: world,
                      label: Text(world.label(context) as String),
                    )
                ],
                emptySelectionAllowed: false,
                multiSelectionEnabled: false,
                onSelectionChanged: (w) => setState(() {
                  _currentWorld = w.first;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: IconButton(
                onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
                icon: Icon(_isFullscreen ? Icons.grid_view : Icons.fullscreen),
                tooltip: _isFullscreen ? S.of(context).worldsFullscreenExit : S.of(context).worldsFullscreen,
              ),
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
            final layers = world.layers.sortedBy((e) => e.index);
            _currentLayers = layers;
            if (_currentLayerIndex >= layers.length) {
              _currentLayerIndex = 0;
            }
            final layer = layers[_currentLayerIndex];
            final navigateArguments = _navigateMode ? _navigateArguments.putIfAbsent(_currentWorld, () {
              return manager.provider.navigateArguments(world, entrance);
            }) : null;
            return FutureBuilder(
              initialData: null,
              future: navigateArguments == null ? null : manager.getNavigateResult(_currentWorld, navigateArguments),
              builder: (context, asyncSnapshot) {
                final path = asyncSnapshot.data;
                return Row(
                  children: [
                    Expanded(
                      child: _isFullscreen ?
                        Column(
                          children: [
                            SegmentedButton(
                              selected: {_currentLayerIndex},
                              segments: [
                                for (int i = 0; i < layers.length; i++)
                                  ButtonSegment(
                                    value: i,
                                    label: Text(layers[i].label(context)),
                                  )
                              ],
                              emptySelectionAllowed: false,
                              multiSelectionEnabled: false,
                              onSelectionChanged: (i) => setState(() {
                                _currentLayerIndex = i.first;
                              }),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: _WorldLayerPaint(
                                  world: world,
                                  layer: layer,
                                  auto: false,
                                  arguments: navigateArguments,
                                  path: path,
                                  onCellTap: _navigateMode
                                    ? (tapLayer, x, y) => _handleNavigateCellTap(world, tapLayer, x, y)
                                    : null,
                                ),
                              ),
                            ),
                          ],
                        ) :
                        OrientationBuilder(
                          builder: (context, orientation) {
                            return Flex(
                              direction: switch (orientation) {
                                Orientation.portrait => Axis.vertical,
                                Orientation.landscape => Axis.horizontal,
                              },
                              children: [
                                for (final layer in layers)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            layer.label(context),
                                            style: Theme.of(context).textTheme.titleMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 4),
                                          Expanded(
                                            child: _WorldLayerPaint(
                                              world: world,
                                              layer: layer,
                                              auto: true,
                                              arguments: navigateArguments,
                                              path: path,
                                              onCellTap: _navigateMode
                                                ? (tapLayer, x, y) => _handleNavigateCellTap(world, tapLayer, x, y)
                                                : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                    ),
                    if (_navigateMode && _showNavigateProperties)
                      SizedBox(
                        width: 300,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _buildNavigateProperties(context, world, navigateArguments!.start, navigateArguments.resources, navigateArguments.exits.isNotEmpty),
                        ),
                      ),
                  ],
                );
              }
            );
          },
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final reverse = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.tab:
        if (_isFullscreen) {
          _cycleLayer(reverse: reverse);
        } else {
          _cycleWorld(reverse: reverse);
        }
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _cycleLayer({required bool reverse}) {
    if (_currentLayers.isEmpty) return;
    final len = _currentLayers.length;
    setState(() {
      _currentLayerIndex = (_currentLayerIndex + (reverse ? -1 : 1) + len) % len;
    });
  }

  void _cycleWorld({required bool reverse}) {
    if (worlds.length < 2) return;
    final len = worlds.length;
    final current = worlds.indexWhere((w) => identical(w, _currentWorld) || w == _currentWorld);
    final next = ((current < 0 ? 0 : current) + (reverse ? -1 : 1) + len) % len;
    setState(() {
      _currentWorld = worlds[next];
      _currentLayerIndex = 0;
      _currentLayers = const [];
    });
  }

  void _handleNavigateCellTap(World world, GroundLayer layer, int x, int y) {
    if (!_navigateMode) return;
    final cell = world.cell(layer, x, y);
    if (cell == null || cell.structureId == null) return;
    switch (_navigateEditMode) {
      case _NavigateEditMode.none:
        break;
      case _NavigateEditMode.start:
        setState(() => _navigateArguments[_currentWorld] = _navigateArguments[_currentWorld]!.copyWith(start: Node(layer, x, y)));
        break;
      case _NavigateEditMode.resource:
        final node = Node(layer, x, y);
        final resources = Set<Node>.of(_navigateArguments[_currentWorld]!.resources);
        if (!resources.remove(node)) {
          resources.add(node);
        }
        setState(() {
          _navigateArguments[_currentWorld] = _navigateArguments[_currentWorld]!.copyWith(resources: resources);
        });
        break;
    }
  }

  Widget _buildNavigateProperties(BuildContext context, World world, Node startNode, Set<Node> resources, bool exit) {
    return Column(
      children: [
        Text(S.of(context).worldsNavigateSetting),
        const SizedBox(height: 8),
        _buildNavigateCard(context,
          mode: _NavigateEditMode.start,
          icon: Icons.flag,
          title: S.of(context).worldsNavigateStartNode,
          body: Text(S.of(context).worldsNavigateStartNodeValue(startNode.layer.label(context), startNode.x, startNode.y)),
          action: (editingStart) => Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _navigateEditMode = editingStart ? _NavigateEditMode.none : _NavigateEditMode.start;
                }),
                icon: const Icon(Icons.touch_app),
                label: Text(
                  editingStart ? S.of(context).worldsNavigateStartNodeEditExit : S.of(context).worldsNavigateStartNodeEdit,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final origin = manager.provider.navigateArguments(world, entrance);
                  setState(() => _navigateArguments[_currentWorld] = _navigateArguments[_currentWorld]!.copyWith(start: origin.start));
                },
                icon: const Icon(Icons.restart_alt),
                label: Text(S.of(context).worldsNavigateReset),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildNavigateCard(context,
          mode: _NavigateEditMode.resource,
          icon: Icons.inventory,
          title: S.of(context).worldsNavigateResource,
          body: Text(S.of(context).worldsNavigateResourceValue(resources.length)),
          action: (editingResource) => Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _navigateEditMode = editingResource ? _NavigateEditMode.none : _NavigateEditMode.resource;
                }),
                icon: const Icon(Icons.touch_app),
                label: Text(
                  editingResource ? S.of(context).worldsNavigateResourceEditExit : S.of(context).worldsNavigateResourceEdit,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _navigateArguments[_currentWorld] = _navigateArguments[_currentWorld]!.copyWith(resources: <Node>{});
                }),
                icon: const Icon(Icons.clear_all),
                label: Text(S.of(context).worldsNavigateResourceClear),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _navigateArguments[_currentWorld] = _navigateArguments[_currentWorld]!.copyWith(resources: Set<Node>.of(world.resources));
                }),
                icon: const Icon(Icons.restart_alt),
                label: Text(S.of(context).worldsNavigateReset),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(S.of(context).worldsNavigateExit),
          value: exit,
          onChanged: (value) => setState(() {
            _navigateArguments[_currentWorld] = _navigateArguments[_currentWorld]!.copyWith(exits:
              value ? manager.provider.navigateArguments(world, entrance).exits : <Node>{},
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNavigateCard(BuildContext context, {
    required _NavigateEditMode mode,
    required IconData icon,
    required String title,
    required Widget body,
    required Widget Function(bool) action,
  }) {
    final selected = _navigateEditMode == mode;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : null),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (selected)
                Text(
                  S.of(context).worldsNavigateEditing,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          body,
          const SizedBox(height: 8),
          action(selected),
        ],
      ),
    );
  }
}

class _WorldLayerPaint extends StatelessWidget {
  final World world;
  final GroundLayer layer;
  final bool auto;
  final NavigateArguments? arguments;
  final List<Node>? path;
  final void Function(GroundLayer layer, int x, int y)? onCellTap;

  const _WorldLayerPaint({
    required this.world,
    required this.layer,
    required this.auto,
    this.arguments,
    this.path,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final painter = auto ? WorldPainter.auto(world: world, layer: layer) : WorldPainter(world: world, layer: layer);
            painter.path = path ?? <Node>[];
            painter.resources = arguments?.resources ?? <Node>{};
            final cellSize = min(constraints.maxWidth / painter.width, constraints.maxHeight / painter.height);
            final paintSize = Size(painter.width * cellSize, painter.height * cellSize);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onCellTap == null ? null : (details) {
                final local = details.localPosition;
                final x = painter.minX + (local.dx / cellSize).floor();
                final y = painter.maxY - (local.dy / cellSize).floor();
                if (x < world.minX || world.maxX < x || y < world.minY || world.maxY < y) {
                  return;
                }
                onCellTap!(layer, x, y);
              },
              child: SizedBox.fromSize(
                size: paintSize,
                child: CustomPaint(
                  size: paintSize,
                  painter: painter,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
