import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget render gambar produk yang mendukung URL (`http`/`https`) maupun path file lokal.
/// Menampilkan ikon kategori produk secara otomatis bila kosong, file hilang, atau gagal dimuat.
class ProductImageWidget extends StatelessWidget {
  final String imageUrl;
  final String itemType;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    this.itemType = 'goods',
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
  });

  static bool isRemoteUrl(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Widget _buildFallback(BuildContext context) {
    final colors = context.posColors;
    final iconData = itemType == 'fnb_menu'
        ? Icons.restaurant_rounded
        : (itemType == 'service'
            ? Icons.design_services_rounded
            : Icons.inventory_2_rounded);
    final resolvedIconSize =
        iconSize ?? (width != null ? width! * 0.5 : 28.0);

    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? colors.surfaceElevated,
      alignment: Alignment.center,
      child: Icon(
        iconData,
        size: resolvedIconSize,
        color: iconColor ?? colors.textMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl.trim();
    Widget child;

    if (raw.isEmpty) {
      child = _buildFallback(context);
    } else if (isRemoteUrl(raw)) {
      child = Image.network(
        raw,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(context),
      );
    } else {
      final localPath = raw.toLowerCase().startsWith('file://')
          ? Uri.parse(raw).toFilePath()
          : raw;
      final file = File(localPath);
      if (file.existsSync()) {
        child = Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(context),
        );
      } else {
        child = _buildFallback(context);
      }
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );
  }
}
