import 'package:flutter/widgets.dart';
import 'package:idv_map_guides/core/data.dart';
import 'package:idv_map_guides/core/world.dart';
import 'package:idv_map_guides/generated/l10n.dart';

extension GroundLayerL10n on GroundLayer {
  String label(BuildContext context) {
    return switch (this) {
      GroundLayer.basement => S.of(context).layerBasement,
      GroundLayer.ground => S.of(context).layerGround,
      GroundLayer.second => S.of(context).layerSecond,
    };
  }
}

extension RotationL10n on Rotation {
  String label(BuildContext context) {
    return switch (this) {
      Rotation.cw0 => S.of(context).rotation0cw,
      Rotation.cw90 => S.of(context).rotation90cw,
      Rotation.cw180 => S.of(context).rotation180cw,
      Rotation.cw270 => S.of(context).rotation270cw,
    };
  }
}

extension DirectionL10n on Direction {
  String label(BuildContext context) {
    return switch (this) {
      Direction.north => S.of(context).directionNorth,
      Direction.east => S.of(context).directionEast,
      Direction.south => S.of(context).directionSouth,
      Direction.west => S.of(context).directionWest,
    };
  }
}

extension StairTransportL10n on StairTransport {
  String label(BuildContext context) {
    return switch (this) {
      StairTransport.nothing => S.of(context).stairTransportNothing,
      StairTransport.goUp => S.of(context).stairTransportGoUp,
      StairTransport.goDown => S.of(context).stairTransportGoDown,
    };
  }
}

extension EdgeTypeL10n on EdgeType {
  String label(BuildContext context) {
    return switch (this) {
      EdgeType.nothing => S.of(context).edgeTypeNothing,
      EdgeType.door => S.of(context).edgeTypeDoor,
      EdgeType.innerWall => S.of(context).edgeTypeInnerWall,
      EdgeType.hole => S.of(context).edgeTypeHole,
    };
  }
}

extension EntranceTypeL10n on EntranceType {
  String label(BuildContext context) {
    return switch (this) {
      EntranceType.main => S.of(context).entranceTypeMain,
      EntranceType.sideGround => S.of(context).entranceTypeSideGround,
      EntranceType.sideSecond => S.of(context).entranceTypeSideSecond,
      EntranceType.alterBasement => '地下室祭坛',
    };
  }
}
