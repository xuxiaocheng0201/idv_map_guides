import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/worlds.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/pages/entrances_page.dart';
import 'package:idv_map_guides/routes.dart';
import 'package:toastification/toastification.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WorldType _world = WorldType.theBringerOfDoom;
  WorldDifficulty _difficulty = WorldDifficulty.insane;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: kDebugMode ? FloatingActionButton(
        child: const Icon(Icons.edit),
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: SizedBox(
                width: 300,
                height: 240,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: const Text('结构编辑'),
                      onPressed: () => Navigator.pushReplacementNamed(context, Routes.editorStructure),
                    ),
                    TextButton(
                      child: const Text('地图编辑'),
                      onPressed: () => Navigator.pushReplacementNamed(context, Routes.editorWorld),
                    ),
                  ],
                ),
              ),
            ),
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
                  arguments: EntranceFeaturePageArgument(manager: manager),
                );
              },
              child: Text(S.of(context).homeEnter),
            ),
          ],
        ),
      ),
    );
  }
}
