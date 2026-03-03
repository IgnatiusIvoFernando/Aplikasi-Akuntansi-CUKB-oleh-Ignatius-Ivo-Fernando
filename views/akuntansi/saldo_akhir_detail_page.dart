import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../config/warna_cukb.dart';
import '../../controllers/saldo_akhir_controller.dart';

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
  final SaldoAkhirController _saldoAkhirController = SaldoAkhirController();
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

  String _formatTanggal(dynamic dateSource) {
    if (dateSource == null || dateSource == "-") return "-";
    try {
      DateTime parsed = dateSource is DateTime ? dateSource : DateTime.parse(dateSource.toString());
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (e) {
      return dateSource.toString();
    }
  }

  Future<void> _loadSaldoAkhir() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final bulanDigit = _bulanAngka[widget.bulan] ?? '01';
      final data = await _saldoAkhirController.getSaldoAkhirByPeriode(bulanDigit, widget.tahun);

      if (mounted) {
        setState(() {
          _akunList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  // --- LOGIKA EXPORT EXCEL ---
  Future<void> _exportExcel() async {
    if (_akunList.isEmpty) return;
    try {
      if (Platform.isAndroid) {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        if (deviceInfo.version.sdkInt >= 30) {
          await Permission.manageExternalStorage.request();
        } else {
          await Permission.storage.request();
        }
      }

      setState(() => _isLoading = true);
      var workbook = excel_pkg.Excel.createExcel();
      workbook.rename(workbook.getDefaultSheet()!, 'Laporan_Saldo');
      excel_pkg.Sheet sheet = workbook['Laporan_Saldo'];

      // Style untuk Header
      var headerStyle = excel_pkg.CellStyle(
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#1A5276'),
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: excel_pkg.HorizontalAlign.Center,
      );

      // Judul Laporan
      sheet.appendRow([excel_pkg.TextCellValue("LAPORAN DETAIL: ${widget.bulan.toUpperCase()} ${widget.tahun}")]);
      sheet.appendRow([excel_pkg.TextCellValue("")]); // Baris Kosong

      // Header Tabel
      List<excel_pkg.TextCellValue> headers = [
        excel_pkg.TextCellValue('Tanggal'),
        excel_pkg.TextCellValue('Akun'),
        excel_pkg.TextCellValue('Pemasukan'),
        excel_pkg.TextCellValue('Pengeluaran'),
        excel_pkg.TextCellValue('Saldo'),
      ];
      sheet.appendRow(headers);

      // Terapkan Style ke Header
      var headerRowIdx = sheet.maxRows - 1;
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRowIdx)).cellStyle = headerStyle;
      }

      double runningSaldo = 0;
      for (var item in _akunList) {
        double nominal = (item['nominal_periode'] ?? 0).toDouble();
        bool isMasuk = item['kategori_tipe'] == 'Masuk';
        runningSaldo += isMasuk ? nominal : -nominal;

        sheet.appendRow([
          excel_pkg.TextCellValue(_formatTanggal(item['tanggal'])),
          excel_pkg.TextCellValue(item['nama'] ?? '-'),
          excel_pkg.DoubleCellValue(isMasuk ? nominal : 0),
          excel_pkg.DoubleCellValue(!isMasuk ? nominal : 0),
          excel_pkg.DoubleCellValue(runningSaldo),
        ]);
      }

      String fileName = "Saldo_${widget.bulan}_${widget.tahun}.xlsx";
      Directory? directory = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      final filePath = "${directory.path}/$fileName";
      final fileBytes = workbook.save();

      if (fileBytes != null) {
        File(filePath)..createSync(recursive: true)..writeAsBytesSync(fileBytes);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Excel disimpan di Download"),
              backgroundColor: Colors.green,
              action: SnackBarAction(label: "BUKA", textColor: Colors.white, onPressed: () => OpenFile.open(filePath))
          ));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error Export Excel: $e");
    }
  }

  // --- FITUR PRINT PDF ---
  Future<void> _printPdf() async {
    if (_akunList.isEmpty) return;
    final doc = pw.Document();

    double runningSaldo = 0;
    final List<List<String>> tableData = [];

    for (var item in _akunList) {
      double nominal = (item['nominal_periode'] ?? 0).toDouble();
      bool isMasuk = item['kategori_tipe'] == 'Masuk';
      runningSaldo += isMasuk ? nominal : -nominal;

      tableData.add([
        _formatTanggal(item['tanggal']),
        item['nama'] ?? '-',
        isMasuk ? _formatCurrency(nominal) : "-",
        !isMasuk ? _formatCurrency(nominal) : "-",
        _formatCurrency(runningSaldo),
      ]);
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) => [
        pw.Header(
            level: 0,
            child: pw.Text("DETAIL SALDO AKHIR - ${widget.bulan.toUpperCase()} ${widget.tahun}")
        ),
        pw.SizedBox(height: 20),
        pw.Table.fromTextArray(
          headers: ['Tanggal', 'Akun', 'Masuk', 'Keluar', 'Saldo'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
          cellAlignment: pw.Alignment.centerRight,
          cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft},
          data: tableData,
        ),
        pw.SizedBox(height: 20),
        pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text("Dicetak pada: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}")
        )
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    double totalPemasukkan = 0;
    double totalPengeluaran = 0;
    double runningSaldo = 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.penanda,
        title: const Text("Detail Saldo", style: TextStyle(color: Colors.white)),
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
                borderRadius: BorderRadius.circular(8),
                color: AppColors.penanda,
              ),
              child: Text(
                "LAPORAN PERIODE ${widget.bulan.toUpperCase()} ${widget.tahun}",
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
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(3.5),
                  2: FlexColumnWidth(3.5),
                  3: FlexColumnWidth(3.5),
                },
                border: TableBorder.all(color: AppColors.penanda),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppColors.layar_primer),
                    children: [
                      _buildCell("TANGGAL", isHeader: true, align: TextAlign.center),
                      _buildCell("PEMASUKKAN", isHeader: true, align: TextAlign.center),
                      _buildCell("PENGELUARAN", isHeader: true, align: TextAlign.center),
                      _buildCell("SALDO", isHeader: true, align: TextAlign.center),
                    ],
                  ),
                  ..._akunList.map((item) {
                    double nominal = (item['nominal_periode'] ?? 0).toDouble();
                    bool isMasuk = item['kategori_tipe'] == 'Masuk';
                    if (isMasuk) {
                      totalPemasukkan += nominal;
                      runningSaldo += nominal;
                    } else {
                      totalPengeluaran += nominal;
                      runningSaldo -= nominal;
                    }
                    return TableRow(
                      children: [
                        _buildCell(_formatTanggal(item['tanggal']), align: TextAlign.center),
                        _buildCell(isMasuk && nominal != 0 ? _formatCurrency(nominal) : "-", align: TextAlign.right),
                        _buildCell(!isMasuk && nominal != 0 ? _formatCurrency(nominal) : "-", align: TextAlign.right),
                        _buildCell(_formatCurrency(runningSaldo), align: TextAlign.right,
                            customColor: runningSaldo < 0 ? Colors.red : AppColors.penanda),
                      ],
                    );
                  }).toList(),
                  if (_akunList.isEmpty)
                    TableRow(children: [
                      _buildCell("-", align: TextAlign.center),
                      _buildCell("-", align: TextAlign.center),
                      _buildCell("-", align: TextAlign.center),
                      _buildCell("Tidak ada data", align: TextAlign.center),
                    ]),
                  TableRow(
                    decoration: const BoxDecoration(color: AppColors.layar_primer),
                    children: [
                      _buildCell("TOTAL", isHeader: true, align: TextAlign.center),
                      _buildCell(_formatCurrency(totalPemasukkan), isHeader: true, align: TextAlign.right),
                      _buildCell(_formatCurrency(totalPengeluaran), isHeader: true, align: TextAlign.right),
                      _buildCell(_formatCurrency(runningSaldo), isHeader: true, align: TextAlign.right,
                          customColor: runningSaldo < 0 ? Colors.red : AppColors.penanda),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // KEMBALIKAN TOMBOL DISINI
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _printButton(),
                const SizedBox(width: 20),
                _excelButton(),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, TextAlign align = TextAlign.left, Color? customColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 10,
          color: customColor ?? AppColors.penanda,
        ),
      ),
    );
  }

  // WIDGET TOMBOL EXCEL
  Widget _excelButton() => ElevatedButton(
      onPressed: _isLoading ? null : _exportExcel,
      style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.excel),
      child: const FaIcon(FontAwesomeIcons.fileExcel, color: Colors.black, size: 18)
  );

  // WIDGET TOMBOL PRINT
  Widget _printButton() => ElevatedButton(
      onPressed: _isLoading ? null : _printPdf,
      style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.print),
      child: const Icon(Icons.print, color: Colors.black, size: 20)
  );
}