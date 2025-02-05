import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomInputField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool error;
  final FocusNode? focusNode;
  final VoidCallback? onClearError;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;

  const CustomInputField({
    Key? key,
    required this.label,
    required this.hintText,
    this.controller,
    this.error = false,
    this.focusNode,
    this.onClearError,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color appBlueColor = Color(0xFF0205D3);
    const Color appYellowColor = Color(0xFFFFFDD0);
    final double fieldWidth = MediaQuery.of(context).size.width - 20;
    return Container(
      width: fieldWidth < 0 ? 0 : fieldWidth,
      height: 40,
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
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
        ),
        textAlignVertical: TextAlignVertical.center,
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
          ),
          hintText: hintText,
          hintStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
          prefixText: prefixText,
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
            vertical: 8,
          ),
        ),
      ),
    );
  }
}
