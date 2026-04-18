import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'business_dashboard_screen.dart';
import 'business_venue_loader.dart';

// back button
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2E2E2E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const BusinessDashboardScreen(),
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// business reviews screen
class BusinessReviewsScreen extends StatefulWidget {
  const BusinessReviewsScreen({super.key});

  @override
  State<BusinessReviewsScreen> createState() => _BusinessReviewsScreenState();
}

class _BusinessReviewsScreenState extends State<BusinessReviewsScreen> {
  bool _isLoading = true;
  String? _managedVenueId;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final result = await BusinessVenueLoader.loadManagedVenue();

      if (!mounted) return;

      if (result.hasError) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage!)),
        );
        return;
      }

      _managedVenueId = result.venueId;

      // newest first
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('venues')
          .doc(_managedVenueId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _reviews = reviewsSnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reviews: $e')),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'No date';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }
    return 'No date';
  }

  String _getReviewerName(Map<String, dynamic> data) {
    final possibleName = data['userName'] ??
        data['username'] ??
        data['name'] ??
        data['reviewerName'];

    if (possibleName == null || possibleName.toString().trim().isEmpty) {
      return 'Anonymous';
    }
    return possibleName.toString();
  }

  Future<void> _reportIssue(String reviewId) async {
    try {
      if (_managedVenueId == null) return;

      // flag review
      await FirebaseFirestore.instance
          .collection('venues')
          .doc(_managedVenueId)
          .collection('reviews')
          .doc(reviewId)
          .set({
        'reported': true,
        'reportedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review flagged for follow-up.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report issue: $e')),
      );
    }
  }

  Widget _buildReviewCard(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final reviewerName = _getReviewerName(data);
    final createdAt = _formatDate(data['createdAt']);
    final reviewText = (data['text'] ?? '').toString().trim();
    final displayText =
    reviewText.isEmpty ? 'No review text available.' : reviewText;

    // review stars
    final ratingRaw = data['rating'];
    final rating =
    ratingRaw is num ? ratingRaw.toInt().clamp(0, 5) : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // name and date
          Row(
            children: [
              Expanded(
                child: Text(
                  reviewerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                createdAt,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          // stars
          if (rating > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                    (i) => Icon(
                  i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          Text(
            displayText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          // report review
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _reportIssue(doc.id),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text(
                'Report Issue',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF222222),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // back button
                const _BackButton(),

                const SizedBox(height: 22),

                const Center(
                  child: Text(
                    'Reviews',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                if (_reviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No reviews yet for this venue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else
                  ..._reviews.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildReviewCard(doc),
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}