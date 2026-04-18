
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
                size: 16,
              ),
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

// selected file before upload
class _PendingMenuFile {
  final File file;
  final String name;
  final bool isPdf;

  const _PendingMenuFile({
    required this.file,
    required this.name,
    required this.isPdf,
  });
}

// menu screen
class BusinessMenuScreen extends StatefulWidget {
  const BusinessMenuScreen({super.key});

  @override
  State<BusinessMenuScreen> createState() => _BusinessMenuScreenState();
}

class _BusinessMenuScreenState extends State<BusinessMenuScreen> {
  String? _venueDocId;

  List<String> _currentMenuFiles = [];
  List<_PendingMenuFile> _selectedFiles = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadVenueMenu();
  }

  bool _isPdfUrl(String url) {
    // check if file is a pdf
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.contains('.pdf?') ||
        lower.contains('application/pdf');
  }

  Future<void> _loadVenueMenu() async {
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

      final data = result.venueData ?? <String, dynamic>{};

      final menuFilesRaw = (data['menuImages'] as List?) ?? const [];
      final menuFiles = menuFilesRaw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // fall back to older menu fields if the main list is empty
      if (menuFiles.isEmpty) {
        final fallbackFile = (
            data['menuImageUrl'] != null &&
                data['menuImageUrl'].toString().trim().isNotEmpty)
            ? data['menuImageUrl'].toString().trim()
            : (data['image'] != null &&
            data['image'].toString().trim().isNotEmpty)
            ? data['image'].toString().trim()
            : '';

        if (fallbackFile.isNotEmpty) {
          menuFiles.add(fallbackFile);
        }
      }

      setState(() {
        _venueDocId = result.venueId;
        _currentMenuFiles = menuFiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load menu: $e')),
      );
    }
  }

  Future<void> _pickMenuFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
        allowMultiple: true,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFiles = <_PendingMenuFile>[];

      for (final picked in result.files) {
        if (picked.path == null) {
          continue;
        }

        final extension = picked.extension?.toLowerCase() ?? '';
        final isPdf = extension == 'pdf';

        pickedFiles.add(
          _PendingMenuFile(
            file: File(picked.path!),
            name: picked.name,
            isPdf: isPdf,
          ),
        );
      }

      if (pickedFiles.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read selected files.')),
        );
        return;
      }

      setState(() {
        _selectedFiles = [..._selectedFiles, ...pickedFiles];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick files: $e')),
      );
    }
  }

  Future<void> _saveMenuFiles() async {
    if (_isSaving || _venueDocId == null) return;

    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose at least one menu file first.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uploadedUrls = <String>[];

      for (final selected in _selectedFiles) {
        // upload file to storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('venue_menus')
            .child(_venueDocId!)
            .child('menu_${DateTime.now().millisecondsSinceEpoch}_${selected.name.replaceAll(' ', '_')}');

        final uploadTask = await ref.putFile(selected.file);
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);

        // tiny delay to help avoid name clashes
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final updatedMenuFiles = [..._currentMenuFiles, ...uploadedUrls];

      // keep menuimages as main field
      // keep menuimageurl there for older screens too
      await FirebaseFirestore.instance
          .collection('venues')
          .doc(_venueDocId)
          .update({
        'menuImages': updatedMenuFiles,
        'menuImageUrl': updatedMenuFiles.isNotEmpty ? updatedMenuFiles.first : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _currentMenuFiles = updatedMenuFiles;
        _selectedFiles = [];
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu files updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save menu files: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeCurrentMenuFile(int index) async {
    if (_venueDocId == null || index < 0 || index >= _currentMenuFiles.length) {
      return;
    }

    final updatedMenuFiles = [..._currentMenuFiles]..removeAt(index);

    try {
      await FirebaseFirestore.instance
          .collection('venues')
          .doc(_venueDocId)
          .update({
        'menuImages': updatedMenuFiles,
        'menuImageUrl': updatedMenuFiles.isNotEmpty ? updatedMenuFiles.first : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _currentMenuFiles = updatedMenuFiles;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu file removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove file: $e')),
      );
    }
  }

  void _openMenuFile(String fileUrl) {
    if (fileUrl.isEmpty) return;

    // open pdf or image viewer depending on file type
    if (_isPdfUrl(fileUrl)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenPdfViewer(pdfUrl: fileUrl),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(imageUrl: fileUrl),
      ),
    );
  }

  Widget _buildEmptyMenu() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, color: Colors.white38, size: 40),
            SizedBox(height: 10),
            Text(
              'No menu uploaded yet',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrokenImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      color: const Color(0xFF111111),
      child: const Center(
        child: Text(
          'Could not load menu image',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildCurrentMenuFiles() {
    if (_currentMenuFiles.isEmpty) {
      return _buildEmptyMenu();
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _currentMenuFiles.length == 1
                ? '1 file uploaded'
                : '${_currentMenuFiles.length} files uploaded',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _currentMenuFiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final fileUrl = _currentMenuFiles[index];
              final isPdf = _isPdfUrl(fileUrl);

              return SizedBox(
                width: 170,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => _openMenuFile(fileUrl),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: isPdf
                                ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.white70,
                                    size: 44,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'tap to open pdf',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : Image.network(
                              fileUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;

                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) =>
                                  _buildBrokenImagePlaceholder(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _removeCurrentMenuFile(index),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${index + 1}/${_currentMenuFiles.length}',
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUploadBox() {
    return InkWell(
      onTap: _pickMenuFiles,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: _selectedFiles.isEmpty
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_rounded, color: Colors.white54, size: 36),
                SizedBox(height: 8),
                Text(
                  'Tap to choose files',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'PNG, JPG, JPEG or PDF',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                for (int i = 0; i < _selectedFiles.length; i++) ...[
                  Row(
                    children: [
                      Icon(
                        _selectedFiles[i].isPdf
                            ? Icons.picture_as_pdf
                            : Icons.image_outlined,
                        color: Colors.white70,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFiles[i].name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedFiles.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                  if (i != _selectedFiles.length - 1)
                    const Divider(color: Colors.white10, height: 1),
                ],
              ],
            ),
          ),
        ),
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
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // current files
                const Text(
                  'Current Menu Files',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                // preview files
                _buildCurrentMenuFiles(),

                const SizedBox(height: 24),

                const Text(
                  'Upload New Menu Files',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                // pick files
                _buildUploadBox(),

                const SizedBox(height: 24),

                // save files
                Center(
                  child: SizedBox(
                    width: 230,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveMenuFiles,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4D5B47),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                        const Color(0xFF4D5B47).withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                          : const Text(
                        'Save Menu Files',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
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

// fullscreen image
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            errorBuilder: (_, __, ___) => const Text(
              'Could not load image',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}

// fullscreen pdf
class FullScreenPdfViewer extends StatelessWidget {
  final String pdfUrl;

  const FullScreenPdfViewer({
    super.key,
    required this.pdfUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        onDocumentLoadFailed: (details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load pdf: ${details.description}'),
            ),
          );
        },
      ),
    );
  }
}