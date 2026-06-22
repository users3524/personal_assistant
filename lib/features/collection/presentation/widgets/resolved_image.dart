import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/image_utils.dart';

class ResolvedImage extends StatefulWidget {
  final String path;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final Widget? placeholder;
  final Widget? error;

  const ResolvedImage({
    super.key,
    required this.path,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.placeholder,
    this.error,
  });

  @override
  State<ResolvedImage> createState() => _ResolvedImageState();
}

class _ResolvedImageState extends State<ResolvedImage> {
  late Future<File> _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = resolveImageFile(widget.path);
  }

  @override
  void didUpdateWidget(covariant ResolvedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _fileFuture = resolveImageFile(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _fileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder ?? _defaultPlaceholder();
        }
        final file = snapshot.data;
        if (snapshot.hasError || file == null) {
          return widget.error ?? _defaultError();
        }
        return Image.file(
          file,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          alignment: widget.alignment,
          errorBuilder: (_, __, ___) => widget.error ?? _defaultError(),
        );
      },
    );
  }

  Widget _defaultPlaceholder() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _defaultError() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: Icon(Icons.broken_image, color: AppColors.muted),
      ),
    );
  }
}
