import 'dart:io';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

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
  List<Jurnal> _daftarJurnal = [];
  bool _isLoading = true;
  Map<int, bool> _hapusLoadingState = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedYear;
  String? _selectedMonth;
  List<String> _availableYears = [];
  // Daftar bulan filter
  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  List<Jurnal> get _filteredJurnal {
    List<Jurnal> hasil = _daftarJurnal;

    // 1. Filter berdasarkan Tahun (jika dipilih)
    if (_selectedYear != null) {
      hasil = hasil.where((j) => j.tanggal.year.toString() == _selectedYear).toList();
    }

    // 2. Filter berdasarkan Bulan (jika dipilih)
    if (_selectedMonth != null) {
      hasil = hasil.where((j) {
        // Mengonversi nomor bulan (1-12) ke nama bulan sesuai daftar _monthNames
        return _monthNames[j.tanggal.month - 1] == _selectedMonth;
      }).toList();
    }

    // 3. Filter berdasarkan Search Query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final searchClean = query.replaceAll('.', '');

      hasil = hasil.where((jurnal) {
        final matchKeterangan = jurnal.keterangan.toLowerCase().contains(query);

        final matchAkunOrNominal = jurnal.details.any((detail) {
          final namaAkun = (detail.akun?.nama ?? '').toLowerCase();
          final nominalString = detail.nominal.toString();
          final nominalFormat = _formatUang(detail.nominal).toLowerCase();

          return namaAkun.contains(query) ||
              nominalString.contains(searchClean) ||
              nominalFormat.contains(query);
        });

        final matchTanggal = _formatTanggal(jurnal.tanggal).contains(query);

        return matchKeterangan || matchAkunOrNominal || matchTanggal;
      }).toList();
    }

    return hasil;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDataDariDatabase();
    _loadAvailableYears();
  }

  Future<void> _loadAvailableYears() async {
    try {
      final db = await _dbHelper.database;
      // Mengambil tahun unik dari kolom 'tanggal' (format YYYY-MM-DD)
      final List<Map<String, dynamic>> result = await db.rawQuery(
          "SELECT DISTINCT strftime('%Y', tanggal) as tahun FROM jurnal_umum ORDER BY tahun DESC"
      );

      if (mounted) {
        setState(() {
          _availableYears = result.map((e) => e['tahun'].toString()).toList();

          // Jika DB kosong, tampilkan tahun sekarang sebagai pilihan default
          if (_availableYears.isEmpty) {
            _availableYears.add(DateTime.now().year.toString());
          }
        });
      }
    } catch (e) {
      debugPrint("Error load years: $e");
    }
  }
  // --- LOGIKA DATABASE ---
  Future<void> _loadDataDariDatabase() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
      SELECT 
        j.id as jurnal_id, j.tanggal, j.keterangan,
        d.id as detail_id, d.akun_id, d.nominal,
        a.nama as akun_nama, a.kategori_id,
        k.tipe as kategori_tipe
      FROM jurnal_umum j
      LEFT JOIN jurnal_detail d ON j.id = d.jurnal_id
      LEFT JOIN akun a ON d.akun_id = a.id
      LEFT JOIN kategori_akun k ON a.kategori_id = k.id
      ORDER BY j.tanggal DESC, j.id DESC
    ''');

      final Map<int, Jurnal> jurnalMap = {};

      for (var row in result) {
        final jurnalId = row['jurnal_id'] as int;

        if (!jurnalMap.containsKey(jurnalId)) {
          DateTime tgl;
          try {
            String rawTgl = row['tanggal'].toString();
            tgl = rawTgl.contains('/')
                ? DateFormat("dd/MM/yyyy").parse(rawTgl)
                : DateTime.parse(rawTgl);
          } catch (e) {
            tgl = DateTime.now();
          }

          jurnalMap[jurnalId] = Jurnal(
            id: jurnalId,
            tanggal: tgl,
            keterangan: row['keterangan']?.toString() ?? '',
            details: [],
          );
        }

        if (row['detail_id'] != null) {
          jurnalMap[jurnalId]!.details.add(
            JurnalDetail(
              id: row['detail_id'] as int,
              jurnalId: jurnalId,
              akunId: row['akun_id'] as int,
              nominal: (row['nominal'] as num?)?.toDouble() ?? 0,
              akun: Akun(
                id: row['akun_id'] as int,
                nama: row['akun_nama']?.toString() ?? 'Tanpa Nama',
                kategoriId: row['kategori_id'] as int? ?? 0,
                kategoriNama: row['kategori_tipe']?.toString() ?? '',
              ),
            ),
          );
        }
      }

      setState(() {
        _daftarJurnal = jurnalMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Database Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusJurnal(Jurnal jurnal, BuildContext context) async {
    if (jurnal.id == null) return;

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Transaksi?"),
        content: Text(
          "Hapus data tanggal ${_formatTanggal(jurnal.tanggal)}?\nKeterangan: ${jurnal.keterangan}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;
    setState(() => _hapusLoadingState[jurnal.id!] = true);

    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(
          'jurnal_detail',
          where: 'jurnal_id = ?',
          whereArgs: [jurnal.id],
        );
        await txn.delete(
          'jurnal_umum',
          where: 'id = ?',
          whereArgs: [jurnal.id],
        );
      });

      // Pastikan widget di mount (widget ada) sebelum melakukan perubahan.
      // Jika tidak di mount (!mounted) maka proses selesai (return)
      if (!mounted) return;
      await _loadDataDariDatabase();
      await _loadAvailableYears();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Transaksi berhasil dihapus"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Gagal menghapus: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _hapusLoadingState.remove(jurnal.id!));
      }
    }
  }

  Map<String, List<Jurnal>> _kelompokkanPerPeriode() {
    final Map<String, List<Jurnal>> grouped = {};
    final monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    for (var jurnal in _filteredJurnal) {
      final periode =
          '${monthNames[jurnal.tanggal.month - 1]} ${jurnal.tanggal.year}';
      grouped.putIfAbsent(periode, () => []).add(jurnal);
    }
    return grouped;
  }

  // --- FITUR EXPORT EXCEL ---
  Future<void> _exportExcel() async {
    try {
      if (Platform.isAndroid) {
        await Permission.manageExternalStorage.request();
      }

      setState(() => _isLoading = true);
      var workbook = excel_pkg.Excel.createExcel();
      workbook.rename(workbook.getDefaultSheet()!, 'Transaksi');
      excel_pkg.Sheet sheet = workbook['Transaksi'];

      var headerStyle = excel_pkg.CellStyle(
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#1A5276'),
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: excel_pkg.HorizontalAlign.Center,
      );

      final jurnalByPeriode = _kelompokkanPerPeriode();
      for (var entry in jurnalByPeriode.entries) {
        sheet.appendRow([
          excel_pkg.TextCellValue("PERIODE: ${entry.key.toUpperCase()}"),
        ]);

        List<excel_pkg.TextCellValue> headers = [
          excel_pkg.TextCellValue('Tanggal'),
          excel_pkg.TextCellValue('Akun'),
          excel_pkg.TextCellValue('Nominal'),
          excel_pkg.TextCellValue('Keterangan'),
        ];
        sheet.appendRow(headers);

        var rowIdx = sheet.maxRows - 1;
        for (var i = 0; i < headers.length; i++) {
          sheet
                  .cell(
                    excel_pkg.CellIndex.indexByColumnRow(
                      columnIndex: i,
                      rowIndex: rowIdx,
                    ),
                  )
                  .cellStyle =
              headerStyle;
        }

        for (var jurnal in entry.value) {
          for (var detail in jurnal.details) {
            sheet.appendRow([
              excel_pkg.TextCellValue(_formatTanggal(jurnal.tanggal)),
              excel_pkg.TextCellValue(detail.akun?.nama ?? ''),
              excel_pkg.DoubleCellValue(detail.nominal),
              excel_pkg.TextCellValue(jurnal.keterangan),
            ]);
          }
        }
        sheet.appendRow([excel_pkg.TextCellValue("")]);
      }

      String fileName =
          "Jurnal_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx";
      Directory? directory = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/$fileName";
      final fileBytes = workbook.save();

      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Excel disimpan di folder Download"),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FITUR PRINT PDF ---
  Future<void> _printPdf() async {
    final doc = pw.Document();
    final jurnalByPeriode = _kelompokkanPerPeriode();

    for (var entry in jurnalByPeriode.entries) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text("LAPORAN JURNAL - ${entry.key}"),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Tanggal', 'Akun', 'Nominal', 'Keterangan'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey900,
              ),
              data: entry.value
                  .expand(
                    (j) => j.details.map(
                      (d) => [
                        _formatTanggal(j.tanggal),
                        d.akun?.nama ?? '',
                        _formatUang(d.nominal),
                        j.keterangan,
                      ],
                    ),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 20),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Dicetak pada: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
              ),
            ),
          ],
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  String _formatTanggal(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
  String _formatUang(double amount) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(amount);

  // --- UI WIDGETS ---
  @override
  Widget build(BuildContext context) {
    final jurnalByPeriode = _kelompokkanPerPeriode();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text(
          "Ctt. Daftar Transaksi",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(selectedMenu: 'jurnal'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _daftarJurnal.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.layar_primer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Cari keterangan, akun, atau nominal...",
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Dropdown Tahun
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedYear,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: "Tahun",
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: _availableYears.map((y) =>
                              DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 13)))
                          ).toList(),
                          onChanged: (v) => setState(() {
                            _selectedYear = v;
                            _selectedMonth = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dropdown Bulan
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMonth,
                          isDense: true,
                          disabledHint: Text("Pilih Tahun Dahulu"),
                          decoration: InputDecoration(
                            labelText: "Bulan",
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          // Hanya aktif jika Tahun sudah dipilih
                          items: _selectedYear == null ? null : _monthNames.map((m) =>
                              DropdownMenuItem(value: m, child: Text(m, style: TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _selectedMonth = v),
                        ),
                      ),
                      // Tombol Reset Filter
                      if (_selectedYear != null || _selectedMonth != null)
                        IconButton(
                          onPressed: () => setState(() { _selectedYear = null; _selectedMonth = null; }),
                          icon: Icon(Icons.filter_alt_off, color: Colors.redAccent),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _headerTitle("Daftar Transaksi"),
                        const SizedBox(height: 12),
                        if (jurnalByPeriode.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text("Data tidak ditemukan"),
                            ),
                          )
                        else
                          ...jurnalByPeriode.entries.map(
                            (entry) => _periodeSection(
                              entry.key,
                              entry.value,
                              context,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.receipt_long, size: 60, color: Colors.grey[400]),
        const Text('Belum ada data', style: TextStyle(color: Colors.grey)),
      ],
    ),
  );

  Widget _headerTitle(String text) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.penanda,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white)),
  );

  Widget _periodeSection(String periode, List<Jurnal> jurnals, BuildContext context) {
    double totalMasuk = 0;
    double totalKeluar = 0;

    for (var j in jurnals) {
      for (var d in j.details) {
        if (d.akun?.kategoriNama == 'Masuk') {
          totalMasuk += d.nominal;
        } else if (d.akun?.kategoriNama == 'Keluar') {
          totalKeluar += d.nominal;
        }
      }
    }

    double selisih = totalMasuk - totalKeluar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  "Periode $periode",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
              Text(
                "Total ${_formatUang(selisih)}",
                style: TextStyle(
                  color: selisih >= 0 ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        _jurnalList(jurnals, context),
        const SizedBox(height: 8),
        Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _excelButton(),
              const SizedBox(width: 20),
              _printButton()
            ]
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _jurnalList(List<Jurnal> jurnals, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.layar_primer.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        children: jurnals
            .map((jurnal) => _tabelJurnal(jurnal, context))
            .toList(),
      ),
    );
  }

  Widget _tabelJurnal(Jurnal jurnal, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Transaksi Info & Actions
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A), // Header Hitam
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white, // Icon Putih
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat(
                        'dd MMMM yyyy',
                        'id_ID',
                      ).format(jurnal.tanggal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white, // Teks Putih
                      ),
                    ),
                  ],
                ),
                _actionButtons(jurnal, context),
              ],
            ),
          ),

          // Body Card: Detail Transaksi
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...jurnal.details.map((detail) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            detail.akun?.nama ?? 'Tanpa Akun',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            _formatUang(detail.nominal),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.penanda,
                              fontFamily: 'Monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),

                // Keterangan Section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "Ket.",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        jurnal.keterangan,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(Jurnal jurnal, BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditSaldoPage(jurnal: jurnal),
            ),
          ).then((v) => v == true ? _loadDataDariDatabase() : null),
          icon: const Icon(Icons.edit_rounded, size: 20),
          color: AppColors.tombol_edit,
          tooltip: 'Edit',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(8),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.tombol_edit.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _hapusLoadingState[jurnal.id] == true
            ? const SizedBox(
                width: 36,
                height: 36,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  ),
                ),
              )
            : IconButton(
                onPressed: () => _hapusJurnal(jurnal, context),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.red,
                tooltip: 'Hapus',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _excelButton() => ElevatedButton(
    onPressed: _isLoading ? null : _exportExcel,
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: AppColors.excel,
    ),
    child: const FaIcon(
      FontAwesomeIcons.fileExcel,
      color: Colors.black,
      size: 18,
    ),
  );
  Widget _printButton() => ElevatedButton(
    onPressed: _isLoading ? null : _printPdf,
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: AppColors.print,
    ),
    child: const Icon(Icons.print, color: Colors.black, size: 20),
  );
}
