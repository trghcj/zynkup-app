import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DiceBearAvatar extends StatelessWidget {
  final String seed;
  final String type; // rings, neon, cyberpunk, etc.
  final double size;

  const DiceBearAvatar({
    super.key,
    required this.seed,
    this.type = 'rings',
    this.size = 80,
  });

  String get _url {
    // Map internal types to DiceBear collections
    // rings -> adventurer
    // neon -> bottts
    // cyberpunk -> avataaars
    // anime -> pixel-art
    // space -> big-smile
    
    String collection = 'adventurer';
    switch (type.toLowerCase()) {
      case 'neon':
        collection = 'bottts';
        break;
      case 'cyber':
      case 'cyberpunk':
        collection = 'avataaars';
        break;
      case 'anime':
        collection = 'pixel-art';
        break;
      case 'space':
        collection = 'big-smile';
        break;
      case 'rings':
      default:
        collection = 'adventurer';
        break;
    }

    return 'https://api.dicebear.com/7.x/$collection/svg?seed=$seed&backgroundColor=b6e3f4,c0aede,d1d4f9';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.network(
        _url,
        placeholderBuilder: (context) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2D231C),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
