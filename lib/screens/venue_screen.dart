import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'create_review_screen.dart';
import 'reviews_screen.dart';
import 'widgets/venue_media_section.dart';
import 'widgets/venue_screen_widgets.dart';

// venue screen
class VenueScreen extends StatelessWidget {
  final String venueId;

  const VenueScreen({
    super.key,
    required this.venueId,
  });

  Future<Map<String, dynamic>> _loadReviewSummary() async {
    // get all reviews for this venue
    final reviewsSnap = await FirebaseFirestore.instance
        .collection('venues')
        .doc(venueId)
        .collection('reviews')
        .get();

    // fallback if there are no reviews yet
    if (reviewsSnap.docs.isEmpty) {
      return {
        'average': 0.0,
        'count': 0,
      };
    }

    double total = 0;
    int count = 0;

    // add up all valid ratings so the average can be shown
    for (final doc in reviewsSnap.docs) {
      final rating = doc.data()['rating'];
      if (rating is num) {
        total += rating.toDouble();
        count++;
      }
    }

    return {
      'average': count == 0 ? 0.0 : total / count,
      'count': count,
    };
  }

  // format average rating to 1 decimal place
  String _formatAverage(double value) {
    return value.toStringAsFixed(1);
  }

  // collect tags from the different formats saved in firestore
  List<String> _extractDietTags(Map<String, dynamic> data) {
    final tags = <String>[];

    final dietTags = data['dietTags'];
    final tagList = data['tagList'];
    final tagsMap = data['tags'];

    if (dietTags is List) {
      tags.addAll(
        dietTags
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty),
      );
    }

    if (tagList is List) {
      tags.addAll(
        tagList
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty),
      );
    }

    if (tagsMap is Map) {
      // this handles true or false style tag maps like glutenFree: true
      tagsMap.forEach((key, value) {
        if (value == true) {
          final formatted = key
              .toString()
              .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
              .trim();
          if (formatted.isNotEmpty) {
            tags.add(
              formatted[0].toUpperCase() + formatted.substring(1),
            );
          }
        }
      });
    }

    // remove duplicates before showing them on screen
    return tags.toSet().toList();
  }

  // get important notes from whichever field exists
  List<String> _extractNotes(Map<String, dynamic> data) {
    final raw = (data['importantNotes'] as List?) ??
        (data['notes'] as List?) ??
        const [];

    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // add or remove favourite venue from users profile
  Future<void> _toggleFavourite({
    required BuildContext context,
    required String venueName,
    required String address,
    required bool isFavourite,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    // stop guests from saving favourites
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save favourites.'),
        ),
      );
      return;
    }

    final favouriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favourites')
        .doc(venueId);

    try {
      if (isFavourite) {
        await favouriteRef.delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$venueName removed from favourites')),
          );
        }
      } else {
        await favouriteRef.set({
          'venueId': venueId,
          'venueName': venueName,
          'address': address,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$venueName added to favourites')),
          );
        }
      }
    } catch (e) {
      // show error if favourite update fails
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update favourite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueRef = FirebaseFirestore.instance.collection('venues').doc(venueId);

    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          // listen for live changes to this venue
          stream: venueRef.snapshots(),
          builder: (context, venueSnap) {
            if (venueSnap.hasError) {
              return Center(
                child: Text(
                  'Error loading venue: ${venueSnap.error}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (venueSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (!venueSnap.hasData || !venueSnap.data!.exists) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Venue not found',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              );
            }

            // pull out venue details with safe fallbacks
            final data = venueSnap.data!.data() ?? <String, dynamic>{};
            final name = data['name']?.toString().trim().isNotEmpty == true
                ? data['name'].toString().trim()
                : 'Venue';
            final address = data['address']?.toString().trim() ?? '';
            final phone = data['phone']?.toString().trim() ?? '';
            final website = data['website']?.toString().trim() ?? '';
            final dietTags = _extractDietTags(data);
            final importantNotes = _extractNotes(data);
            final menuFiles = extractVenueMenuFiles(data);

            final location = data['location'];
            final double? lat;
            final double? lng;

            // support both geopoint and separate lat lng values
            if (location is GeoPoint) {
              lat = location.latitude;
              lng = location.longitude;
            } else {
              lat = (data['lat'] is num) ? (data['lat'] as num).toDouble() : null;
              lng = (data['lng'] is num) ? (data['lng'] as num).toDouble() : null;
            }

            final venueLatLng = (lat != null && lng != null) ? LatLng(lat, lng) : null;

            final user = FirebaseAuth.instance.currentUser;

            // watch this users favourite doc so the button updates live
            final favouriteStream = user == null
                ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
                : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('favourites')
                .doc(venueId)
                .snapshots();

            return FutureBuilder<Map<String, dynamic>>(
              // load review stats for stars and count
              future: _loadReviewSummary(),
              builder: (context, reviewSnap) {
                final average = (reviewSnap.data?['average'] as double?) ?? 0.0;
                final count = (reviewSnap.data?['count'] as int?) ?? 0;

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: favouriteStream,
                  builder: (context, favouriteSnap) {
                    final isFavourite =
                        user != null && (favouriteSnap.data?.exists ?? false);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VenueHeaderBar(
                            onBack: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 10),
                          VenueMapPreview(
                            venueId: venueId,
                            venueName: name,
                            venueLatLng: venueLatLng,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          VenueStars(average: average),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatAverage(average)} ($count)',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          GridView.count(
                            shrinkWrap: true,
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 2.15,
                            children: [
                              // action buttons
                              VenueActionButton(
                                icon: Icons.star,
                                label: 'See Reviews',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReviewsScreen(
                                        venueId: venueId,
                                        venueName: name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              VenueActionButton(
                                icon: Icons.rate_review_outlined,
                                label: 'Write Review',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreateReviewScreen(
                                        venueId: venueId,
                                        venueName: name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              VenueActionButton(
                                icon: isFavourite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                label: isFavourite
                                    ? 'Remove Favourite'
                                    : 'Add Favourite',
                                onTap: () {
                                  _toggleFavourite(
                                    context: context,
                                    venueName: name,
                                    address: address,
                                    isFavourite: isFavourite,
                                  );
                                },
                              ),
                              VenueActionButton(
                                icon: Icons.report_problem_outlined,
                                label: 'Report Issue',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Report issue coming soon'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          VenueSectionCard(
                            title: 'Important Notes',
                            child: importantNotes.isEmpty
                                ? const Text(
                              'No important notes added yet.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            )
                                : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: importantNotes.map((note) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Icon(
                                          Icons.circle,
                                          color: Colors.white70,
                                          size: 7,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          note,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          VenueSectionCard(
                            title: 'Dietary Tags',
                            child: dietTags.isEmpty
                                ? const Text(
                              'No dietary tags added yet.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            )
                                : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: dietTags
                                  .map((tag) => VenueTagChip(text: tag))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          VenueSectionCard(
                            title: 'Menu',
                            child: VenueMediaSection(menuFiles: menuFiles),
                          ),
                          const SizedBox(height: 12),
                          VenueSectionCard(
                            title: 'Contact',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (address.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      address,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                if (phone.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      phone,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                if (website.isNotEmpty)
                                  Text(
                                    website,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                if (address.isEmpty && phone.isEmpty && website.isEmpty)
                                  const Text(
                                    'No contact details added yet.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}