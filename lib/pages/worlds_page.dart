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
import 'package:sentry_flutter/sentry_flutter.dart';

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

enum _NavigatePathView {
  both,
  path1,
  path2,
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
  bool _navigateDouble = false;
  _NavigateEditMode _navigateEditMode = _NavigateEditMode.none;
  _NavigatePathView _navigatePathView = _NavigatePathView.both;
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
    Sentry.metrics.count('worlds', 1, attributes: {
      'type': SentryAttribute.string(manager.provider.type.label(context)),
      'difficulty': SentryAttribute.string(manager.provider.difficulty.label(context)),
      'map': SentryAttribute.string(worldLabel(_currentWorld, context)),
    });
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
            IconButton(
              onPressed: () => setState(() => _navigateMode = !_navigateMode),
              icon: const Icon(Icons.navigation_outlined),
              selectedIcon: const Icon(Icons.navigation),
              isSelected: _navigateMode,
              tooltip: S.of(context).worldsNavigateMode,
            ),
            IconButton(
              onPressed: _navigateMode ? () => setState(() => _showNavigateProperties = !_showNavigateProperties) : null,
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              isSelected: _showNavigateProperties,
              tooltip: S.of(context).worldsNavigateSetting,
            ),
            IconButton(
              onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
              icon: Icon(_isFullscreen ? Icons.grid_view : Icons.fullscreen),
              isSelected: _isFullscreen,
              tooltip: _isFullscreen ? S.of(context).worldsFullscreenExit : S.of(context).worldsFullscreen,
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
                  final hidePath1 = _navigateDouble && _navigatePathView == _NavigatePathView.path2;
                  final hidePath2 = _navigateDouble && _navigatePathView == _NavigatePathView.path1;
                  return _WorldLayerPaint(
                    world: world,
                    layer: layer,
                    auto: auto,
                    resources: navigateArguments?.resources ?? <Node>{},
                    path: hidePath1 ? null : path1,
                    path2: hidePath2 ? null : path2,
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
                                child: InteractiveViewer(
                                  child: buildLayerPaint(layer, false),
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

  Widget _buildNavigateProperties(BuildContext context, World world, List<Node>? path1, List<Node>? path2, bool loading) {
    final origin = UnionNavigateArguments.fromProvider(provider: manager.provider, world: world, setting: _defaultNavigateSettings, defaultEntrance: entrance);
    final current = _navigateArguments[_currentWorld]!;
    final editingStart = _navigateEditMode == _NavigateEditMode.start;
    final editingStart2 = _navigateEditMode == _NavigateEditMode.start2;
    final editingResource = _navigateEditMode == _NavigateEditMode.resource;
    void update(UnionNavigateArguments arguments) => setState(() => _navigateArguments[_currentWorld] = arguments);
    void toggleEdit(_NavigateEditMode mode) => setState(() => _navigateEditMode = _navigateEditMode == mode ? _NavigateEditMode.none : mode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(S.of(context).worldsNavigateSetting),
        const SizedBox(height: 4),
        _buildNavigateCard(
          context,
          icon: Icons.people_alt,
          title: S.of(context).worldsNavigateDoubleMode,
          trailing: Switch(
            value: _navigateDouble,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (value) => setState(() => _navigateDouble = value),
          ),
        ),
        if (_navigateDouble)
          _buildNavigateCard(
            context,
            icon: Icons.visibility_outlined,
            title: S.of(context).worldsNavigatePathView,
            trailing: SegmentedButton<_NavigatePathView>(
              selected: {_navigatePathView},
              showSelectedIcon: false,
              emptySelectionAllowed: false,
              multiSelectionEnabled: false,
              segments: const [
                ButtonSegment(
                  value: _NavigatePathView.path1,
                  label: Text('1'),
                ),
                ButtonSegment(
                  value: _NavigatePathView.both,
                  label: Text('1+2'),
                ),
                ButtonSegment(
                  value: _NavigatePathView.path2,
                  label: Text('2'),
                ),
              ],
              onSelectionChanged: (s) => setState(() => _navigatePathView = s.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: WidgetStatePropertyAll(Size(28, 28)),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                ),
              ),
            ),
          ),
        _buildNavigateCard(
          context,
          icon: Icons.flag,
          title: S.of(context).worldsNavigateStartNode,
          value: S.of(context).worldsNavigateStartNodeValue(
            current.start.layer.label(context),
            current.start.x,
            current.start.y,
          ),
          selected: editingStart,
          actions: [
            _buildIconAction(
              context,
              icon: editingStart ? Icons.check : Icons.touch_app,
              tooltip: editingStart
                ? S.of(context).worldsNavigateStartNodeEditExit
                : S.of(context).worldsNavigateStartNodeEdit,
              onPressed: () => toggleEdit(_NavigateEditMode.start),
              selected: editingStart,
            ),
            _buildIconAction(
              context,
              icon: Icons.restart_alt,
              tooltip: S.of(context).worldsNavigateReset,
              onPressed: () => update(current.copyWith(start: origin.start)),
            ),
          ],
        ),
        if (_navigateDouble)
          _buildNavigateCard(
            context,
            icon: Icons.flag_outlined,
            title: S.of(context).worldsNavigateDoubleStartNode,
            value: S.of(context).worldsNavigateStartNodeValue(
              current.start2.layer.label(context),
              current.start2.x,
              current.start2.y,
            ),
            selected: editingStart2,
            actions: [
              _buildIconAction(
                context,
                icon: editingStart2 ? Icons.check : Icons.touch_app,
                tooltip: editingStart2
                  ? S.of(context).worldsNavigateStartNodeEditExit
                  : S.of(context).worldsNavigateStartNodeEdit,
                onPressed: () => toggleEdit(_NavigateEditMode.start2),
                selected: editingStart2,
              ),
              _buildIconAction(
                context,
                icon: Icons.restart_alt,
                tooltip: S.of(context).worldsNavigateReset,
                onPressed: () => update(current.copyWith(start2: origin.start2)),
              ),
            ],
          ),
        _buildNavigateCard(
          context,
          icon: Icons.inventory,
          title: S.of(context).worldsNavigateResource,
          value: S.of(context).worldsNavigateResourceValue(current.resources.length),
          selected: editingResource,
          actions: [
            _buildIconAction(
              context,
              icon: editingResource ? Icons.check : Icons.touch_app,
              tooltip: editingResource
                ? S.of(context).worldsNavigateResourceEditExit
                : S.of(context).worldsNavigateResourceEdit,
              onPressed: () => toggleEdit(_NavigateEditMode.resource),
              selected: editingResource,
            ),
            _buildIconAction(
              context,
              icon: Icons.restart_alt,
              tooltip: S.of(context).worldsNavigateReset,
              onPressed: () => update(current.copyWith(resources: origin.resources)),
            ),
            _buildIconAction(
              context,
              icon: Icons.clear_all,
              tooltip: S.of(context).worldsNavigateResourceClear,
              onPressed: () => update(current.copyWith(resources: <Node>{})),
            ),
          ],
        ),
        if (origin.keyResource != null)
          _buildNavigateCard(
            context,
            icon: Icons.key,
            title: S.of(context).worldsNavigateKeyResource,
            trailing: Switch(
              value: current.keyResource != null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) => update(
                current.copyWith(keyResource: value ? origin.keyResource : null),
              ),
            ),
          ),
        _buildNavigateCard(
          context,
          icon: Icons.exit_to_app,
          title: S.of(context).worldsNavigateExit,
          trailing: Switch(
            value: current.exits.isNotEmpty,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (value) => update(
              current.copyWith(exits: value ? origin.exits : <Node>{}),
            ),
          ),
        ),
        _buildNavigateCard(
          context,
          icon: Icons.route_outlined,
          title: S.of(context).worldsNavigatePathLength,
          value: loading ? null : _navigateDouble
            ? '${path1?.length ?? 0} / ${path2?.length ?? 0}'
            : '${path1?.length ?? 0}',
          trailing: loading ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ) : null,
        ),
      ],
    );
  }

  Widget _buildIconAction(BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool selected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        fixedSize: const Size(30, 30),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: selected ? scheme.primary : scheme.onSurfaceVariant,
        backgroundColor: selected ? scheme.primaryContainer : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildNavigateCard(BuildContext context, {
    required IconData icon,
    required String title,
    String? value,
    bool selected = false,
    Widget? trailing,
    List<Widget> actions = const <Widget>[],
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                  if (value != null)
                    TextSpan(
                      text: '  $value',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 4),
            for (final action in actions) action,
          ],
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing,
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
