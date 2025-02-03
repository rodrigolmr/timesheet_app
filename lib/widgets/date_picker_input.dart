import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatePickerInput extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool error;
  final FocusNode? focusNode;

  const DatePickerInput({
    Key? key,
    required this.label,
    required this.hintText,
    this.controller,
    this.error = false,
    this.focusNode,
  }) : super(key: key);

  @override
  _DatePickerInputState createState() => _DatePickerInputState();
}

class _DatePickerInputState extends State<DatePickerInput> {
  late TextEditingController _localController;

  @override
  void initState() {
    super.initState();
    _localController = widget.controller ?? TextEditingController();
  }

  Future<void> _selectDate(BuildContext context) async {
    widget.focusNode?.requestFocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _localController.text = DateFormat('M/d/yy, EEEE').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color appBlueColor = Color(0xFF0205D3);
    const Color appYellowColor = Color(0xFFFFFDD0);

    final double fieldWidth = MediaQuery.of(context).size.width - 20;

    return Container(
      width: fieldWidth < 0 ? 0 : fieldWidth,
      height: 40,
      // Sombra vermelha clara se error == true
      decoration: widget.error
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
        readOnly: true,
        controller: _localController,
        focusNode: widget.focusNode,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
        ),
        textAlignVertical: TextAlignVertical.center,
        onTap: () => _selectDate(context),
        decoration: InputDecoration(
          labelText: widget.label,
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
          hintText: widget.hintText,
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
          errorText: widget.error ? ' ' : null,
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
