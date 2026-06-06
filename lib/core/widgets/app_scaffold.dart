/// 通用页面脚手架。
///
/// 封装了 AppBar、SafeArea、背景色等通用配置，
/// 减少各页面的重复代码。
library;

import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget body;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final PreferredSizeWidget? bottom;

  const AppScaffold({
    super.key,
    this.title,
    this.actions,
    this.leading,
    required this.body,
    this.floatingActionButton,
    this.showBackButton = false,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null || showBackButton
          ? AppBar(
              title: title != null ? Text(title!) : null,
              actions: actions,
              leading: leading,
              bottom: bottom,
              automaticallyImplyLeading: showBackButton,
            )
          : null,
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}
