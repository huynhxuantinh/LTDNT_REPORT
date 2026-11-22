import 'package:flutter/material.dart';
import 'package:trek_bikes_app/api_config.dart';

class FoodImage extends StatelessWidget {
  const FoodImage({super.key, required this.imageUrl, this.size = 56});
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = imageUrl?.trim();
    final url = value == null || value.isEmpty ? null : Uri.tryParse(value);
    final resolved = url == null
        ? null
        : url.hasAuthority
        ? url
        : Uri.parse('${ApiConfig.baseUrl}/').resolveUri(url);
    Widget fallback() => Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: resolved == null || !{'http', 'https'}.contains(resolved.scheme)
            ? fallback()
            : Image.network(
                resolved.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}
