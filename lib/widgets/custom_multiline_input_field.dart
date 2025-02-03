import 'package:flutter/material.dart';

class CustomMultilineInputField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool error;
  final FocusNode? focusNode;
  final VoidCallback? onClearError;

  const CustomMultilineInputField({
    Key? key,
    required this.label,
    required this.hintText,
    this.controller,
    this.error = false,
    this.focusNode,
    this.onClearError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color appBlueColor = Color(0xFF0205D3);
    const Color appYellowColor = Color(0xFFFFFDD0);

    final double fieldWidth = MediaQuery.of(context).size.width - 20;

    return Container(
      width: fieldWidth < 0 ? 0 : fieldWidth,
      height: 120,
      // Error shadow (if needed)
      decoration: error
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
        ),
        textAlignVertical: TextAlignVertical.top,
        onTap: () {
          if (error && onClearError != null) {
            onClearError!();
          }
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
          floatingLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: appBlueColor,
            height:
                0.8, // 🔥 This reduces the spacing between the label and text
          ),
          hintText: hintText,
          hintStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
          filled: true,
          fillColor: appYellowColor,
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: appBlueColor, width: 1),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: appBlueColor, width: 2),
          ),
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: appBlueColor, width: 1),
          ),
          errorText: error ? ' ' : null,
          errorStyle: const TextStyle(fontSize: 0, height: 0),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8, // Keeps text inside with proper spacing
          ),
        ),
      ),
    );
  }
}
