import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'venue_screen.dart';

// profile screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // firebase helpers
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  // photo upload state
  bool _uploading = false;

  User get _user => _auth.currentUser!;

  // user doc
  DocumentReference<Map<String, dynamic>> get _userRef =>
      _db.collection('users').doc(_user.uid);

  Stream<int> _favouritesCountStream() {
    // favourites count
    return _userRef
        .collection('favourites')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> _userReviewsCountStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    // review count
    return _db
        .collectionGroup('reviews')
        .where('uid', isEqualTo: user.uid)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  String _formatMemberSince(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();

    // readable date
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _changePhoto() async {
    // stop if already uploading
    if (_uploading) return;

    // photo options
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2E2E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag handle
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Change profile photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),

                // pick from gallery
                _sheetBtn(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose from gallery',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final x = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (x != null) await _uploadAndSave(File(x.path));
                  },
                ),
                const SizedBox(height: 10),

                // take photo
                _sheetBtn(
                  icon: Icons.photo_camera_outlined,
                  label: 'Take a photo',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final x = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (x != null) await _uploadAndSave(File(x.path));
                  },
                ),
                const SizedBox(height: 10),

                // remove photo
                _sheetBtn(
                  icon: Icons.delete_outline,
                  label: 'Remove photo',
                  danger: true,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _userRef.set({'photoUrl': ''}, SetOptions(merge: true));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    // bottom sheet button
    final color = danger ? Colors.redAccent : Colors.white;
    return Material(
      color: const Color(0xFF3A3A3A),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAndSave(File file) async {
    try {
      setState(() => _uploading = true);

      // upload photo
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(_user.uid)
          .child('profile.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // save photo url
      await _userRef.set({'photoUrl': url}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openFavourites() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FavouriteVenuesScreen()),
    );
  }

  void _openReviews() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserReviewsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    // no user
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF2B2B2B),
        body: Center(
          child: Text(
            'Not signed in',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          // profile stream
          stream: _userRef.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data!.data() ?? <String, dynamic>{};
            final username = (data['username'] ?? '@user').toString();
            final createdAt = data['createdAt'] as Timestamp?;
            final photoUrl = (data['photoUrl'] ?? '').toString();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                children: [
                  SizedBox(
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

                        // top actions
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // reviews shortcut
                              _topIcon(icon: Icons.star, onTap: _openReviews),
                              const SizedBox(width: 10),

                              // favourites shortcut
                              _topIcon(icon: Icons.favorite, onTap: _openFavourites),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // profile photo
                  GestureDetector(
                    onTap: _changePhoto,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3A3A3A),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: photoUrl.isEmpty
                            // default icon
                                ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 86,
                            )
                                : Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 86,
                              ),
                            ),
                          ),
                        ),

                        // upload overlay
                        if (_uploading)
                          Container(
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.45),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // username
                  Text(
                    username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // member since
                  Text(
                    'Member since ${_formatMemberSince(createdAt)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // favourites count
                  StreamBuilder<int>(
                    stream: _favouritesCountStream(),
                    builder: (context, c) {
                      final count = c.data ?? 0;
                      return Text(
                        'Favourites: $count',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),

                  // reviews count
                  StreamBuilder<int>(
                    stream: _userReviewsCountStream(),
                    builder: (context, c) {
                      final count = c.data ?? 0;
                      return Text(
                        'Reviews: $count',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _topIcon({required IconData icon, required VoidCallback onTap}) {
    // top icon button
    return Material(
      color: const Color(0xFF3A3A3A),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    // dark card
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}

// favourite venues screen
class FavouriteVenuesScreen extends StatelessWidget {
  const FavouriteVenuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // no user
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF2B2B2B),
        appBar: _DarkAppBar(title: 'Favourite venues'),
        body: Center(
          child: Text(
            'Not signed in',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // favourites stream
    final favouritesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favourites')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      appBar: const _DarkAppBar(title: 'Favourite venues'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: favouritesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load favourites:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          // empty favourites
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No favourite venues yet.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final venueId = (data['venueId'] ?? docs[index].id).toString();
              final venueName = (data['venueName'] ?? 'Venue').toString().trim();
              final address = (data['address'] ?? '').toString().trim();

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF515151),
                    child: Icon(Icons.favorite, color: Colors.white),
                  ),
                  title: Text(
                    venueName.isEmpty ? 'Venue' : venueName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: address.isEmpty
                      ? null
                      : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      address,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ),

                  // open venue
                  trailing: IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white70),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VenueScreen(venueId: venueId),
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VenueScreen(venueId: venueId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// user reviews screen
class UserReviewsScreen extends StatelessWidget {
  const UserReviewsScreen({super.key});

  String _venueIdFromPath(String path) {
    // get venue id from path
    final parts = path.split('/');
    final venuesIndex = parts.indexOf('venues');

    if (venuesIndex != -1 && venuesIndex + 1 < parts.length) {
      return parts[venuesIndex + 1];
    }

    return '';
  }

  int _parseRating(dynamic value) {
    // keep rating between 0 and 5
    if (value is int) return value.clamp(0, 5);
    if (value is double) return value.round().clamp(0, 5);
    if (value is num) return value.toInt().clamp(0, 5);
    return 0;
  }

  Timestamp? _bestTimestamp(Map<String, dynamic> data) {
    // use updated date first
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) return updatedAt;

    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt;

    return null;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // no user
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF2B2B2B),
        appBar: _DarkAppBar(title: 'Your reviews'),
        body: Center(
          child: Text(
            'Not signed in',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // reviews stream
    final reviewsStream = FirebaseFirestore.instance
        .collectionGroup('reviews')
        .where('uid', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      appBar: const _DarkAppBar(title: 'Your reviews'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reviewsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your reviews:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.data!.docs,
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
            return const Center(
              child: Text(
                'You have not written any reviews yet.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final venueId = _venueIdFromPath(doc.reference.path);
              final venueName = (data['venueName'] ?? 'Venue').toString().trim();
              final text = (data['text'] ?? '').toString().trim();
              final rating = _parseRating(data['rating']);
              final dateText = _formatDate(_bestTimestamp(data));

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            venueName.isEmpty ? 'Venue' : venueName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
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
                            (starIndex) => Icon(
                          starIndex < rating ? Icons.star : Icons.star_border,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // review text
                    Text(
                      text.isEmpty ? 'No review text.' : text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // view venue button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
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
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'View venue',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// dark app bar
class _DarkAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _DarkAppBar({required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF2B2B2B),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}