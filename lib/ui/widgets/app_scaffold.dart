import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.appBarTitle,
    this.actions,
    this.showWalletMark = true,
    this.scrollable = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final String? appBarTitle;
  final List<Widget>? actions;
  final bool showWalletMark;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: _buildContent(context),
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: appBarTitle == null
            ? null
            : AppBar(
                title: Text(appBarTitle!),
                actions: actions,
              ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A120F),
                AppColors.background,
                Color(0xFF050A08),
              ],
            ),
          ),
          child: SafeArea(
            child: scrollable
                ? SingleChildScrollView(child: body)
                : body,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showWalletMark || title != null || subtitle != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                if (showWalletMark) const WalletMark(),
                if (title != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 26,
                        ),
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class WalletMark extends StatelessWidget {
  const WalletMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accentStrong],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.56,
              height: size * 0.38,
              decoration: BoxDecoration(
                color: const Color(0xFF052814),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Positioned(
              right: size * 0.2,
              child: Container(
                width: size * 0.24,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: const Color(0xFF09331B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Container(
                    width: size * 0.06,
                    height: size * 0.06,
                    decoration: const BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
