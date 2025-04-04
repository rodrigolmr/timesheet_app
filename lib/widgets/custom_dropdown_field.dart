import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomDropdownField extends StatelessWidget {
  final String label;
  final String hintText;
  final bool error;
  final FocusNode? focusNode;
  final VoidCallback? onClearError;
  final String? prefixText;

  /// Lista de itens do dropdown. Ex: ["1234", "2345", ...]
  final List<String> items;

  /// Valor atualmente selecionado
  final String? value;

  /// Callback ao selecionar um novo valor
  final ValueChanged<String?>? onChanged;

  const CustomDropdownField({
    Key? key,
    required this.label,
    required this.hintText,
    required this.items,
    this.value,
    this.onChanged,
    this.error = false,
    this.focusNode,
    this.onClearError,
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
      // Sombrinha vermelha se error == true
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
      child: DropdownButtonFormField<String>(
        isDense: true,
        focusNode: focusNode,

        /// Se não há valor selecionado, esse `hint` aparece
        /// e aqui definimos explicitamente cor=preto (black).
        hint: Text(
          hintText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
        ),

        value: value,
        onChanged: (newValue) {
          if (error && onClearError != null) {
            onClearError!();
          }
          if (onChanged != null) {
            onChanged!(newValue);
          }
        },
        items: items.map((itemValue) {
          return DropdownMenuItem(
            value: itemValue,
            child: Text(itemValue),
          );
        }).toList(),

        /// Aqui configuramos a `InputDecoration` para ter label, borda etc.
        /// Mas NÃO use `hintText:` nela, pois vai conflitar com o hint do dropdown.
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
          // Removemos o hintText daqui para evitar conflito
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
