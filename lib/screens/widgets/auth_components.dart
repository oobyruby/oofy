import 'package:flutter/material.dart';

// base scaffold used for auth screens (login / create account)
class AuthScaffold extends StatelessWidget {
  final Widget child;

  const AuthScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      body: SafeArea(
        child: Padding(
          // keeps spacing consistent across auth screens
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}

// header used on auth screens (back button + title + subtitle)
class AuthHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const AuthHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // back button (top left)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(-16, 0),
              child: IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_ios_new),
                color: Colors.white70,
                tooltip: 'Back',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // app name
        const Text(
          'oofy',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.0,
          ),
        ),

        const SizedBox(height: 14),

        // screen title (e.g. login / create account)
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// wraps a field with a label above it
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const LabeledField({
    super.key,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // label text
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // actual input field passed in
        child,
      ],
    );
  }
}

// styled text field used across auth screens
class DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  const DarkTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,

      // slightly dimmed text if disabled
      style: TextStyle(
        color: enabled ? Colors.white : Colors.white70,
      ),

      cursorColor: Colors.white,

      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),

        filled: true,
        fillColor: const Color(0xFF1F1F1F),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),

        suffixIcon: suffixIcon,

        // custom error styling
        errorStyle: const TextStyle(
          color: Color(0xFFFFB4B4),
          fontSize: 12,
        ),
      ),
    );
  }
}

// main button used for auth actions (login / create account)
class PrimaryPillButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const PrimaryPillButton({
    super.key,
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        // disables button while loading
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF1F1F1F),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: loading
        // shows spinner instead of text while submitting
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Colors.white,
          ),
        )
            : Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}