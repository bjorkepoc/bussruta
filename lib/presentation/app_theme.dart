import 'package:flutter/material.dart';

enum AppBannerTone { info, success, fail }

enum AppSurfaceTone { dark, cream, accent }

class AppTheme {
  const AppTheme._();

  static const Color feltGreen = Color(0xFF0E3B2F);
  static const Color deepGreen = Color(0xFF153F33);
  static const Color charcoal = Color(0xFF1B1F1E);
  static const Color surface = Color(0xFF232927);
  static const Color surfaceHigh = Color(0xFF2C3431);
  static const Color cream = Color(0xFFF5F2E9);
  static const Color gold = Color(0xFFD4AF37);
  static const Color copper = Color(0xFFB87333);
  static const Color success = Color(0xFF2ECC71);
  static const Color danger = Color(0xFFE74C3C);

  static const LinearGradient tableGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[charcoal, deepGreen, feltGreen],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[surfaceHigh, surface],
  );

  static BoxDecoration tableBackground() {
    return const BoxDecoration(gradient: tableGradient);
  }

  static ThemeData buildTheme() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      secondary: copper,
      tertiary: success,
      error: danger,
      surface: surface,
      onPrimary: charcoal,
      onSecondary: cream,
      onSurface: cream,
    );
    final TextTheme textTheme = ThemeData.dark().textTheme.apply(
      bodyColor: cream,
      displayColor: cream,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: charcoal,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: deepGreen,
        foregroundColor: cream,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cream,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cream.withValues(alpha: 0.08)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: deepGreen,
        disabledColor: surface.withValues(alpha: 0.55),
        labelStyle: const TextStyle(color: cream, fontWeight: FontWeight.w700),
        secondaryLabelStyle: const TextStyle(color: cream),
        iconTheme: const IconThemeData(color: gold, size: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: gold.withValues(alpha: 0.26)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: charcoal,
          disabledBackgroundColor: surfaceHigh,
          disabledForegroundColor: cream.withValues(alpha: 0.45),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: charcoal,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cream,
          side: BorderSide(color: gold.withValues(alpha: 0.58)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        labelStyle: TextStyle(color: cream.withValues(alpha: 0.74)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cream.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return gold;
          }
          return cream;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return gold.withValues(alpha: 0.35);
          }
          return surfaceHigh;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: gold,
        inactiveTrackColor: cream.withValues(alpha: 0.18),
        thumbColor: gold,
        overlayColor: gold.withValues(alpha: 0.18),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        dragHandleColor: gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceHigh,
        textStyle: const TextStyle(color: cream),
        iconColor: gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cream.withValues(alpha: 0.08)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cream.withValues(alpha: 0.12),
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: cream),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Color bannerColor(AppBannerTone tone) {
    return switch (tone) {
      AppBannerTone.info => deepGreen,
      AppBannerTone.success => const Color(0xFF176B3B),
      AppBannerTone.fail => const Color(0xFF9E2F2F),
    };
  }

  static IconData bannerIcon(AppBannerTone tone) {
    return switch (tone) {
      AppBannerTone.info => Icons.info_outline,
      AppBannerTone.success => Icons.check_circle_outline,
      AppBannerTone.fail => Icons.error_outline,
    };
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.tone = AppSurfaceTone.dark,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final AppSurfaceTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Color background = switch (tone) {
      AppSurfaceTone.dark => AppTheme.surface,
      AppSurfaceTone.cream => AppTheme.cream,
      AppSurfaceTone.accent => AppTheme.deepGreen,
    };
    final Color border = switch (tone) {
      AppSurfaceTone.dark => AppTheme.cream.withValues(alpha: 0.10),
      AppSurfaceTone.cream => AppTheme.copper.withValues(alpha: 0.22),
      AppSurfaceTone.accent => AppTheme.gold.withValues(alpha: 0.34),
    };
    final Color foreground = switch (tone) {
      AppSurfaceTone.cream => AppTheme.charcoal,
      AppSurfaceTone.dark || AppSurfaceTone.accent => AppTheme.cream,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: foreground),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    required this.tone,
    this.icon,
  });

  final String message;
  final AppBannerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color color = AppTheme.bannerColor(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cream.withValues(alpha: 0.28)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon ?? AppTheme.bannerIcon(tone),
                color: AppTheme.cream,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.cream,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final double maxWidth = MediaQuery.sizeOf(context).width - 48;
    final double chipMaxWidth = maxWidth.clamp(160.0, 360.0).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: chipMaxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.34)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: AppTheme.gold),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
