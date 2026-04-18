import 'package:flutter/material.dart';

// bottom navigation bar used across the app
class OofyBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const OofyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),

        // top border + slight shadow to separate from screen
        border: Border(
          top: BorderSide(
            color: Color(0xFF313131),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // each icon maps to a tab index
              NavIcon(
                icon: Icons.map,
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              NavIcon(
                icon: Icons.info,
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              NavIcon(
                icon: Icons.star,
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              NavIcon(
                icon: Icons.person,
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              NavIcon(
                icon: Icons.settings,
                isSelected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// single icon inside the bottom nav
class NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const NavIcon({
    super.key,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // makes tap area easier to hit
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,

            // small visual feedback when selected
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: isSelected ? 31 : 29,
            ),
          ),
        ),
      ),
    );
  }
}