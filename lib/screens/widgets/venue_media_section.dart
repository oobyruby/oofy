import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// gets menu files from the venue data
List<String> extractVenueMenuFiles(Map<String, dynamic> data) {
  final files = <String>[];

  final menuImages = data['menuImages'];
  final image = data['image'];
  final imageUrl = data['imageUrl'];
  final menuImage = data['menuImage'];
  final menuImageUrl = data['menuImageUrl'];
  final menuPdfUrl = data['menuPdfUrl'];
  final menuFiles = data['menuFiles'];

  void addValue(dynamic value) {
    final cleaned = cleanVenueFileUrl(value?.toString() ?? '');
    if (cleaned.isNotEmpty) {
      files.add(cleaned);
    }
  }

  if (menuImages is List) {
    for (final item in menuImages) {
      addValue(item);
    }
  } else {
    addValue(menuImages);
  }

  if (menuFiles is List) {
    for (final item in menuFiles) {
      addValue(item);
    }
  } else {
    addValue(menuFiles);
  }

  for (final extra in [image, imageUrl, menuImage, menuImageUrl, menuPdfUrl]) {
    addValue(extra);
  }

  return files.toSet().toList();
}

// keeps firebase urls safe
String cleanVenueFileUrl(String value) {
  final cleaned = value.replaceAll('\n', '').replaceAll('\r', '').trim();

  if (cleaned.isEmpty || cleaned.toLowerCase() == 'null') {
    return '';
  }

  // keep full download urls exactly as they are
  if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
    return cleaned;
  }

  return cleaned;
}

// checks if the file is a pdf
bool isVenuePdfUrl(String url) {
  final lower = cleanVenueFileUrl(url).toLowerCase();
  return lower.endsWith('.pdf') ||
      lower.contains('.pdf?') ||
      lower.contains('application/pdf');
}

// turns gs urls into download urls
Future<String> resolveVenueFileUrl(String fileUrl) async {
  final cleaned = cleanVenueFileUrl(fileUrl);

  if (cleaned.isEmpty) return '';

  if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
    return cleaned;
  }

  if (!cleaned.startsWith('gs://')) {
    return cleaned;
  }

  try {
    final ref = FirebaseStorage.instance.refFromURL(cleaned);
    return await ref.getDownloadURL();
  } catch (e) {
    debugPrint('menu file resolve failed: $cleaned');
    debugPrint('menu file resolve error: $e');
    return '';
  }
}

// menu files section
class VenueMediaSection extends StatelessWidget {
  final List<String> menuFiles;

  const VenueMediaSection({
    super.key,
    required this.menuFiles,
  });

  void _openMenuFile(BuildContext context, int initialIndex) {
    if (menuFiles.isEmpty) return;

    final tappedFile = menuFiles[initialIndex].trim();

    if (tappedFile.isEmpty) return;

    if (isVenuePdfUrl(tappedFile)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenPdfViewer(
            pdfUrl: tappedFile,
          ),
        ),
      );
      return;
    }

    final imageFiles = menuFiles.where((file) => !isVenuePdfUrl(file.trim())).toList();

    if (imageFiles.isEmpty) return;

    final imageIndex = imageFiles.indexOf(tappedFile);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageGallery(
          imageUrls: imageFiles,
          initialIndex: imageIndex < 0 ? 0 : imageIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (menuFiles.isEmpty) {
      return const Text(
        'No menu files added yet.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
        ),
      );
    }

    if (menuFiles.length == 1) {
      final fileUrl = menuFiles.first;

      if (isVenuePdfUrl(fileUrl)) {
        return GestureDetector(
          onTap: () => _openMenuFile(context, 0),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFF2E2E2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 54,
                ),
                SizedBox(height: 10),
                Text(
                  'tap to open pdf menu',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return VenueImagePreviewCard(
        fileUrl: fileUrl,
        index: 0,
        total: 1,
        singleFullWidth: true,
        onTap: () => _openMenuFile(context, 0),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'tap any file to open it',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 185,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: menuFiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final fileUrl = menuFiles[index];

              if (isVenuePdfUrl(fileUrl)) {
                return GestureDetector(
                  onTap: () => _openMenuFile(context, index),
                  child: Container(
                    width: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2E2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                              SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'tap to open pdf',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${index + 1}/${menuFiles.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return VenueImagePreviewCard(
                fileUrl: fileUrl,
                index: index,
                total: menuFiles.length,
                onTap: () => _openMenuFile(context, index),
              );
            },
          ),
        ),
      ],
    );
  }
}

// image preview card
class VenueImagePreviewCard extends StatefulWidget {
  final String fileUrl;
  final int index;
  final int total;
  final VoidCallback onTap;
  final bool singleFullWidth;

  const VenueImagePreviewCard({
    super.key,
    required this.fileUrl,
    required this.index,
    required this.total,
    required this.onTap,
    this.singleFullWidth = false,
  });

  @override
  State<VenueImagePreviewCard> createState() => _VenueImagePreviewCardState();
}

class _VenueImagePreviewCardState extends State<VenueImagePreviewCard> {
  late final Future<String> _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = resolveVenueFileUrl(widget.fileUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.singleFullWidth) {
      return GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: _buildImage(),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 150,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: const Color(0xFF2E2E2E),
                  child: _buildImage(),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${widget.index + 1}/${widget.total}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return FutureBuilder<String>(
      future: _resolvedUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final url = snapshot.data?.trim() ?? '';

        if (url.isEmpty) {
          return const Center(
            child: Text(
              'Could not load image',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          );
        }

        return Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('menu image load failed: $url');
            debugPrint('menu image error: $error');
            return const Center(
              child: Text(
                'Could not load image',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }
}

// image viewer
class FullScreenImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_currentIndex + 1}/${widget.imageUrls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return FullScreenImagePage(
            imageUrl: widget.imageUrls[index],
          );
        },
      ),
    );
  }
}

// image page
class FullScreenImagePage extends StatefulWidget {
  final String imageUrl;

  const FullScreenImagePage({
    super.key,
    required this.imageUrl,
  });

  @override
  State<FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  late final Future<String> _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    _resolvedImageUrl = resolveVenueFileUrl(widget.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolvedImageUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final resolvedUrl = snapshot.data?.trim() ?? '';

        if (resolvedUrl.isEmpty) {
          return const Center(
            child: Text(
              'Could not load image',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(
              resolvedUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                debugPrint('fullscreen image load failed: $resolvedUrl');
                debugPrint('fullscreen image error: $error');
                return const Text(
                  'Could not load image',
                  style: TextStyle(color: Colors.white54),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// pdf viewer
class FullScreenPdfViewer extends StatefulWidget {
  final String pdfUrl;

  const FullScreenPdfViewer({
    super.key,
    required this.pdfUrl,
  });

  @override
  State<FullScreenPdfViewer> createState() => _FullScreenPdfViewerState();
}

class _FullScreenPdfViewerState extends State<FullScreenPdfViewer> {
  late final Future<String> _resolvedPdfUrl;

  @override
  void initState() {
    super.initState();
    _resolvedPdfUrl = resolveVenueFileUrl(widget.pdfUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: _resolvedPdfUrl,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final resolvedUrl = snapshot.data?.trim() ?? '';

          if (resolvedUrl.isEmpty) {
            return const Center(
              child: Text(
                'Could not load pdf',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return SfPdfViewer.network(
            resolvedUrl,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            onDocumentLoadFailed: (details) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not load pdf: ${details.description}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
