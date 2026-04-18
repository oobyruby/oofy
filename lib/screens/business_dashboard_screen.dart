import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'business_edit_venue_screen.dart';
import 'business_menu_screen.dart';
import 'business_reviews_screen.dart';
import 'business_venue_overview_screen.dart';

// business dashboard screen
class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      // sign out
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      // go back through auth flow
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthGate(),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      // show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign out: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
    }
  }

  void _showSupportComingSoon(BuildContext context) {
    // placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Support coming soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // top right buttons
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF3A3A3A),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
        onPressed: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2B2B),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text(
          'Business Dashboard',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // top row layout
              Row(
                children: [
                  const SizedBox(width: 104),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'oofy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                  ),

                  // support
                  _buildCircleActionButton(
                    icon: Icons.headset_mic_rounded,
                    onTap: () => _showSupportComingSoon(context),
                  ),
                  const SizedBox(width: 8),

                  // sign out
                  _buildCircleActionButton(
                    icon: Icons.logout_rounded,
                    onTap: () => _signOut(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 36),

              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DashboardTile(
                            icon: Icons.grid_view_rounded,
                            label: 'Overview',
                            onTap: () {
                              // open overview
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const BusinessVenueOverviewScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _DashboardTile(
                            icon: Icons.edit_outlined,
                            label: 'Edit Venue',
                            onTap: () {
                              // open edit screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const BusinessEditVenueScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _DashboardTile(
                            icon: Icons.image_outlined,
                            label: 'Menu',
                            onTap: () {
                              // open menu screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BusinessMenuScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _DashboardTile(
                            icon: Icons.star_rounded,
                            label: 'Reviews',
                            onTap: () {
                              // open reviews
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BusinessReviewsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // support message
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Can’t find what you’re looking for? Contact support for help.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // dashboard tile
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 54,
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}