import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/core_data/l10n.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/core_navigator/setting.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/painter/world_painter.dart';
import 'package:idv_map_guides/routes.dart';

class WorldListPageArguments {
  final WorldsManager<BaseWorldsEnums> manager;
  final List<BaseWorldsEnums> worlds;
  final EntranceType entrance;
  final DefaultNavigateSettings settings;
  const WorldListPageArguments({required this.manager, required this.worlds, required this.entrance, required this.settings});
}

enum _NavigateEditMode {
  none,
  start,
  resource,
  start2,
}

class WorldListPage extends StatefulWidget {
  const WorldListPage({super.key});

  @override
  State<WorldListPage> createState() => _WorldListPageState();
}

class _WorldListPageState extends State<WorldListPage> {
  late WorldsManager<BaseWorldsEnums> manager;
  late List<BaseWorldsEnums> worlds;
  late EntranceType entrance;
  late DefaultNavigateSettings _defaultNavigateSettings;
  bool _initialized = false;
  late BaseWorldsEnums _currentWorld;

  final FocusNode _focusNode = FocusNode(debugLabel: 'WorldListPage');
  bool _isFullscreen = false;
  int _currentLayerIndex = 0;
  List<GroundLayer> _currentLayers = const [];

  bool _navigateMode = true;
  bool _showNavigateProperties = true;
  _NavigateEditMode _navigateEditMode = _NavigateEditMode.none;
  bool _navigateDouble = false;
  final Map<BaseWorldsEnums, UnionNavigateArguments> _navigateArguments = <BaseWorldsEnums, UnionNavigateArguments>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final argument = ModalRoute.of(context)?.settings.arguments as WorldListPageArguments?;
    if (argument == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.popAndPushNamed(context, Routes.home);
        }
      });
      return;
    }
    manager = argument.manager;
    worlds = argument.worlds;
    entrance = argument.entrance;
    _defaultNavigateSettings = argument.settings;
    _navigateDouble = _defaultNavigateSettings.useDouble;
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
                      label: Text(worldLabel(world, context)),
                    )
                ],
                showSelectedIcon: false,
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
              return UnionNavigateArguments.fromProvider(
                provider: manager.provider,
                world: world,
                setting: _defaultNavigateSettings,
                defaultEntrance: entrance,
              );
            }) : null;
            Future<dynamic>? navigationFuture;
            if (_navigateMode && navigateArguments != null) {
              if (_navigateDouble) {
                navigationFuture = manager.getNavigateDoubleResult(_currentWorld, navigateArguments.twoArgument);
              } else {
                navigationFuture = manager.getNavigateResult(_currentWorld, navigateArguments.oneArgument);
              }
            }
            return FutureBuilder(
              initialData: null,
              future: navigationFuture,
              builder: (context, asyncSnapshot) {
                List<Node>? path1;
                List<Node>? path2;
                final data = asyncSnapshot.data;
                if (_navigateDouble) {
                  if (data is ({List<Node> path1, List<Node> path2})) {
                    path1 = data.path1;
                    path2 = data.path2;
                  }
                } else {
                  if (data is List<Node>) path1 = data;
                }
                final loading = asyncSnapshot.connectionState != ConnectionState.done;
                Widget buildLayerPaint(GroundLayer layer, bool auto) {
                  return _WorldLayerPaint(
                    world: world,
                    layer: layer,
                    auto: auto,
                    resources: navigateArguments?.resources ?? <Node>{},
                    path: path1,
                    path2: path2,
                    onCellTap: _navigateMode ? (tapLayer, x, y) => _handleNavigateCellTap(world, tapLayer, x, y) : null,
                  );
                }
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
                              showSelectedIcon: false,
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
                                child: buildLayerPaint(layer, false),
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
                                            child: buildLayerPaint(layer, true),
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
                          child: SingleChildScrollView(
                            child: _buildNavigateProperties(
                              context,
                              world,
                              navigateArguments,
                              path1,
                              path2,
                              loading,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
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
    final currentArguments = _navigateArguments[_currentWorld]!;
    switch (_navigateEditMode) {
      case _NavigateEditMode.none:
        break;
      case _NavigateEditMode.start:
        setState(() => _navigateArguments[_currentWorld] = currentArguments.copyWith(start: Node(layer, x, y)));
        break;
      case _NavigateEditMode.start2:
        setState(() => _navigateArguments[_currentWorld] = currentArguments.copyWith(start2: Node(layer, x, y)));
        break;
      case _NavigateEditMode.resource:
        final node = Node(layer, x, y);
        final resources = Set<Node>.of(currentArguments.resources);
        if (!resources.remove(node)) {
          resources.add(node);
        } // FIXME: optimize
        setState(() => _navigateArguments[_currentWorld] = currentArguments.copyWith(resources: resources));
        break;
    }
  }

  Widget _buildNavigateProperties(BuildContext context, World world, UnionNavigateArguments? currentArguments, List<Node>? path1, List<Node>? path2, bool loading) {
    final origin = UnionNavigateArguments.fromProvider(provider: manager.provider, world: world, setting: _defaultNavigateSettings, defaultEntrance: entrance);
    final current = _navigateArguments[_currentWorld]!;
    return Column(
      children: [
        Text(S.of(context).worldsNavigateSetting),
        const SizedBox(height: 8),
        _buildNavigateCard(
          context,
          selected: false,
          icon: Icons.people_alt,
          title: S.of(context).worldsNavigateDoubleMode,
          headerAction: Switch(
            value: _navigateDouble,
            onChanged: (value) => setState(() => _navigateDouble = value),
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final isStartEditing = _navigateEditMode == _NavigateEditMode.start;
            final start = current.start;
            return _buildNavigateCard(
              context,
              selected: isStartEditing,
              icon: Icons.flag,
              title: S.of(context).worldsNavigateStartNode,
              body: Text(S.of(context).worldsNavigateStartNodeValue(start.layer.label(context), start.x, start.y)),
              headerAction: (isStartEditing ? FilledButton.icon : OutlinedButton.icon)(
                onPressed: () => setState(() {
                  _navigateEditMode = isStartEditing ? _NavigateEditMode.none : _NavigateEditMode.start;
                }),
                icon: const Icon(Icons.touch_app),
                label: Text(isStartEditing
                    ? S.of(context).worldsNavigateStartNodeEditExit
                    : S.of(context).worldsNavigateStartNodeEdit),
              ),
              action: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _navigateArguments[_currentWorld] = current.copyWith(start: origin.start);
                      });
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: Text(S.of(context).worldsNavigateReset),
                  ),
                ],
              ),
            );
          },
        ),
        if (_navigateDouble) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final isStart2Editing = _navigateEditMode == _NavigateEditMode.start2;
              final start2 = current.start2;
              return _buildNavigateCard(
                context,
                selected: isStart2Editing,
                icon: Icons.flag,
                title: S.of(context).worldsNavigateDoubleStartNode,
                body: Text(S.of(context).worldsNavigateStartNodeValue(start2.layer.label(context), start2.x, start2.y)),
                headerAction: (isStart2Editing ? FilledButton.icon : OutlinedButton.icon)(
                  onPressed: () => setState(() {
                    _navigateEditMode = isStart2Editing ? _NavigateEditMode.none : _NavigateEditMode.start2;
                  }),
                  icon: const Icon(Icons.touch_app),
                  label: Text(isStart2Editing
                      ? S.of(context).worldsNavigateStartNodeEditExit
                      : S.of(context).worldsNavigateStartNodeEdit),
                ),
                action: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _navigateArguments[_currentWorld] = current.copyWith(start2: origin.start2);
                        });
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: Text(S.of(context).worldsNavigateReset),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final isResourceEditing = _navigateEditMode == _NavigateEditMode.resource;
            final resources = current.resources;
            return _buildNavigateCard(
              context,
              selected: isResourceEditing,
              icon: Icons.inventory,
              title: S.of(context).worldsNavigateResource,
              body: Text(S.of(context).worldsNavigateResourceValue(resources.length)),
              headerAction: (isResourceEditing ? FilledButton.icon : OutlinedButton.icon)(
                onPressed: () => setState(() {
                  _navigateEditMode = isResourceEditing ? _NavigateEditMode.none : _NavigateEditMode.resource;
                }),
                icon: const Icon(Icons.touch_app),
                label: Text(isResourceEditing
                    ? S.of(context).worldsNavigateResourceEditExit
                    : S.of(context).worldsNavigateResourceEdit),
              ),
              action: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _navigateArguments[_currentWorld] = current.copyWith(resources: origin.resources);
                    }),
                    icon: const Icon(Icons.restart_alt),
                    label: Text(S.of(context).worldsNavigateReset),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _navigateArguments[_currentWorld] = current.copyWith(resources: <Node>{});
                    }),
                    icon: const Icon(Icons.clear_all),
                    label: Text(S.of(context).worldsNavigateResourceClear),
                  ),
                ],
              ),
            );
          },
        ),
        if (origin.keyResource != null) ...[
          const SizedBox(height: 8),
          _buildNavigateCard(
            context,
            selected: false,
            icon: Icons.key,
            title: S.of(context).worldsNavigateKeyResource,
            headerAction: Switch(
              value: current.keyResource != null,
              onChanged: (value) => setState(() {
                _navigateArguments[_currentWorld] = current.copyWith(keyResource: value ? origin.keyResource : null);
              }),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _buildNavigateCard(
          context,
          selected: false,
          icon: Icons.exit_to_app,
          title: S.of(context).worldsNavigateExit,
          headerAction: Switch(
            value: current.exits.isNotEmpty,
            onChanged: (value) => setState(() {
              _navigateArguments[_currentWorld] = current.copyWith(exits: value ? origin.exits : <Node>{});
            }),
          ),
        ),
        const SizedBox(height: 8),
        _buildNavigateCard(
          context,
          selected: false,
          icon: Icons.route_outlined,
          title: S.of(context).worldsNavigatePathLength,
          headerAction: SizedBox(
            height: 36,
            child: loading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : _navigateDouble
                ? Text('${path1?.length ?? 0} ${path2?.length ?? 0}')
                : Text('${path1?.length ?? 0}'),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigateCard(BuildContext context, {
    required bool selected,
    required IconData icon,
    required String title,
    Widget? body,
    Widget? headerAction,
    Widget? action,
  }) {
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
              ?headerAction,
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            body,
          ],
          if (action != null) ...[
            const SizedBox(height: 8),
            action,
          ],
        ],
      ),
    );
  }
}

class _WorldLayerPaint extends StatelessWidget {
  final World world;
  final GroundLayer layer;
  final bool auto;
  final Set<Node>? resources;
  final List<Node>? path;
  final List<Node>? path2;
  final void Function(GroundLayer layer, int x, int y)? onCellTap;

  const _WorldLayerPaint({
    required this.world,
    required this.layer,
    required this.auto,
    this.resources,
    this.path,
    this.path2,
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
            painter.path2 = path2 ?? <Node>[];
            painter.resources = resources ?? <Node>{};
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
