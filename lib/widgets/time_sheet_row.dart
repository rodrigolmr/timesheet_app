import 'package:flutter/material.dart';

class TimeSheetRowItem extends StatefulWidget {
  final String day;
  final String month;
  final String jobName;
  final String userName;
  final bool initialChecked;
  final ValueChanged<bool>? onCheckChanged;

  const TimeSheetRowItem({
    Key? key,
    required this.day,
    required this.month,
    required this.jobName,
    required this.userName,
    this.initialChecked = false,
    this.onCheckChanged,
  }) : super(key: key);

  @override
  State<TimeSheetRowItem> createState() => _TimeSheetRowItemState();
}

class _TimeSheetRowItemState extends State<TimeSheetRowItem> {
  bool _isChecked = false;

  @override
  void initState() {
    super.initState();
    // Define o estado local inicialmente com base na prop
    _isChecked = widget.initialChecked;
  }

  /// Se o pai mudar o `initialChecked` (por ex: "Select All"),
  /// sincronizamos `_isChecked` para refletir a nova prop.
  @override
  void didUpdateWidget(covariant TimeSheetRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialChecked != widget.initialChecked) {
      setState(() {
        _isChecked = widget.initialChecked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      child: Center(
        child: SizedBox(
          width: 328,
          child: Row(
            children: [
              // CONTAINER PRINCIPAL (borda azul) - 288px de largura
              Container(
                width: 288,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFD0), // Fundo amarelo claro
                  border: Border.all(color: const Color(0xFF0205D3), width: 1),
                  borderRadius: BorderRadius.circular(5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    // 1) DIA E MÊS (40 px)
                    Container(
                      width: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8E5FF),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(5),
                          bottomLeft: Radius.circular(5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 25,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.day,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF0000),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 16,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.month,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF000000),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 2) NOME DO JOB (170 px)
                    Container(
                      width: 170,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.jobName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF3B3B3B),
                        ),
                      ),
                    ),
                    // LINHA VERTICAL BRANCA
                    Container(
                        width: 2, height: double.infinity, color: Colors.white),
                    // 3) NOME DO USUÁRIO (72 px)
                    Container(
                      width: 72,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.userName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF3B3B3B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // CHECKBOX FORA DA BORDA AZUL - 40px
              SizedBox(
                width: 40,
                child: Center(
                  child: Checkbox(
                    value: _isChecked,
                    onChanged: (newValue) {
                      final checked = newValue ?? false;
                      setState(() {
                        _isChecked = checked;
                      });
                      // Notifica o pai
                      if (widget.onCheckChanged != null) {
                        widget.onCheckChanged!(checked);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
