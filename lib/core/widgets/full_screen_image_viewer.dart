import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;

  const FullScreenImageViewer({super.key, this.imageUrl, this.imageBytes}) 
    : assert(imageUrl != null || imageBytes != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: imageUrl != null 
              ? CachedNetworkImage(imageUrl: imageUrl!) 
              : Image.memory(imageBytes!),
        ),
      ),
    );
  }
}
