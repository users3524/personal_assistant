/// 藏品网格卡片组件。
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/antique_entity.dart';
import 'resolved_image.dart';

class AntiqueGridCard extends StatelessWidget {
  final AntiqueEntity item;
  final String? latestPhoto;
  final VoidCallback onTap;

  const AntiqueGridCard({
    super.key,
    required this.item,
    this.latestPhoto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coverPath =
        latestPhoto ??
        (item.imagePaths.isNotEmpty ? item.imagePaths.first : null);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图 — 优先最新打卡照片
            Expanded(
              child: coverPath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ResolvedImage(
                          path: coverPath,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: _buildPlaceholder(),
                          error: _buildPlaceholder(),
                        ),
                        if (latestPhoto != null)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${DateTime.now().difference(item.acquiredDate).inDays}天',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : _buildPlaceholder(),
            ),
            // 信息区
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.category,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (item.subtype != null && item.subtype!.isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item.subtype!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primaryLight.withValues(alpha: 0.28),
      child: const Center(
        child: Icon(Icons.diamond_outlined, size: 48, color: AppColors.primary),
      ),
    );
  }
}
