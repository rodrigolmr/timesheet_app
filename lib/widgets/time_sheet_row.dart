import 'package:flutter/material.dart';

class TimeSheetRowItem extends StatefulWidget {
  final String day; // Ex: "26"
  final String month; // Ex: "Jan"
  final String jobName; // Ex: "Dolce amore/cipla"
  final String userName; // Ex: "Stefen"
  final bool initialChecked;

  /// Callback para notificar quando o checkbox é marcado/desmarcado
  final ValueChanged<bool>? onCheckChanged;

  const TimeSheetRowItem({
    Key? key,
    required this.day,
    required this.month,
    required this.jobName,
    required this.userName,
    this.initialChecked = false,
    this.onCheckChanged, // <-- Adicionado
  }) : super(key: key);

  @override
  State<TimeSheetRowItem> createState() => _TimeSheetRowItemState();
}

class _TimeSheetRowItemState extends State<TimeSheetRowItem> {
  bool _isChecked = false;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.initialChecked;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Desloca todo o conjunto 10px para a direita
      margin: const EdgeInsets.only(left: 10),
      child: Center(
        child: SizedBox(
          width: 328, // 288 (container azul) + 40 (checkbox) = 328 total
          child: Row(
            children: [
              // CONTAINER PRINCIPAL (borda azul) - 288px de largura
              Container(
                width: 288,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFD0), // Fundo amarelo claro
                  border: Border.all(
                    color: const Color(0xFF0205D3), // Azul
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    // 1) DIA E MÊS (40 px), arredondado à esquerda
                    Container(
                      width: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8E5FF), // Fundo lilás
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(5),
                          bottomLeft: Radius.circular(5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Dia (25 px de altura)
                          SizedBox(
                            height: 25,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.day,
                                style: const TextStyle(
                                  fontSize: 22, // Dia
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF0000), // #FF0000
                                ),
                              ),
                            ),
                          ),
                          // Mês (16 px de altura)
                          SizedBox(
                            height: 16,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.month,
                                style: const TextStyle(
                                  fontSize: 13, // Mês
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF000000), // #000000
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2) NOME DO JOB (170 px), em até 2 linhas
                    Container(
                      width: 170,
                      alignment: Alignment.center, // <-- Centraliza
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.jobName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center, // <-- Texto centralizado
                        style: const TextStyle(
                          fontSize: 13, // 13 p/ job name
                          color: Color(0xFF3B3B3B),
                        ),
                      ),
                    ),

                    // LINHA VERTICAL BRANCA (2 px)
                    Container(
                      width: 2,
                      height:
                          double.infinity, // Preenche a altura do pai (45px)
                      color: Colors.white,
                    ),

                    // 3) NOME DO USUÁRIO (72 px), arredondado à direita, em até 2 linhas
                    Container(
                      width: 72,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                      ),
                      alignment: Alignment.center, // <-- Centraliza
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.userName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center, // <-- Texto centralizado
                        style: const TextStyle(
                          fontSize: 10, // 10 p/ user
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
                      // Chama callback para notificar o "pai" que houve mudança
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
