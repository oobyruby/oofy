import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'venue_screen.dart';

// reviews screen
class ReviewsScreen extends StatelessWidget {
  final String? venueId;
  final String? venueName;

  const ReviewsScreen({
    super.key,
    this.venueId,
    this.venueName,
  });

  // single venue mode
  bool get _isVenueSpecific =>
      venueId != null && venueId!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      body: SafeArea(
        child: _ReviewsBody(
          venueId: venueId,
          venueName: venueName,
          isVenueSpecific: _isVenueSpecific,
        ),
      ),
    );
  }
}

class _ReviewsBody extends StatelessWidget {
  final String? venueId;
  final String? venueName;
  final bool isVenueSpecific;

  const _ReviewsBody({
    required this.venueId,
    required this.venueName,
    required this.isVenueSpecific,
  });

  @override
  Widget build(BuildContext context) {
    // venue reviews or all reviews
    final Stream<QuerySnapshot<Map<String, dynamic>>> reviewsStream =
    isVenueSpecific
        ? FirebaseFirestore.instance
        .collection('venues')
        .doc(venueId)
        .collection('reviews')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        : FirebaseFirestore.instance.collectionGroup('reviews').snapshots();

    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // app title
                const Center(
                  child: Text(
                    'oofy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // close button
                if (isVenueSpecific)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // screen title
        Text(
          isVenueSpecific
              ? ((venueName?.trim().isNotEmpty ?? false)
              ? '${venueName!.trim()} Reviews'
              : 'Venue Reviews')
              : 'Latest Reviews',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: reviewsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load reviews:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                snapshot.data?.docs ?? [],
              );

              // newest first
              docs.sort((a, b) {
                final aData = a.data();
                final bData = b.data();

                final aTs = _bestTimestamp(aData);
                final bTs = _bestTimestamp(bData);

                final aMillis = aTs?.millisecondsSinceEpoch ?? 0;
                final bMillis = bTs?.millisecondsSinceEpoch ?? 0;

                return bMillis.compareTo(aMillis);
              });

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    isVenueSpecific
                        ? 'No reviews for this venue yet.'
                        : 'No reviews yet.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final reviewDoc = docs[index];
                  final data = reviewDoc.data();

                  // venue id for this review
                  final derivedVenueId = isVenueSpecific
                      ? venueId!.trim()
                      : _venueIdFromPath(reviewDoc.reference.path);

                  final rawUsername =
                  (data['username'] ?? data['userName'] ?? 'username')
                      .toString()
                      .trim();

                  // add @ if missing
                  final username = rawUsername.startsWith('@')
                      ? rawUsername
                      : '@$rawUsername';

                  final reviewText = (data['text'] ?? '').toString().trim();
                  final rating = _parseRating(data['rating']);
                  final dateText = _formatDate(_bestTimestamp(data));

                  if (isVenueSpecific) {
                    final displayVenueName =
                    (venueName?.trim().isNotEmpty ?? false)
                        ? venueName!.trim()
                        : (data['venueName'] ?? 'Venue').toString().trim();

                    return _ReviewCard(
                      username: username.isEmpty ? '@username' : username,
                      venueName: displayVenueName.isEmpty
                          ? 'Venue'
                          : displayVenueName,
                      reviewText: reviewText,
                      rating: rating,
                      dateText: dateText,
                      onReadMore: () {
                        // open full review
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewDetailScreen(
                              venueId: derivedVenueId,
                              venueName: displayVenueName.isEmpty
                                  ? 'Venue'
                                  : displayVenueName,
                              username:
                              username.isEmpty ? '@username' : username,
                              reviewText: reviewText,
                              rating: rating,
                              dateText: dateText,
                            ),
                          ),
                        );
                      },
                    );
                  }

                  // get venue name if it was not saved in the review
                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: derivedVenueId.isEmpty
                        ? null
                        : FirebaseFirestore.instance
                        .collection('venues')
                        .doc(derivedVenueId)
                        .get(),
                    builder: (context, venueSnapshot) {
                      String displayVenueName =
                      (data['venueName'] ?? '').toString().trim();

                      // fallback to the venue document if review data has no venue name
                      if (displayVenueName.isEmpty &&
                          venueSnapshot.hasData &&
                          venueSnapshot.data?.data() != null) {
                        displayVenueName =
                            (venueSnapshot.data!.data()!['name'] ?? 'Venue')
                                .toString()
                                .trim();
                      }

                      if (displayVenueName.isEmpty) {
                        displayVenueName = 'Venue';
                      }

                      return _ReviewCard(
                        username: username.isEmpty ? '@username' : username,
                        venueName: displayVenueName,
                        reviewText: reviewText,
                        rating: rating,
                        dateText: dateText,
                        onReadMore: () {
                          // open full review
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewDetailScreen(
                                venueId: derivedVenueId,
                                venueName: displayVenueName,
                                username:
                                username.isEmpty ? '@username' : username,
                                reviewText: reviewText,
                                rating: rating,
                                dateText: dateText,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static Timestamp? _bestTimestamp(Map<String, dynamic> data) {
    // use updated date first
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) return updatedAt;

    // fall back to created date if updated date is missing
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt;

    return null;
  }

  static String _venueIdFromPath(String path) {
    // get venue id from path
    final parts = path.split('/');
    final venuesIndex = parts.indexOf('venues');

    if (venuesIndex != -1 && venuesIndex + 1 < parts.length) {
      return parts[venuesIndex + 1];
    }

    return '';
  }

  static int _parseRating(dynamic value) {
    // keep rating between 0 and 5
    if (value is int) return value.clamp(0, 5);
    if (value is double) return value.round().clamp(0, 5);
    if (value is num) return value.toInt().clamp(0, 5);
    return 0;
  }

  static String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }
}

class _ReviewCard extends StatelessWidget {
  final String username;
  final String venueName;
  final String reviewText;
  final int rating;
  final String dateText;
  final VoidCallback onReadMore;

  const _ReviewCard({
    required this.username,
    required this.venueName,
    required this.reviewText,
    required this.rating,
    required this.dateText,
    required this.onReadMore,
  });

  @override
  Widget build(BuildContext context) {
    // review card
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF565656),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                username,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A4A4A),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venueName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      dateText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // stars
                Row(
                  children: List.generate(
                    5,
                        (index) => Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // review preview
                Text(
                  reviewText.isEmpty ? 'No review text.' : reviewText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // read more button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onReadMore,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Read More',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ReviewDetailScreen extends StatelessWidget {
  final String venueId;
  final String venueName;
  final String username;
  final String reviewText;
  final int rating;
  final String dateText;

  const ReviewDetailScreen({
    super.key,
    required this.venueId,
    required this.venueName,
    required this.username,
    required this.reviewText,
    required this.rating,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2B2B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Review',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF4A4A4A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venueName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      dateText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // username
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                // stars
                Row(
                  children: List.generate(
                    5,
                        (index) => Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // full review
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      reviewText.isEmpty ? 'No review text.' : reviewText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // view venue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: venueId.isEmpty
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VenueScreen(venueId: venueId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'View Venue',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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