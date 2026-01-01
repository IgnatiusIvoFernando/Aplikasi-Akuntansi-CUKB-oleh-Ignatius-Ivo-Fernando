import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/warna_cukb.dart';
import '../../controllers/saldo_controller.dart';

class SaldoAkhirDetailPage extends StatefulWidget {
  final int id;
  final String bulan;
  final String tahun;

  const SaldoAkhirDetailPage({
    super.key,
    required this.id,
    required this.bulan,
    required this.tahun,
  });

  @override
  State<SaldoAkhirDetailPage> createState() => _SaldoAkhirDetailPageState();
}

class _SaldoAkhirDetailPageState extends State<SaldoAkhirDetailPage> {
  final SaldoAkhirController _controller = SaldoAkhirController();
  List<Map<String, dynamic>> _akunList = [];
  bool _isLoading = true;

  final Map<String, String> _bulanAngka = {
    'Januari': '01', 'Februari': '02', 'Maret': '03', 'April': '04',
    'Mei': '05', 'Juni': '06', 'Juli': '07', 'Agustus': '08',
    'September': '09', 'Oktober': '10', 'November': '11', 'Desember': '12'
  };

  @override
  void initState() {
    super.initState();
    _loadSaldoAkhir();
  }

  Future<void> _loadSaldoAkhir() async {
    setState(() => _isLoading = true);
    try {
      final bulanDigit = _bulanAngka[widget.bulan] ?? '01';
      final data = await _controller.getSaldoAkhirByPeriode(bulanDigit, widget.tahun);
      setState(() {
        _akunList = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double value) {
    if (value == 0) return "-";
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  // ================= PDF (DISAMAKAN DENGAN JURNAL UMUM) =================
  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    double totalD = 0;
    double totalK = 0;
    for (var item in _akunList) {
      totalD += (item['debit'] ?? 0).toDouble();
      totalK += (item['kredit'] ?? 0).toDouble();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("LAPORAN NERACA SALDO", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                  pw.Text("Periode: ${widget.bulan} ${widget.tahun}", style: pw.TextStyle(fontSize: 14, color: PdfColors.blueGrey700)),
                  pw.Divider(thickness: 2, color: PdfColors.blueGrey900),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
              headers: ['Nama Akun', 'Debit', 'Kredit'],
              data: [
                ..._akunList
                    .where((a) => (a['debit'] != 0 || a['kredit'] != 0))
                    .map((akun) => [
                  akun['nama'].toString(),
                  _formatCurrency((akun['debit'] ?? 0).toDouble()),
                  _formatCurrency((akun['kredit'] ?? 0).toDouble()),
                ]),
                ['TOTAL', _formatCurrency(totalD), _formatCurrency(totalK)],
              ],
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ================= EXCEL (DISAMAKAN DENGAN JURNAL UMUM) =================
  Future<void> _exportToExcel() async {
    try {
      // 1. Request Permission sederhana
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }

      setState(() => _isLoading = true);

      // 2. Buat Workbook Excel
      var workbook = excel.Excel.createExcel();
      workbook.rename(workbook.getDefaultSheet()!, 'Neraca Saldo');
      excel.Sheet sheet = workbook['Neraca Saldo'];

      // Header Style Biru Tua identik dengan Jurnal Umum
      var headerStyle = excel.CellStyle(
        backgroundColorHex: excel.ExcelColor.fromHexString('#1A5276'),
        fontColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );

      // Judul & Header Laporan
      sheet.appendRow([excel.TextCellValue("LAPORAN NERACA SALDO PERIODE: ${widget.bulan.toUpperCase()} ${widget.tahun}")]);

      List<excel.TextCellValue> headers = [
        excel.TextCellValue('Nama Akun'),
        excel.TextCellValue('Debit'),
        excel.TextCellValue('Kredit'),
      ];
      sheet.appendRow(headers);

      // Warnai Header
      var headerRowIdx = sheet.maxRows - 1;
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRowIdx));
        cell.cellStyle = headerStyle;
      }

      // 3. Masukkan Data Akun
      double totalD = 0;
      double totalK = 0;

      for (var data in _akunList) {
        double d = (data['debit'] ?? 0).toDouble();
        double k = (data['kredit'] ?? 0).toDouble();
        if (d == 0 && k == 0) continue; // Lewati jika saldo kosong

        sheet.appendRow([
          excel.TextCellValue(data['nama'].toString()),
          excel.DoubleCellValue(d),
          excel.DoubleCellValue(k),
        ]);
        totalD += d;
        totalK += k;
      }

      // Baris Total
      sheet.appendRow([
        excel.TextCellValue("TOTAL"),
        excel.DoubleCellValue(totalD),
        excel.DoubleCellValue(totalK),
      ]);

      var totalRowIdx = sheet.maxRows - 1;
      for (int i = 0; i < 3; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: totalRowIdx)).cellStyle = headerStyle;
      }

      // 4. Penentuan Path & Nama File (Cara sederhana Jurnal Umum)
      // Hindari spasi pada nama file untuk meminimalisir error OS
      String cleanPeriode = "${widget.bulan}_${widget.tahun}".replaceAll(' ', '_');
      String fileName = "Neraca_Saldo_$cleanPeriode.xlsx";

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final filePath = "${directory!.path}/$fileName";
      final fileBytes = workbook.save();

      if (fileBytes != null) {
        // Tulis file
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Berhasil diunduh: $fileName"),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: "BUKA",
                textColor: Colors.white,
                onPressed: () => OpenFile.open(filePath),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal Export: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    // Bagian build UI tetap sama persis sesuai permintaan "Jangan ubah UI"
    double totalDebit = 0;
    double totalKredit = 0;
    for (var item in _akunList) {
      totalDebit += (item['debit'] ?? 0).toDouble();
      totalKredit += (item['kredit'] ?? 0).toDouble();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.penanda,
        title: const Text("Akuntansi", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadiusGeometry.circular(8),
                color: AppColors.list_period,
              ),
              child: Text(
                "NERACA SALDO PERIODE ${widget.bulan.toUpperCase()} ${widget.tahun}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.penanda, width: 1),
              ),
              child: Table(
                border: TableBorder.all(color: AppColors.penanda),
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppColors.layar_primer),
                    children: [
                      _buildCell("Nama Akun", isHeader: true),
                      _buildCell("Debit", isHeader: true),
                      _buildCell("Kredit", isHeader: true),
                    ],
                  ),
                  ..._akunList.where((a) => (a['debit'] != 0 || a['kredit'] != 0)).map((akun) {
                    return TableRow(
                      children: [
                        _buildCell(akun['nama'].toString()),
                        _buildCell(_formatCurrency((akun['debit'] ?? 0).toDouble()), align: TextAlign.right),
                        _buildCell(_formatCurrency((akun['kredit'] ?? 0).toDouble()), align: TextAlign.right),
                      ],
                    );
                  }).toList(),
                  TableRow(
                    decoration: const BoxDecoration(color: AppColors.layar_primer),
                    children: [
                      _buildCell("TOTAL", isHeader: true),
                      _buildCell(_formatCurrency(totalDebit), isHeader: true, align: TextAlign.right),
                      _buildCell(_formatCurrency(totalKredit), isHeader: true, align: TextAlign.right),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(AppColors.print, Icons.print, _generatePdf),
                const SizedBox(width: 20),
                _actionButton(AppColors.excel, FontAwesomeIcons.fileExcel, _exportToExcel),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: AppColors.penanda,
        ),
      ),
    );
  }

  Widget _actionButton(Color color, IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Icon(icon, color: Colors.black, size: 22),
    );
  }
}