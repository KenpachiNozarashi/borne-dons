import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Shared backdrop; a light veil preserves text contrast on uploaded photos.
class AppBackground extends StatelessWidget {
  final Uint8List? bytes;
  final Widget child;
  const AppBackground({super.key, this.bytes, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFEDEDED),
      image: DecorationImage(
        image: bytes == null
            ? const AssetImage('assets/legacy/background.jpg')
            : MemoryImage(bytes!) as ImageProvider,
        fit: BoxFit.cover,
        colorFilter: bytes == null
            ? null
            : const ColorFilter.mode(Color(0xB3FFFFFF), BlendMode.srcOver),
      ),
    ),
    child: child,
  );
}
