import 'dart:ui';

import 'package:comparators/comparators.dart';
import 'package:idv_map_guides/core/data.dart';

const pathColor = Color(0xFF00EEFF);
const pathStartColor = Color(0xFF00DD77);
const pathEndColor = Color(0xFFFF3399);
const pathMarkerColor = Color(0xFFFFFFFF);

void _drawPathStart(Canvas canvas, Offset center, double cellSize) {
  final radius = cellSize * 0.26;
  final fillPaint = Paint()
    ..color = pathStartColor
    ..style = PaintingStyle.fill;
  final borderPaint = Paint()
    ..color = pathMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.05;
  final innerPaint = Paint()
    ..color = pathMarkerColor
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, radius, fillPaint);
  canvas.drawCircle(center, radius, borderPaint);
  canvas.drawCircle(center, radius * 0.36, innerPaint);
}

void _drawPathEnd(Canvas canvas, Offset center, double cellSize) {
  final radius = cellSize * 0.26;
  final fillPaint = Paint()
    ..color = pathEndColor
    ..style = PaintingStyle.fill;
  final borderPaint = Paint()
    ..color = pathMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.05;
  final innerPaint = Paint()
    ..color = pathMarkerColor
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, radius, fillPaint);
  canvas.drawCircle(center, radius, borderPaint);
  final side = radius * 0.8;
  canvas.drawRect(Rect.fromCenter(center: center, width: side, height: side), innerPaint);
}

class _PathNodeInfo {
  final int polylineIndex;
  final int nodeIndex;
  final Offset incomingSide;
  final Offset outgoingSide;
  const _PathNodeInfo(
    this.polylineIndex,
    this.nodeIndex,
    this.incomingSide,
    this.outgoingSide,
  );
}

void paintPath(
  Canvas canvas,
  double cellSize,
  List<Node> path,
  GroundLayer layer,
  Offset Function(int, int, double) cellCenter,
  Color? color,
) {
  if (path.isEmpty) return;

  // 将完整的跨层路线，切成只连续出现在本层的若干路线段
  final polylines = <List<Node>>[];
  List<Node>? current;
  Node? prevNode;
  for (final node in path) {
    final bool nodeOnThisLayer = node.layer == layer;
    final bool isCrossLayerEntry = prevNode != null &&
        prevNode.layer == layer && !nodeOnThisLayer &&
        (node.x - prevNode.x).abs() + (node.y - prevNode.y).abs() == 1;
    if (!nodeOnThisLayer && !isCrossLayerEntry) {
      if (current != null && current.length > 1) {
        polylines.add(current);
      }
      current = null;
      prevNode = null;
      continue;
    }
    (current ??= <Node>[]).add(node);
    prevNode = node;
  }
  if (current != null && current.length > 1) polylines.add(current);
  if (polylines.isEmpty) return;

  // 统计每个单元格的路径节点信息
  final cellNodes = <Node, List<_PathNodeInfo>>{};
  for (int polylineIndex = 0; polylineIndex < polylines.length; polylineIndex++) {
    final nodes = polylines[polylineIndex];
    for (int nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
      final node = nodes[nodeIndex];
      final Offset center = cellCenter(node.x, node.y, cellSize);
      Offset incomingSide = Offset.zero; // 进入侧单位向量，从当前节点指向前一个节点的向量
      Offset outgoingSide = Offset.zero; // 离开侧单位向量，从当前节点指向后一个节点的向量
      if (nodeIndex > 0) { // 非起点，有进入侧单位向量
        final Offset p = cellCenter(nodes[nodeIndex - 1].x, nodes[nodeIndex - 1].y, cellSize);
        final Offset v = p - center;
        if (v.distance > 1e-6) incomingSide = v / v.distance;
      }
      if (nodeIndex < nodes.length - 1) { // 非终点，有离开侧单位向量
        final Offset q = cellCenter(nodes[nodeIndex + 1].x, nodes[nodeIndex + 1].y, cellSize);
        final Offset v = q - center;
        if (v.distance > 1e-6) outgoingSide = v / v.distance;
      }
      Offset virtualIncomingSide; // 来向单位向量
      Offset virtualOutgoingSide; // 去向单位向量
      if (nodeIndex == 0) { // 起点
        virtualIncomingSide = outgoingSide * -1;
        virtualOutgoingSide = outgoingSide;
      } else if (nodeIndex < nodes.length - 1) { // 终点
        virtualIncomingSide = incomingSide;
        virtualOutgoingSide = incomingSide * -1;
      } else { // 中间节点
        virtualIncomingSide = incomingSide + outgoingSide * -1;
        virtualIncomingSide = virtualIncomingSide.distance > 1e-6 ? virtualIncomingSide / virtualIncomingSide.distance : incomingSide;
        virtualOutgoingSide = incomingSide * -1 + outgoingSide;
        virtualOutgoingSide = virtualOutgoingSide.distance > 1e-6 ? virtualOutgoingSide / virtualOutgoingSide.distance : outgoingSide;
      }
      cellNodes.putIfAbsent(node, () => <_PathNodeInfo>[])
          .add(_PathNodeInfo(polylineIndex, nodeIndex, virtualIncomingSide, virtualOutgoingSide));
    }
  }

  // 计算每个路径节点的偏移量（分配车道）
  final laneOffsets = <(int, int), Offset>{}; // key: (polylineIndex, nodeIndex)
  for (final entry in cellNodes.entries) {
    final infos = entry.value;
    // 计算分布轴方向（多数路径东西走向 → 垂直轴(y)；多数南北走向 → 水平轴(x)）
    double sumAbsDx = 0, sumAbsDy = 0;
    for (final info in infos) {
      sumAbsDx += info.outgoingSide.dx.abs();
      sumAbsDy += info.outgoingSide.dy.abs();
    }
    final verticalAxis = sumAbsDx >= sumAbsDy; // 如果 x 分量总和更大，说明路径偏东西走向，分布轴应垂直（y轴）
    final Offset axis = verticalAxis ? const Offset(0, 1) : const Offset(1, 0); // 垂直轴为 (0,1)，水平轴为 (1,0)
    // 将车道从左到右/从下到上排序
    infos.sort(compareSequentially([
      compare<_PathNodeInfo>((info) => info.incomingSide.dy), // 来向 y 升序，北侧进入的排前
      compare<_PathNodeInfo>((info) => info.incomingSide.dx), // 来向 x 升序，西侧进入的排前
      compare<_PathNodeInfo>((info) => info.outgoingSide.dy), // 去向 y 升序
      compare<_PathNodeInfo>((info) => info.outgoingSide.dx), // 去向 x 升序
      compare<_PathNodeInfo>((info) => info.polylineIndex), // 折线索引
      compare<_PathNodeInfo>((info) => info.nodeIndex), // 节点索引
    ]));
    // 分配车道偏移
    final int n = infos.length;
    for (int k = 0; k < n; k++) {
      final info = infos[k];
      final double t = (k + 1) / (n + 1) - 0.5; // 均匀分配偏移，范围 (-0.5, 0.5)
      laneOffsets[(info.polylineIndex, info.nodeIndex)] = axis * (t * cellSize);
    }
  }

  // 计算路径节点的实际绘制位置
  final shiftedPolylines = <List<Offset>>[];
  for (int pi = 0; pi < polylines.length; pi++) {
    final nodes = polylines[pi];
    final points = <Offset>[];
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final Offset center = cellCenter(n.x, n.y, cellSize);
      final Offset offset = laneOffsets[(pi, i)] ?? Offset.zero;
      points.add(center + offset);
    }
    shiftedPolylines.add(points);
  }
  if (shiftedPolylines.isEmpty) return;

  // 绘制折线
  final linePaint = Paint()
    ..color = color ?? pathColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.08
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final points in shiftedPolylines) {
    final route = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      route.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(route, linePaint);
  }
  // 绘制箭头
  final double arrowSize = cellSize * 0.2;
  final arrowPaint = Paint()
    ..color = color ?? pathColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = cellSize * 0.06
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final points in shiftedPolylines) {
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final v = b - a;
      final len = v.distance;
      if (len < 1e-6) continue;
      final u = v / len;
      final n = Offset(-u.dy, u.dx);
      final mid = Offset.lerp(a, b, 0.5)!;
      final tip = mid + u * (arrowSize * 0.5);
      final back = tip - u * arrowSize;
      canvas.drawLine(tip, back + n * (arrowSize * 0.6), arrowPaint);
      canvas.drawLine(tip, back - n * (arrowSize * 0.6), arrowPaint);
    }
  }
  // 绘制起点/终点标记
  if (path.first.layer == layer) {
    _drawPathStart(canvas, shiftedPolylines.first.first, cellSize);
  }
  if (path.last.layer == layer) {
    _drawPathEnd(canvas, shiftedPolylines.last.last, cellSize);
  }
}
