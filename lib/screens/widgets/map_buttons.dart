import 'package:flutter/material.dart';

// small square button used on the map (zoom, focus, etc)
class SquareMapButton extends StatelessWidget {
  final IconData icon;
  final Future<void> Function() onTap;

  const SquareMapButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF4A4A4A),
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),

        // runs the async action when tapped
        onTap: () => onTap(),

        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// round button used for "center map" action
class RoundMapButton extends StatelessWidget {
  final Future<void> Function() onTap;

  const RoundMapButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: const Color(0xFF2F2F2F),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),

        // recenters / focuses the map
        onTap: () => onTap(),

        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            Icons.my_location,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}