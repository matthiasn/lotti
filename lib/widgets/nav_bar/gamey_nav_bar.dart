import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/themes/gamey/gamey_theme.dart';

/// Feature-specific colors for navigation bar items.
/// Uses label-based lookup for robustness against navigation order changes.
class _NavBarColors {
  _NavBarColors._();

  /// Color mapping by nav item label (case-insensitive).
  /// This approach is more robust than index-based mapping.
  static const Map<String, Color> _colorsByLabel = {
    'tasks': GameyColors.primaryOrange,
    'calendar': GameyColors.primaryBlue,
    'habits': GameyColors.habitPink,
    'dashboards': GameyColors.primaryPurple,
    'journal': GameyColors.journalTeal,
    'settings': GameyColors.primaryGreen,
  };

  /// Get color for a navigation item by its label.
  /// Falls back to primaryBlue for unknown labels.
  static Color forLabel(String? label) {
    if (label == null || label.isEmpty) {
      return GameyColors.primaryBlue;
    }
    return _colorsByLabel[label.toLowerCase()] ?? GameyColors.primaryBlue;
  }
}

/// A premium, gamey-styled bottom navigation bar with:
/// - Floating pill design with glassmorphism
/// - Vibrant gradient backgrounds on selected items
/// - Animated icon transitions with bounce effects
/// - Glowing selection indicators
/// - Haptic feedback on interactions
class GameyBottomNavigationBar extends StatefulWidget {
  const GameyBottomNavigationBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<GameyBottomNavigationBar> createState() =>
      _GameyBottomNavigationBarState();
}

class _GameyBottomNavigationBarState extends State<GameyBottomNavigationBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _bounceControllers;
  late List<Animation<double>> _bounceAnimations;
  late AnimationController _selectionController;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Bounce animations for each item
    _bounceControllers = List.generate(
      widget.items.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _bounceAnimations = _bounceControllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1, end: 0.85)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.85, end: 1.15)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 50,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1.15, end: 1)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
      ]).animate(controller);
    }).toList();

    // Selection slide animation
    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didUpdateWidget(GameyBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _disposeAnimations();
      _initAnimations();
    }
    if (widget.currentIndex != oldWidget.currentIndex) {
      _selectionController.forward(from: 0);
    }
  }

  void _disposeAnimations() {
    for (final controller in _bounceControllers) {
      controller.dispose();
    }
    _selectionController.dispose();
  }

  @override
  void dispose() {
    _disposeAnimations();
    super.dispose();
  }

  void _handleTap(int index) {
    if (index == widget.currentIndex) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Trigger bounce animation
    _bounceControllers[index].forward(from: 0);

    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        // Gradient background for the entire nav bar
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF0F0F1A),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF8F9FA),
                ],
        ),
        // Top border with gradient
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: bottomPadding > 0 ? 4 : 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.items.length, (index) {
              final item = widget.items[index];
              final isSelected = index == widget.currentIndex;
              final featureColor = _NavBarColors.forLabel(item.label);

              return Expanded(
                child: _GameyNavBarItem(
                  item: item,
                  isSelected: isSelected,
                  featureColor: featureColor,
                  bounceAnimation: _bounceAnimations[index],
                  onTap: () => _handleTap(index),
                  isDark: isDark,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _GameyNavBarItem extends StatelessWidget {
  const _GameyNavBarItem({
    required this.item,
    required this.isSelected,
    required this.featureColor,
    required this.bounceAnimation,
    required this.onTap,
    required this.isDark,
  });

  final BottomNavigationBarItem item;
  final bool isSelected;
  final Color featureColor;
  final Animation<double> bounceAnimation;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedBuilder(
        animation: bounceAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: bounceAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: isSelected
              ? BoxDecoration(
                  // Gradient pill background for selected item
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      featureColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      featureColor.withValues(alpha: isDark ? 0.15 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: featureColor.withValues(alpha: isDark ? 0.4 : 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    // Inner glow
                    BoxShadow(
                      color: featureColor.withValues(alpha: isDark ? 0.3 : 0.2),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                    // Outer glow
                    BoxShadow(
                      color:
                          featureColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      blurRadius: 20,
                    ),
                  ],
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container with glow effect
              Stack(
                alignment: Alignment.center,
                children: [
                  // Glow behind icon when selected
                  if (isSelected)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: featureColor.withValues(alpha: 0.6),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  // The icon itself
                  AnimatedScale(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    scale: isSelected ? 1.2 : 1.0,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        if (isSelected) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              featureColor,
                              Color.lerp(featureColor, Colors.white, 0.3)!,
                            ],
                          ).createShader(bounds);
                        }
                        return LinearGradient(
                          colors: [unselectedColor, unselectedColor],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcIn,
                      child: IconTheme(
                        data: const IconThemeData(
                          size: 26,
                          color: Colors.white,
                        ),
                        child: isSelected ? item.activeIcon : item.icon,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Label with gradient text when selected
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: isSelected ? 11 : 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? featureColor : unselectedColor,
                  letterSpacing: isSelected ? 0.3 : 0,
                ),
                child: Text(
                  item.label ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Animated dot indicator
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                width: isSelected ? 6 : 0,
                height: isSelected ? 6 : 0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: featureColor,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: featureColor.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
