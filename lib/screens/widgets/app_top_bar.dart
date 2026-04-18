import 'package:flutter/material.dart';

// reusable top bar used across screens
// supports left button, centered title, and optional right button
class AppTopBar extends StatelessWidget {
  final VoidCallback? onLeftTap;
  final IconData leftIcon;

  final VoidCallback? onRightTap;
  final IconData? rightIcon;

  final String title;
  final bool showShadow;

  const AppTopBar({
    super.key,
    this.onLeftTap,
    this.leftIcon = Icons.home_rounded,
    this.onRightTap,
    this.rightIcon,
    this.title = 'oofy',
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // left button (defaults to back if no action given)
        _CircleButton(
          icon: leftIcon,
          onTap: onLeftTap ?? () => Navigator.pop(context),
          showShadow: showShadow,
        ),

        const Spacer(),

        // centered title
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),

        const Spacer(),

        // optional right button
        // if none is provided, keep spacing so layout stays centered
        rightIcon != null
            ? _CircleButton(
          icon: rightIcon!,
          onTap: onRightTap ?? () {},
          showShadow: showShadow,
        )
            : const SizedBox(width: 48),
      ],
    );
  }
}

// small reusable circular icon button used in the top bar
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showShadow;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.showShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        shape: BoxShape.circle,

        // optional shadow for depth
        boxShadow: showShadow
            ? const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ]
            : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onTap,
      ),
    );
  }
}