import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusinessEditVenueScreen extends StatefulWidget {
  const BusinessEditVenueScreen({super.key});

  @override
  State<BusinessEditVenueScreen> createState() => _BusinessEditVenueScreenState();
}

class _BusinessEditVenueScreenState extends State<BusinessEditVenueScreen> {
  // text controllers
  final TextEditingController _venueNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _openingHoursController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // venue doc id
  String? _venueDocId;

  // loading states
  bool _isLoading = true;
  bool _isSaving = false;

  // tag values
  bool _glutenFree = false;
  bool _vegetarian = false;
  bool _dairyFree = false;
  bool _vegan = false;

  @override
  void initState() {
    super.initState();
    _loadVenueData();
  }

  @override
  void dispose() {
    _venueNameController.dispose();
    _descriptionController.dispose();
    _openingHoursController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // load linked venue data
  Future<void> _loadVenueData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          _isLoading = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No logged in user found.')),
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not found.')),
        );
        return;
      }

      final userData = userDoc.data();
      final managedVenueId = userData?['managedVenueId'];

      if (managedVenueId == null || managedVenueId.toString().trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No venue linked to this business account.')),
        );
        return;
      }

      final venueDoc = await FirebaseFirestore.instance
          .collection('venues')
          .doc(managedVenueId.toString())
          .get();

      if (!venueDoc.exists) {
        setState(() {
          _isLoading = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Linked venue not found.')),
        );
        return;
      }

      final data = venueDoc.data() ?? {};
      final tags = Map<String, dynamic>.from(data['tags'] ?? {});
      final notesRaw = data['notes'];

      _venueDocId = venueDoc.id;

      _venueNameController.text = (data['name'] ?? '').toString();

      if (notesRaw is List && notesRaw.isNotEmpty) {
        _descriptionController.text = notesRaw.first.toString();
      } else {
        _descriptionController.text = '';
      }

      _openingHoursController.text = (data['openingHours'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();

      _glutenFree = tags['glutenFree'] == true;
      _vegetarian = tags['vegetarian'] == true;
      _dairyFree = tags['dairyFree'] == true;
      _vegan = tags['vegan'] == true;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load venue data: $e')),
      );
    }
  }

  // save edited venue data
  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    if (_isSaving || _venueDocId == null) return;

    final description = _descriptionController.text.trim();
    final openingHours = _openingHoursController.text.trim();
    final phone = _phoneController.text.trim();

    final Map<String, bool> tags = {
      'glutenFree': _glutenFree,
      'vegetarian': _vegetarian,
      'dairyFree': _dairyFree,
      'vegan': _vegan,
    };

    final List<String> tagList = [];
    if (_glutenFree) tagList.add('gluten free');
    if (_vegetarian) tagList.add('vegetarian');
    if (_dairyFree) tagList.add('dairy free');
    if (_vegan) tagList.add('vegan');

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('venues').doc(_venueDocId).update({
        'notes': description.isEmpty ? [] : [description],
        'openingHours': openingHours,
        'phone': phone,
        'tags': tags,
        'tagList': tagList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Venue details updated successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save changes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // open full screen text editor
  Future<void> _openFullScreenEditor({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required int minLines,
    required int maxLines,
  }) async {
    FocusScope.of(context).unfocus();

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenTextEditor(
          title: title,
          initialValue: controller.text,
          hintText: hintText,
          minLines: minLines,
          maxLines: maxLines,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      controller.text = result;
    });
  }

  // section label
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // normal text field
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.white70,
          fontSize: 18,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Colors.white38,
            fontSize: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  // tappable field for bigger text
  Widget _buildExpandableField({
    required String value,
    required String hintText,
    required VoidCallback onTap,
  }) {
    final displayText = value.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    displayText.isEmpty ? hintText : displayText,
                    style: TextStyle(
                      color: displayText.isEmpty ? Colors.white38 : Colors.white,
                      fontSize: 18,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.edit_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // checkbox row
  Widget _buildTagCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            side: const BorderSide(color: Colors.white, width: 2),
            checkColor: Colors.black,
            activeColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ],
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // top row
                Row(
                  children: [
                    Container(
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
                        icon: const Icon(
                          Icons.home_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'oofy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 34),

                const Center(
                  child: Text(
                    'Edit Venue Information',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 38),

                _buildLabel('Venue Name'),
                const SizedBox(height: 10),
                _buildInputField(
                  controller: _venueNameController,
                  hintText: 'Venue Name',
                  enabled: false,
                  suffixIcon: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.lock,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                _buildLabel('Description'),
                const SizedBox(height: 10),
                _buildExpandableField(
                  value: _descriptionController.text,
                  hintText: 'Description',
                  onTap: () async {
                    await _openFullScreenEditor(
                      title: 'Description',
                      controller: _descriptionController,
                      hintText: 'Description',
                      minLines: 8,
                      maxLines: 14,
                    );
                  },
                ),

                const SizedBox(height: 18),

                _buildLabel('Opening Hours'),
                const SizedBox(height: 10),
                _buildExpandableField(
                  value: _openingHoursController.text,
                  hintText: 'Opening Hours',
                  onTap: () async {
                    await _openFullScreenEditor(
                      title: 'Opening Hours',
                      controller: _openingHoursController,
                      hintText: 'Opening Hours',
                      minLines: 6,
                      maxLines: 12,
                    );
                  },
                ),

                const SizedBox(height: 18),

                _buildLabel('Contact Number'),
                const SizedBox(height: 10),
                _buildInputField(
                  controller: _phoneController,
                  hintText: 'Contact Number',
                ),

                const SizedBox(height: 18),

                _buildLabel('Allergen Tags'),
                const SizedBox(height: 12),

                _buildTagCheckbox(
                  label: 'Gluten free',
                  value: _glutenFree,
                  onChanged: (value) {
                    setState(() {
                      _glutenFree = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 8),

                _buildTagCheckbox(
                  label: 'Vegetarian',
                  value: _vegetarian,
                  onChanged: (value) {
                    setState(() {
                      _vegetarian = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 8),

                _buildTagCheckbox(
                  label: 'Dairy free',
                  value: _dairyFree,
                  onChanged: (value) {
                    setState(() {
                      _dairyFree = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 8),

                _buildTagCheckbox(
                  label: 'Vegan',
                  value: _vegan,
                  onChanged: (value) {
                    setState(() {
                      _vegan = value ?? false;
                    });
                  },
                ),

                const SizedBox(height: 42),

                // save button
                Center(
                  child: SizedBox(
                    width: 230,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF111111),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Center(
                  child: Text(
                    'Changes made may take a few minutes\nto update',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
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

class _FullScreenTextEditor extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hintText;
  final int minLines;
  final int maxLines;

  const _FullScreenTextEditor({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
  });

  @override
  State<_FullScreenTextEditor> createState() => _FullScreenTextEditorState();
}

class _FullScreenTextEditorState extends State<_FullScreenTextEditor> {
  // local editor controller
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF222222),
      appBar: AppBar(
        backgroundColor: const Color(0xFF222222),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _controller.text);
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                height: 1.45,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 17,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}