import 'package:flutter/material.dart';

class UrlInputField extends StatelessWidget {
  const UrlInputField({
    super.key,
    required this.controller,
    required this.onPaste,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onPaste;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: 'https://www.tiktok.com/...',
        prefixIcon: const Icon(Icons.link_rounded),
        suffixIcon: IconButton(
          onPressed: onPaste,
          icon: const Icon(Icons.paste_rounded),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}
