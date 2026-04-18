import 'package:flutter/material.dart';

// main screen that shows important info about how to use venue data safely
class ImportantInfoScreen extends StatelessWidget {
  const ImportantInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // colour palette (kept consistent with rest of app)
    const bg = Color(0xFF232323);
    const card = Color(0xFF1A1A1A);
    const pill = Color(0xFF3A3A3A);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          // main screen padding
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // app title at top
              const Text(
                'oofy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 18),

              // pill-style section header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: pill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Important Info',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // scrollable content so text doesn't overflow on smaller screens
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // main info card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // section title
                            Text(
                              'Please read before using venue information',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            SizedBox(height: 14),

                            // explanation of what the app does
                            Text(
                              'Oofy aims to help users find venues that may be suitable for different dietary requirements by showing researched information, tags, notes, and user reviews where available.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),

                            SizedBox(height: 14),

                            // limitation disclaimer (cannot guarantee safety)
                            Text(
                              'Although every effort is made to keep this information as accurate and useful as possible, venue menus, ingredients, suppliers, and preparation methods can change. Because of this, we cannot guarantee that any venue listed is completely safe for every user.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),

                            SizedBox(height: 14),

                            // advice to check with venue directly
                            Text(
                              'We encourage contacting the venue in advance or speaking directly with '
                                  'staff when you arrive to confirm allergen information, ingredients,'
                                  ' and how food is prepared.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),

                            SizedBox(height: 14),

                            // emphasis on higher-risk conditions
                            Text(
                              'This is especially important for anyone with allergies, coeliac disease, or other conditions where cross-contamination may be a risk.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // smaller supporting info box with icon
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // info icon for visual cue
                            Icon(
                              Icons.info_outline,
                              color: Colors.white70,
                              size: 20,
                            ),

                            SizedBox(width: 10),

                            // short summary message
                            Expanded(
                              child: Text(
                                'Oofy is designed to be a support tool to help find venues, but cannot guarantee every venue is 100% safe. ',

                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                  height: 1.45,
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
            ],
          ),
        ),
      ),
    );
  }
}