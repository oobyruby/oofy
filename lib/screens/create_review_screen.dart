import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  bool _loadingExisting = true;
  bool _hasExistingReview = false;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  // count words for the review limit
  int _wordCount(String s) {
    final words = s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.length;
  }

  // check the review before saving
  String? _validateReview(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) return 'Please write a review.';

    final wc = _wordCount(text);
    if (wc > 300) return 'Max 300 words (you have $wc).';

    if (_rating < 1 || _rating > 5) return 'Please choose a rating (1-5).';

    return null;
  }

  Future<void> _loadExistingReview() async {
    final user = FirebaseAuth.instance.currentUser;

    // stop loading if nobody is signed in
    if (user == null) {
      if (mounted) {
        setState(() => _loadingExisting = false);
      }
      return;
    }

    try {
      final reviewRef = FirebaseFirestore.instance
          .collection('venues')
          .doc(widget.venueId)
          .collection('reviews')
          .doc(user.uid);

      final snap = await reviewRef.get();

      if (!snap.exists) return;

      final data = snap.data() ?? {};

      // existing review
      _hasExistingReview = true;

      final savedRating = data['rating'];
      if (savedRating is num) {
        _rating = savedRating.toInt();
      }

      final savedText = data['text'];
      if (savedText is String) {
        _reviewController.text = savedText;
      }
    } catch (_) {
      // leave empty if it fails
    } finally {
      if (mounted) {
        setState(() => _loadingExisting = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;

    // stop guests from submitting reviews
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final venueRef = firestore.collection('venues').doc(widget.venueId);
      final reviewRef = venueRef.collection('reviews').doc(user.uid);

      // get username from users collection
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final username = (userData['username'] ?? '').toString().trim();

      final existing = await reviewRef.get();
      final now = FieldValue.serverTimestamp();

      // save review
      final data = <String, dynamic>{
        'uid': user.uid,
        'venueId': widget.venueId,
        'venueName': (widget.venueName ?? '').trim(),
        'username': username,
        'rating': _rating,
        'text': _reviewController.text.trim(),
        'updatedAt': now,
        if (!existing.exists) 'createdAt': now,
      };

      await reviewRef.set(data, SetOptions(merge: true));

      // recalculate average rating after save
      final reviewSnap = await venueRef.collection('reviews').get();
      double total = 0;
      int count = 0;

      for (final doc in reviewSnap.docs) {
        final rating = doc.data()['rating'];
        if (rating is num) {
          total += rating.toDouble();
          count++;
        }
      }

      // update venue rating fields so they stay in sync
      await venueRef.set({
        'ratingAvg': count == 0 ? 0 : total / count,
        'ratingCount': count,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _hasExistingReview ? 'Review updated' : 'Review saved',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save review: $e')),
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
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                if (_hasExistingReview)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2B2B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'You already reviewed this venue. You can update it here.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Text(
                  'Rating',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
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
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_wordCount(_reviewController.text)}/300 words',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 18),
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
                      : Text(
                    _hasExistingReview
                        ? 'Update review'
                        : 'Submit review',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
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

class _StarPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _StarPicker({
    required this.rating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // rating stars
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