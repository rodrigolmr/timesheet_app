import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String labelText;
  final bool obscureText;

  const CustomTextField({
    Key? key,
    required this.labelText,
    this.obscureText = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 40,
      child: TextField(
        obscureText: obscureText,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Color(0xFF3D3D3D),
        ),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(
            fontSize: 16,
            color: Color(0xFFB5B5B5),
          ),
          fillColor: const Color(0xFFFEFFE4),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: Color(0xFF0C29AB),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: Color(0xFF0C29AB),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }
}
