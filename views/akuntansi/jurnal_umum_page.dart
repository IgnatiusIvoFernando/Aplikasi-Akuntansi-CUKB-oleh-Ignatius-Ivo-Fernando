import 'dart:io';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart' hide Border;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart'; // Tambahkan ini

import '../../controllers/jurnal_controller.dart';
import '../akuntansi/edit_saldo_page.dart';
import '../../config/warna_cukb.dart';
import '../widgets/app_drawer.dart';
import '../../controllers/database_helper.dart';
import '../../controllers/akun_controller.dart';
import '../../models/jurnal_umum_header.dart';
import '../../models/jurnal_detail.dart';
import '../../models/akun.dart';

class JurnalUmumPage extends StatefulWidget {
  const JurnalUmumPage({super.key});

  @override
  State<JurnalUmumPage> createState() => _JurnalUmumPageState();
}

class _JurnalUmumPageState extends State<JurnalUmumPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AkunController _akunController = AkunController();

  List<Jurnal> _daftarJurnal = [];
  bool _isLoading = true;
  final Map<int, bool> _hapusLoadingState = {};

  @override
  void initState() {
    super.initState();
    _loadDataDariDatabase();
  }

  Future<void> _loadDataDariDatabase() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
      SELECT 
        j.id as jurnal_id, j.tanggal, j.keterangan, j.created_at,
        d.id as detail_id, d.akun_id, d.debit, d.kredit,
        a.nama as akun_nama, a.kategori_id
      FROM jurnal_umum j
      LEFT JOIN jurnal_detail d ON j.id = d.jurnal_id
      LEFT JOIN akun a ON d.akun_id = a.id
      ORDER BY j.tanggal DESC, j.id, d.id
    ''');

      if (!mounted) return;
      if (result.isEmpty) {
        setState(() { _daftarJurnal = []; _isLoading = false; });
        return;
      }

      final Map<int, Jurnal> jurnalMap = {};
      for (var row in result) {
        final jurnalId = row['jurnal_id'] as int;
        if (!jurnalMap.containsKey(jurnalId)) {
          jurnalMap[jurnalId] = Jurnal(
            id: jurnalId,
            tanggal: DateTime.parse(row['tanggal'].toString()),
            keterangan: row['keterangan'].toString(),
            details: [],
          );
        }
        if (row['detail_id'] != null) {
          jurnalMap[jurnalId]!.details.add(JurnalDetail(
            id: row['detail_id'] as int,
            jurnalId: jurnalId,
            akunId: row['akun_id'] as int,
            debit: (row['debit'] as num?)?.toDouble() ?? 0,
            kredit: (row['kredit'] as num?)?.toDouble() ?? 0,
            akun: Akun(
              id: row['akun_id'] as int,
              nama: row['akun_nama'].toString(),
              kategoriId: row['kategori_id'] as int,
            ),
          ));
        }
      }

      for (var jurnal in jurnalMap.values) { jurnal.calculateTotals(); }
      setState(() { _daftarJurnal = jurnalMap.values.toList(); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusJurnal(Jurnal jurnal, BuildContext context) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Jurnal?"),
        content: Text("Hapus jurnal tanggal ${_formatTanggal(jurnal.tanggal)}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true || jurnal.id == null) return;

    setState(() => _hapusLoadingState[jurnal.id!] = true);

    try {
      final db = await _dbHelper.database;

      // Gunakan Transaction untuk memastikan konsistensi data
      await db.transaction((txn) async {
        // 1. Hapus SEMUA detail yang berhubungan dengan jurnal_id ini
        await txn.delete(
          'jurnal_detail',
          where: 'jurnal_id = ?',
          whereArgs: [jurnal.id],
        );

        // 2. Hapus header jurnalnya
        await txn.delete(
          'jurnal_umum',
          where: 'id = ?',
          whereArgs: [jurnal.id],
        );
      });

      if (!mounted) return;

      setState(() {
        _daftarJurnal.removeWhere((j) => j.id == jurnal.id);
        _hapusLoadingState.remove(jurnal.id!);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Jurnal dan detail berhasil dihapus"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error deleting jurnal: $e');
      if (mounted) {
        setState(() => _hapusLoadingState.remove(jurnal.id!));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Map<String, List<Jurnal>> _kelompokkanPerPeriode() {
    final Map<String, List<Jurnal>> grouped = {};
    final monthNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

    for (var jurnal in _daftarJurnal) {
      final periode = '${monthNames[jurnal.tanggal.month - 1]} ${jurnal.tanggal.year}';
      grouped.putIfAbsent(periode, () => []).add(jurnal);
    }
    return grouped;
  }

  // ================= EXCEL (FIXED: DOWNLOAD FOLDER & SNACKBAR) =================
  Future<void> _exportExcel() async {
    try {
      // 1. Request Permission
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }

      setState(() => _isLoading = true);

      var workbook = excel_pkg.Excel.createExcel();
      workbook.rename(workbook.getDefaultSheet()!, 'Jurnal Umum');
      excel_pkg.Sheet sheet = workbook['Jurnal Umum'];

      var headerStyle = excel_pkg.CellStyle(
        // Gunakan ExcelColor.fromHexString untuk mengonversi string ke objek warna
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#1A5276'),
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: excel_pkg.HorizontalAlign.Center,
      );

      final jurnalByPeriode = _kelompokkanPerPeriode();

      for (var entry in jurnalByPeriode.entries) {
        sheet.appendRow([excel_pkg.TextCellValue("LAPORAN JURNAL PERIODE: ${entry.key.toUpperCase()}")]);

        List<excel_pkg.TextCellValue> headers = [
          excel_pkg.TextCellValue('Tanggal'),
          excel_pkg.TextCellValue('Keterangan'),
          excel_pkg.TextCellValue('Nama Akun'),
          excel_pkg.TextCellValue('Debit'),
          excel_pkg.TextCellValue('Kredit'),
        ];
        sheet.appendRow(headers);

        var lastRowNum = sheet.maxRows - 1;
        for (var i = 0; i < headers.length; i++) {
          var cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: lastRowNum));
          cell.cellStyle = headerStyle;
        }

        for (var jurnal in entry.value) {
          for (var detail in jurnal.details) {
            sheet.appendRow([
              excel_pkg.TextCellValue(_formatTanggal(jurnal.tanggal)),
              excel_pkg.TextCellValue(jurnal.keterangan),
              excel_pkg.TextCellValue(detail.akun?.nama ?? ''),
              excel_pkg.DoubleCellValue(detail.debit),
              excel_pkg.DoubleCellValue(detail.kredit),
            ]);
          }
        }
        sheet.appendRow([excel_pkg.TextCellValue("")]);
      }

      // 2. Tentukan Path Download Publik
      String namaPeriode = jurnalByPeriode.keys.first.replaceAll(' ', '_');

      String fileName = "Jurnal_Umum_$namaPeriode.xlsx";
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
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (mounted) {
          setState(() => _isLoading = false);
          // 3. Tampilkan Snackbar Berhasil
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Berhasil diunduh ke folder Download: $fileName"),
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

  // ================= PDF =================
  Future<void> _printPdf() async {
    final doc = pw.Document();
    final jurnalByPeriode = _kelompokkanPerPeriode();

    for (var entry in jurnalByPeriode.entries) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Header(
              level: 0,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("LAPORAN JURNAL UMUM", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                    pw.Text("Periode: ${entry.key}", style: pw.TextStyle(fontSize: 14, color: PdfColors.blueGrey700)),
                    pw.Divider(thickness: 2, color: PdfColors.blueGrey900),
                  ]
              )
          ),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
            headers: ['Tanggal', 'Keterangan', 'Akun', 'Debit', 'Kredit'],
            data: entry.value.expand((j) => j.details.map((d) => [
              _formatTanggal(j.tanggal), j.keterangan, d.akun?.nama ?? '', _formatUang(d.debit), _formatUang(d.kredit)
            ])).toList(),
            cellAlignments: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 20),
        ],
      ));
    }
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  String _formatTanggal(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  String _formatUang(double amount) {
    final formatter = NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final jurnalByPeriode = _kelompokkanPerPeriode();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text("Akuntansi", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(selectedMenu: 'jurnal'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _daftarJurnal.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerButton("Jurnal Umum"),
            const SizedBox(height: 12),
            ...jurnalByPeriode.entries.map((entry) => _periodeSection(entry.key, entry.value, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Belum ada data jurnal', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _headerButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: BoxDecoration(color: AppColors.penanda, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _periodeSection(String periode, List<Jurnal> jurnals, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
          child: Text("Periode $periode", style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        _jurnalList(jurnals, context),
        const SizedBox(height: 12),
        Row(
          children: [
            _printButton(),
            const SizedBox(width: 20),
            _excelButton(),
          ],
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _jurnalList(List<Jurnal> jurnals, BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.layar_primer.withOpacity(0.9), // Sedikit transparan
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5), // Inner glow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          thumbVisibility: true,
          child: Column(
            children: jurnals.map((jurnal) => _tabelJurnal(jurnal, context)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _tabelJurnal(Jurnal jurnal, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.layar_primer, borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF1A1A1A)), // Hitam metalik
                    headingTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    dataRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFE0D8FF)), // Lavender lebih terang
                    border: TableBorder.all(
                      color: Colors.black.withOpacity(0.2),
                      width: 1,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    columnSpacing: 24,
                    headingRowHeight: 30,
                    dataRowMinHeight: 28,
                    columns: const [
                      DataColumn(label: Text("Tanggal")),
                      DataColumn(label: Text("Akun")),
                      DataColumn(label: Text("Debit")),
                      DataColumn(label: Text("Kredit")),
                    ],
                    rows: [
                      ...jurnal.details.map((detail) {
                        return DataRow(
                          cells: [
                            DataCell(Text(_formatTanggal(jurnal.tanggal))),
                            DataCell(Text(detail.akun?.nama ?? '')),
                            DataCell(Text(_formatUang(detail.debit))),
                            DataCell(Text(_formatUang(detail.kredit))),
                          ],
                        );
                      }),
                      DataRow(
                        cells: [
                          const DataCell(Text("")),
                          const DataCell(Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(_formatUang(jurnal.totalDebit), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(_formatUang(jurnal.totalKredit), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 30),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 70,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => EditSaldoPage(jurnal: jurnal))).then((value) {
                              if (value == true) _loadDataDariDatabase();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tombol_edit,
                            elevation: 3,
                            shadowColor: AppColors.tombol_edit.withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text("Edit", style: TextStyle(color: Colors.black, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 70,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_hapusLoadingState[jurnal.id] != true) _hapusJurnal(jurnal, context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B30),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.zero,
                          ),
                          child: _hapusLoadingState[jurnal.id] == true
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              : const Text("Hapus", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch, // Menarik container agar tinggi maksimal
                children: [
                  Container(
                    width: 100, // Berikan lebar pasti agar rapi
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(5)),
                    ),
                    child: const Center(
                      child: Text(
                          "Keterangan",
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), // Padding lebih lega
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8CEFF),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                        border: Border.all(color: Colors.black12, width: 1),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white.withOpacity(0.3), Colors.transparent],
                        ),
                      ),
                      child: Text(
                        jurnal.keterangan,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.4, // Memberikan spasi antar baris agar teks panjang enak dibaca
                        ),
                        softWrap: true,
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _excelButton() => ElevatedButton(
      onPressed: _isLoading ? null : _exportExcel,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.excel,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const FaIcon(FontAwesomeIcons.fileExcel, color: Colors.black, size: 18)
  );

  Widget _printButton() => ElevatedButton(
      onPressed: _isLoading ? null : _printPdf,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.print,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Icon(Icons.print, color: Colors.black, size: 20)
  );
}