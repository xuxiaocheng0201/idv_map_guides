import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idv_map_guides/bloc/map_cubit.dart';
import 'package:idv_map_guides/core/l10n.dart';
import 'package:idv_map_guides/core/maps.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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

            Text(S.of(context).mapChoose, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            BlocBuilder<MapCubit, MapState>(
              builder: (context, state) => Wrap(
                spacing: 12,
                children: MapType.values.map((map) {
                  final isSelected = state.map == map;
                  return ChoiceChip(
                    label: Text(map.label(context)),
                    selected: isSelected,
                    onSelected: (_) => context.read<MapCubit>().selectMap(map),
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            Text(S.of(context).difficultyChoose, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            BlocBuilder<MapCubit, MapState>(
              builder: (context, state) => Wrap(
                  spacing: 12,
                  children: MapDifficulty.values.map((difficulty) {
                    final isSelected = state.difficulty == difficulty;
                    return ChoiceChip(
                      label: Text(difficulty.label(context)),
                      selected: isSelected,
                      onSelected: (_) => context.read<MapCubit>().selectDifficulty(difficulty),
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    );
                  }).toList(),
                ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                final state = context.read<MapCubit>().state;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Enter ${state.map.label(context)} - ${state.difficulty.label(context)}',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                S.of(context).enter,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
