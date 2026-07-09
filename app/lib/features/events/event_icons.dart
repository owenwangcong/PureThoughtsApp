import 'package:flutter/material.dart';

/// 事件类型的预置图标集(event_types.icon 键 → 图标;PRD v0.5.7 §5)
/// 管理员建类型时从此集合选择。
const eventIconOptions = <String, IconData>{
  'self_improvement': Icons.self_improvement, // 靜坐
  'groups': Icons.groups, // 共修
  'record_voice_over': Icons.record_voice_over, // 講法
  'temple_buddhist': Icons.temple_buddhist, // 禪七
  'event': Icons.event, // 其它
  'menu_book': Icons.menu_book,
  'spa': Icons.spa,
  'music_note': Icons.music_note,
  'videocam': Icons.videocam,
  'local_florist': Icons.local_florist,
  'wb_sunny': Icons.wb_sunny,
  'nightlight': Icons.nightlight,
};

IconData eventIcon(String? key) => eventIconOptions[key] ?? Icons.event;
