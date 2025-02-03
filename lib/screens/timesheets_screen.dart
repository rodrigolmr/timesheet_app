import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_button_mini.dart';
import '../widgets/time_sheet_row.dart';
import '../services/pdf_service.dart';

class TimesheetsScreen extends StatefulWidget {
  const TimesheetsScreen({Key? key}) : super(key: key);

  @override
  State<TimesheetsScreen> createState() => _TimesheetsScreenState();
}

class _TimesheetsScreenState extends State<TimesheetsScreen> {
  bool _ordenacaoDecrescente = true;
  DateTime? _dataInicial;
  DateTime? _dataFinal;
  bool _exibirContainerOrdenacao = false;
  final Map<String, Map<String, dynamic>> _selectedTimesheets = {};

  @override
  Widget build(BuildContext context) {
    final query = _construirQueryTimesheets();
    return BaseLayout(
      title: "Time Sheet",
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Center(child: TitleBox(title: "Timesheets")),
          const SizedBox(height: 20),
          _construirBarraSuperior(context),
          if (_exibirContainerOrdenacao) ...[
            const SizedBox(height: 20),
            _construirContainerFiltros(),
          ],
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Erro ao carregar: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final dados = snapshot.data;
                if (dados == null || dados.docs.isEmpty) {
                  return const Center(
                      child: Text('Nenhum timesheet encontrado.'));
                }
                return ListView.builder(
                  itemCount: dados.docs.length,
                  itemBuilder: (context, index) {
                    final doc = dados.docs[index];
                    return _construirItemLista(doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Query<Map<String, dynamic>> _construirQueryTimesheets() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('timesheets');
    if (_dataInicial != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_dataInicial!));
    }
    if (_dataFinal != null) {
      final dataFinalAjustada = DateTime(
        _dataFinal!.year,
        _dataFinal!.month,
        _dataFinal!.day,
        23,
        59,
        59,
      );
      query = query.where('timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(dataFinalAjustada));
    }
    query = query.orderBy('timestamp', descending: _ordenacaoDecrescente);
    return query;
  }

  Widget _construirItemLista(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final jobName = data['jobName'] ?? '';
    final foreman = data['foreman'] ?? '';
    final dateStr = data['date'] ?? '';
    final Timestamp? ts = data['timestamp'];
    String dia = '';
    String mesAbreviado = '';
    if (ts != null) {
      final dataT = ts.toDate();
      dia = DateFormat('d').format(dataT);
      mesAbreviado = DateFormat('MMM').format(dataT);
    } else {
      final resultadoParse = _extrairDiaMes(dateStr);
      dia = resultadoParse['dia'] ?? '';
      mesAbreviado = resultadoParse['mes'] ?? '';
    }
    final userName = foreman.isNotEmpty ? foreman : 'User';
    final timesheetId = doc.id;
    final bool isChecked = _selectedTimesheets.containsKey(timesheetId);
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/timesheet-view',
            arguments: {'docId': timesheetId});
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: TimeSheetRowItem(
          day: dia,
          month: mesAbreviado,
          jobName: jobName,
          userName: userName,
          initialChecked: isChecked,
          onCheckChanged: (marcado) {
            setState(() {
              if (marcado) {
                _selectedTimesheets[timesheetId] = data;
              } else {
                _selectedTimesheets.remove(timesheetId);
              }
            });
          },
        ),
      ),
    );
  }

  Widget _construirBarraSuperior(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        height: 60,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CustomButton(
              type: ButtonType.newButton,
              onPressed: () {
                Navigator.pushNamed(context, '/new-time-sheet');
              },
            ),
            CustomButton(
              type: ButtonType.pdfButton,
              onPressed: _generatePdf,
            ),
            CustomMiniButton(
              type: MiniButtonType.sortMiniButton,
              onPressed: () {
                setState(() {
                  _exibirContainerOrdenacao = !_exibirContainerOrdenacao;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirContainerFiltros() {
    return Center(
      child: Container(
        width: 240,
        height: 97,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFD0DAFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _construirSecaoOrdenacaoData(),
            _construirSecaoDatas(),
          ],
        ),
      ),
    );
  }

  Widget _construirSecaoOrdenacaoData() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF0205D3), width: 2),
          ),
          child: const Text(
            "Date",
            style: TextStyle(
                color: Color(0xFF0205D3),
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _ordenacaoDecrescente = true;
                });
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _ordenacaoDecrescente
                      ? const Color(0xFF0205D3)
                      : const Color(0xFFBDBDBD),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.arrow_downward,
                    color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                setState(() {
                  _ordenacaoDecrescente = false;
                });
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: !_ordenacaoDecrescente
                      ? const Color(0xFF0205D3)
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.arrow_upward,
                  color:
                      !_ordenacaoDecrescente ? Colors.white : Colors.grey[700],
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirSecaoDatas() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _construirDateBox(
          rotulo: "Initial date",
          dataSelecionada: _dataInicial,
          aoEscolherData: (dataEscolhida) {
            setState(() {
              _dataInicial = dataEscolhida;
              if (_dataFinal != null && _dataInicial!.isAfter(_dataFinal!)) {
                _dataFinal = null;
              }
            });
          },
        ),
        const SizedBox(height: 4),
        const Text(
          "to",
          style: TextStyle(fontSize: 14, color: Color(0xFF5A5A5A)),
        ),
        const SizedBox(height: 4),
        _construirDateBox(
          rotulo: "Final date",
          dataSelecionada: _dataFinal,
          aoEscolherData: (dataEscolhida) {
            setState(() {
              _dataFinal = dataEscolhida;
              if (_dataInicial != null && _dataFinal!.isBefore(_dataInicial!)) {
                _dataInicial = null;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _construirDateBox({
    required String rotulo,
    required DateTime? dataSelecionada,
    required Function(DateTime) aoEscolherData,
  }) {
    return InkWell(
      onTap: () => _selecionarData(dataSelecionada, aoEscolherData),
      child: Container(
        width: 90,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF0205D3), width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          dataSelecionada == null
              ? rotulo
              : DateFormat('dd/MM/yyyy').format(dataSelecionada),
          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
        ),
      ),
    );
  }

  Future<void> _selecionarData(
      DateTime? valorAtual, Function(DateTime) aoEscolherData) async {
    final agora = DateTime.now();
    final dataInicial = DateTime(2000);
    final dataFinal = DateTime(2100);
    final dataInicialPicker = valorAtual ?? agora;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: dataInicialPicker,
      firstDate: dataInicial,
      lastDate: dataFinal,
    );
    if (escolhida != null) {
      aoEscolherData(escolhida);
    }
  }

  Map<String, String> _extrairDiaMes(String dataString) {
    try {
      final partes = dataString.split('/');
      if (partes.length < 2) {
        return {'dia': '', 'mes': ''};
      }
      final parteDia = partes[1];
      final diaSemVirgula = parteDia.split(',').first.trim();
      final dia = diaSemVirgula;
      final parteMes = partes[0];
      final mesNumero = int.tryParse(parteMes) ?? 0;
      final meses = {
        1: 'Jan',
        2: 'Feb',
        3: 'Mar',
        4: 'Apr',
        5: 'May',
        6: 'Jun',
        7: 'Jul',
        8: 'Aug',
        9: 'Sep',
        10: 'Oct',
        11: 'Nov',
        12: 'Dec',
      };
      final mesNome = meses[mesNumero] ?? '';
      return {'dia': dia, 'mes': mesNome};
    } catch (e) {
      return {'dia': '', 'mes': ''};
    }
  }

  Future<void> _generatePdf() async {
    if (_selectedTimesheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum timesheet selecionado!')));
      return;
    }
    try {
      await PdfService().generateTimesheetPdf(_selectedTimesheets);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF gerado com sucesso!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
