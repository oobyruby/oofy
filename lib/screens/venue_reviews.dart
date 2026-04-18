import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// venue reviews section
class VenueReviewsSection extends StatelessWidget {
  final String venueId;
  final String? venueName;

  const VenueReviewsSection({
    super.key,
    required this.venueId,
    this.venueName,
  });

  Timestamp? _bestTimestamp(Map<String, dynamic> data) {
    // use updated date first
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) return updatedAt;

    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // reviews for this venue
    final reviewsStream = FirebaseFirestore.instance
        .collection('venues')
        .doc(venueId)
        .collection('reviews')
        .snapshots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Reviews',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // write review button
            _WriteReviewButton(
              venueId: venueId,
              venueName: venueName,
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: reviewsStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Couldn’t load reviews: ${snap.error}',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }

            final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              snap.data?.docs ?? [],
            );

            // newest first
            docs.sort((a, b) {
              final aTs = _bestTimestamp(a.data());
              final bTs = _bestTimestamp(b.data());

              final aMillis = aTs?.millisecondsSinceEpoch ?? 0;
              final bMillis = bTs?.millisecondsSinceEpoch ?? 0;

              return bMillis.compareTo(aMillis);
            });

            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No reviews yet — be the first!',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            // review cards
            return Column(
              children: docs.map((d) => ReviewCard(review: d)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _WriteReviewButton extends StatelessWidget {
  final String venueId;
  final String? venueName;

  const _WriteReviewButton({
    required this.venueId,
    required this.venueName,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3A3A3A),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: () async {
        final user = FirebaseAuth.instance.currentUser;

        // user must be logged in
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to write a review.')),
          );
          return;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateReviewScreen(
              venueId: venueId,
              venueName: venueName,
            ),
          ),
        );
      },
      child: const Text(
        'Write review',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

// create review screen
class CreateReviewScreen extends StatefulWidget {
  final String venueId;
  final String? venueName;

  const CreateReviewScreen({
    super.key,
    required this.venueId,
    this.venueName,
  });

  @override
  State<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends State<CreateReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  int _wordCount(String s) {
    // word count
    final words = s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.length;
  }

  String? _validateReview(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) return 'Please write a review.';

    final wc = _wordCount(text);
    if (wc > 300) return 'Max 300 words (you have $wc).';

    if (_rating < 1 || _rating > 5) return 'Please choose a rating (1–5).';

    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;

    // no signed in user
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return;
    }

    // stop if form is invalid
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final venueRef =
      FirebaseFirestore.instance.collection('venues').doc(widget.venueId);

      // one review per user
      final reviewRef = venueRef.collection('reviews').doc(user.uid);

      // get username
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final username = (userDoc.data()?['username'] ?? '').toString().trim();

      final now = Timestamp.now();
      final existing = await reviewRef.get();

      final data = <String, dynamic>{
        'uid': user.uid,
        'venueId': widget.venueId,
        'venueName': (widget.venueName ?? '').trim(),
        'username': username.isEmpty ? null : username,
        'rating': _rating,
        'text': _reviewController.text.trim(),
        'updatedAt': now,
        if (!existing.exists) 'createdAt': now,
      };

      // save review
      await reviewRef.set(data, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review saved ✅')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t save review: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.venueName?.trim().isNotEmpty == true
        ? 'Review: ${widget.venueName}'
        : 'Write a review';

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text(
                  'Rating',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),

                // star picker
                _StarPicker(
                  rating: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Your review (max 300 words)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),

                // review text
                TextFormField(
                  controller: _reviewController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 7,
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF2B2B2B),
                    hintText: 'What was it like?',
                    hintStyle: const TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: _validateReview,
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),

                // word count
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_wordCount(_reviewController.text)}/300 words',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 18),

                // submit button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3A3A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Submit review',
                    style: TextStyle(fontWeight: FontWeight.w900),
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

class _StarPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _StarPicker({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // rating picker
    return Row(
      children: List.generate(5, (i) {
        final index = i + 1;
        final filled = index <= rating;

        return IconButton(
          onPressed: () => onChanged(index),
          icon: Icon(
            filled ? Icons.star : Icons.star_border,
            color: Colors.white,
          ),
        );
      }),
    );
  }
}

// review card
class ReviewCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> review;

  const ReviewCard({super.key, required this.review});

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review.data();

    final uid = (r['uid'] ?? widget.review.id).toString();
    final username = (r['username'] ?? '').toString().trim();

    // username or uid fallback
    final handle = username.isNotEmpty ? '@$username' : '@${_shortUid(uid)}';

    final rating = (r['rating'] is int)
        ? (r['rating'] as int)
        : int.tryParse(r['rating']?.toString() ?? '') ?? 0;

    final text = (r['text'] ?? '').toString().trim();

    final ts = (r['updatedAt'] ?? r['createdAt']);
    final when = _formatDate(ts);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF3A3A3A),
              child: Icon(Icons.person, color: Colors.white70, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              handle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              when,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // stars
                      Text(
                        _starsText(rating),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // preview or full text
                  Text(
                    _expanded ? text : _previewText(text, maxChars: 120),
                    style: const TextStyle(color: Colors.white),
                  ),

                  if (text.length > 120) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded ? 'Read less' : 'Read more',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortUid(String uid) {
    // short fallback name
    if (uid.isEmpty) return 'user';
    return uid.length <= 6 ? uid : uid.substring(0, 6);
  }

  static String _previewText(String text, {required int maxChars}) {
    // short preview
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars).trimRight()}…';
  }

  static String _starsText(int rating) {
    // stars as text
    final r = rating.clamp(0, 5);
    return List.generate(5, (i) => i < r ? '★' : '☆').join();
  }

  static String _formatDate(dynamic ts) {
    try {
      DateTime dt;

      if (ts is Timestamp) {
        dt = ts.toDate();
      } else if (ts is DateTime) {
        dt = ts;
      } else {
        return '';
      }

      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();

      return '$dd/$mm/$yyyy';
    } catch (_) {
      return '';
    }
  }
}