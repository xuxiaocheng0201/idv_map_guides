import 'package:flutter/material.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/l10n.dart';
import 'package:idv_map_guides/core_data/modules.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/main.dart';
import 'package:idv_map_guides/pages/editors/editor_store.dart';
import 'package:idv_map_guides/pages/entrances_page.dart';
import 'package:idv_map_guides/routes.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:toastification/toastification.dart';

class SecretSwitch extends StatefulWidget {
  const SecretSwitch({super.key, required this.child});
  final Widget child;

  @override
  State<SecretSwitch> createState() => _SecretSwitchState();
}

class _SecretSwitchState extends State<SecretSwitch> {
  int _taps = 0;
  DateTime? _lastTap;

  void _handleTap() {
    if (editorMode.value) return;
    final now = DateTime.now();
    if (_lastTap == null || now.difference(_lastTap!) > const Duration(seconds: 1)) {
      _taps = 0;
    }
    _lastTap = now;
    _taps++;
    if (_taps >= 7) {
      _taps = 0;
      editorMode.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WorldType _world = WorldType.theBringerOfDoom;
  WorldDifficulty _difficulty = WorldDifficulty.nightmare;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: editorMode,
      builder: (context, enabled, _) {
        return Scaffold(
          floatingActionButton: enabled ? FloatingActionButton(
            child: const Icon(Icons.edit),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => _EditorEntryDialog(),
              );
            },
          ) : null,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  S.of(context).title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FutureBuilder(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    final text = info == null ? 'null' : '${info.version}+$bundledVersion';
                    return SecretSwitch(child: Text(text));
                  },
                ),
                const SizedBox(height: 32),

                Text(S.of(context).homeChooseWorld, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: WorldType.values.map((world) {
                    return ChoiceChip(
                      label: Text(world.label(context)),
                      selected: _world == world,
                      onSelected: (_) => setState(() => _world = world),
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                Text(S.of(context).homeChooseDifficulty, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: WorldDifficulty.values.map((difficulty) {
                    return ChoiceChip(
                      label: Text(difficulty.label(context)),
                      selected: _difficulty == difficulty,
                      onSelected: (_) => setState(() => _difficulty = difficulty),
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: () {
                    final manager = getWorldsManager(_world, _difficulty);
                    if (manager == null) {
                      toastification.show(
                        autoCloseDuration: const Duration(seconds: 3),
                        showProgressBar: true,
                        title: Text(S.of(context).homeNotSupport),
                      );
                      return;
                    }
                    Navigator.pushNamed(
                      context,
                      Routes.entrances,
                      arguments: EntranceFeaturePageArguments(manager: manager),
                    );
                  },
                  child: Text(S.of(context).homeEnter),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}

class _EditorEntryDialog extends StatefulWidget {
  @override
  State<_EditorEntryDialog> createState() => _EditorEntryDialogState();
}

class _EditorEntryDialogState extends State<_EditorEntryDialog> {
  WorldType _target = WorldType.theBringerOfDoom;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择要编辑的地图'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: WorldType.values.map((type) {
                  return ChoiceChip(
                    label: Text(type.label(context)),
                    selected: _target == type,
                    onSelected: (_) => setState(() => _target = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    child: const Text('结构编辑'),
                    onPressed: () => _open(Routes.editorStructure),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    child: const Text('地图编辑'),
                    onPressed: () => _open(Routes.editorWorld),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(String route) {
    final codec = worldCodecFor(_target);
    final store = editorStoreFor(_target.assets, codec);
    final arguments = EditorRouteArguments(mapKey: _target.assets, store: store);
    Navigator.pushReplacementNamed(context, route, arguments: arguments);
  }
}
