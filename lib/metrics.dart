import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/core_data/classification.dart';
import 'package:idv_map_guides/core_data/l10n.dart';
import 'package:idv_map_guides/core_data/worlds_base.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void metricWorldTypeDifficulty(BuildContext context, WorldType type, WorldDifficulty difficulty) {
  if (kDebugMode) return;
  final key = '${type.name}/${difficulty.name}';
  Sentry.metrics.count(key, 1);
}

void metricWorldInstance(BuildContext context, BaseWorldsEnums world) {
  if (kDebugMode) return;
  final key = '${world.runtimeType}/${worldLabel(world, context)}';
  Sentry.metrics.count(key, 1);
}
