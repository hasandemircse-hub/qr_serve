import 'dart:convert';

/// Wire payload: `FLOOR_LAYOUT_SNAPSHOT` (see `schemas/floor_layout.schema.json`).
class FloorLayoutSnapshot {
  FloorLayoutSnapshot({
    required this.type,
    required this.schemaVersion,
    required this.restaurantId,
    required this.generatedAt,
    required this.floors,
  });

  final String type;
  final int schemaVersion;
  final String restaurantId;
  final String generatedAt;
  final List<FloorLayoutFloor> floors;

  static FloorLayoutSnapshot fromJson(Map<String, dynamic> json) {
    return FloorLayoutSnapshot(
      type: json['type'] as String? ?? '',
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      restaurantId: json['restaurantId'] as String? ?? '',
      generatedAt: json['generatedAt'] as String? ?? '',
      floors: (json['floors'] as List<dynamic>? ?? [])
          .map((e) => FloorLayoutFloor.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static FloorLayoutSnapshot? tryParse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['type'] != 'FLOOR_LAYOUT_SNAPSHOT') return null;
      return FloorLayoutSnapshot.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

class FloorLayoutFloor {
  FloorLayoutFloor({
    required this.floorIndex,
    required this.label,
    required this.tables,
  });

  final int floorIndex;
  final String label;
  final List<TableLayoutNode> tables;

  factory FloorLayoutFloor.fromJson(Map<String, dynamic> json) {
    return FloorLayoutFloor(
      floorIndex: (json['floorIndex'] as num).toInt(),
      label: json['label'] as String,
      tables: (json['tables'] as List<dynamic>)
          .map((e) => TableLayoutNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum TableShape { square, round }

enum TableAvailability { empty, occupied, reserved }

class TableLayoutNode {
  TableLayoutNode({
    required this.tableId,
    required this.label,
    required this.shape,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.floorIndex,
    this.groupId,
    required this.availability,
    this.seatCount,
    this.zone,
    this.rotation = 0,
  });

  final String tableId;
  final String label;
  final TableShape shape;
  final double x;
  final double y;
  final double width;
  final double height;
  final int floorIndex;
  final String? groupId;
  final TableAvailability availability;
  final int? seatCount;
  final String? zone;
  final double rotation;

  TableLayoutNode copyWith({
    String? tableId,
    String? label,
    TableShape? shape,
    double? x,
    double? y,
    double? width,
    double? height,
    int? floorIndex,
    String? groupId,
    TableAvailability? availability,
    int? seatCount,
    String? zone,
    double? rotation,
  }) {
    return TableLayoutNode(
      tableId: tableId ?? this.tableId,
      label: label ?? this.label,
      shape: shape ?? this.shape,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      floorIndex: floorIndex ?? this.floorIndex,
      groupId: groupId ?? this.groupId,
      availability: availability ?? this.availability,
      seatCount: seatCount ?? this.seatCount,
      zone: zone ?? this.zone,
      rotation: rotation ?? this.rotation,
    );
  }

  factory TableLayoutNode.fromJson(Map<String, dynamic> json) {
    final shapeRaw = (json['shape'] as String?)?.toUpperCase() ?? 'SQUARE';
    final availRaw =
        (json['availabilityStatus'] as String?)?.toUpperCase() ?? 'EMPTY';
    return TableLayoutNode(
      tableId: json['tableId'] as String,
      label: json['label'] as String,
      shape: shapeRaw == 'ROUND' ? TableShape.round : TableShape.square,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      floorIndex: (json['floorIndex'] as num).toInt(),
      groupId: json['groupId'] as String?,
      availability: switch (availRaw) {
        'OCCUPIED' => TableAvailability.occupied,
        'RESERVED' => TableAvailability.reserved,
        _ => TableAvailability.empty,
      },
      seatCount: (json['seatCount'] as num?)?.toInt(),
      zone: json['zone'] as String?,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    );
  }
}
