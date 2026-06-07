/// 藏品网格卡片组件。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/antique_entity.dart';

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
    final coverPath = latestPhoto ?? (item.imagePaths.isNotEmpty ? item.imagePaths.first : null);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图 — 优先最新打卡照片
            Expanded(
              child: coverPath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(coverPath),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        ),
                        if (latestPhoto != null)
                          Positioned(
                            top: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${DateTime.now().difference(item.acquiredDate).inDays}天',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.category,
                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.subtype != null && item.subtype!.isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item.subtype!,
                            style: const TextStyle(fontSize: 10, color: Colors.orange),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('${DateTime.now().difference(item.acquiredDate).inDays}天',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      const Spacer(),
                      if (item.currentValuation != null)
                        Text(
                          '¥${item.currentValuation!.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                        ),
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
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.diamond_outlined, size: 48, color: Colors.grey),
      ),
    );
  }
}
