import 'dart:convert';
import 'package:flutter/material.dart';

ImageProvider getAvatarImage(String? avatarName) {
  final name = avatarName ?? 'avatar_1';
  if (name.startsWith('data:image/') || name.contains(';base64,')) {
    try {
      final base64String = name.split(',').last;
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      return const AssetImage('assets/images/avatar_1.png');
    }
  }
  // Fallback for asset image
  return AssetImage('assets/images/$name.png');
}

Widget buildAvatarCircle(String? avatarName, {double radius = 24, Color backgroundColor = const Color(0xFF151211)}) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    backgroundImage: getAvatarImage(avatarName),
  );
}
