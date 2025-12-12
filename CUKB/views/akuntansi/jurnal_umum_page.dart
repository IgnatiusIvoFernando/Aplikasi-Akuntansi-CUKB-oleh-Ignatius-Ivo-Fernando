import '../akuntansi/edit_saldo_page.dart';
import 'package:flutter/material.dart';
import '../../config/warna_cukb.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/app_drawer.dart';
import '../../controllers/database_helper.dart';
import '../../controllers/akun_controller.dart';
import '../../models/jurnal.dart';
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

  // Cache untuk nama akun
  final Map<int, String> _namaAkunCache = {};

  @override
  void initState() {
    super.initState();
    _loadDataDariDatabase();
  }

  // LOAD DATA DARI DATABASE - sesuai struktur Anda
  Future<void> _loadDataDariDatabase() async {
    setState(() => _isLoading = true);

    try {
      // 1. Query jurnal dari database - TANPA JOIN
      final db = await _dbHelper.database;
      final jurnalsResult = await db.rawQuery('''
        SELECT * FROM jurnal_umum 
        ORDER BY tanggal DESC
      ''');

      if (jurnalsResult.isEmpty) {
        setState(() {
          _daftarJurnal = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Load semua akun untuk mapping
      final semuaAkun = await _akunController.getSemuaAkun();
      for (var akun in semuaAkun) {
        if (akun.id != null) {
          _namaAkunCache[akun.id!] = akun.nama;
        }
      }

      // 3. Proses setiap jurnal
      final jurnals = <Jurnal>[];

      for (var jurnalMap in jurnalsResult) {
        final jurnalId = jurnalMap['id'] as int;

        // Ambil details untuk jurnal ini
        final detailsResult = await db.rawQuery('''
          SELECT * FROM jurnal_detail 
          WHERE jurnal_id = ? 
          ORDER BY id
        ''', [jurnalId]);

        // Convert ke JurnalDetail
        final details = detailsResult.map((map) {
          return JurnalDetail.fromMap(map);
        }).toList();

        // Buat Akun object untuk setiap detail
        for (var detail in details) {
          if (_namaAkunCache.containsKey(detail.akunId)) {
            detail.akun = Akun(
              id: detail.akunId,
              nama: _namaAkunCache[detail.akunId]!,
              kategoriId: 0,
            );
          }
        }

        // Buat object Jurnal dengan factory method
        final jurnal = Jurnal.fromMapWithDetails(jurnalMap, details);

        jurnals.add(jurnal);
      }

      setState(() {
        _daftarJurnal = jurnals;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }
  // GROUP BY PERIODE dari tanggal ISO String
  Map<String, List<Jurnal>> _kelompokkanPerPeriode() {
    final Map<String, List<Jurnal>> grouped = {};

    for (var jurnal in _daftarJurnal) {
      // Parse tanggal (ISO String) untuk ambil bulan dan tahun
      // Format: "2023-12-01T00:00:00.000"
      final bulan = jurnal.tanggal.month;
      final tahun = jurnal.tanggal.year;

      // Nama bulan Indonesia
      final namaBulan = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];

      final periode = '${namaBulan[bulan - 1]} $tahun';

      if (!grouped.containsKey(periode)) {
        grouped[periode] = [];
      }
      grouped[periode]!.add(jurnal);
    }

    // Urutkan periode dari terbaru ke terlama
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        try {
          final aParts = a.split(' ');
          final bParts = b.split(' ');

          if (aParts.length == 2 && bParts.length == 2) {
            // Map nama bulan ke angka
            final bulanIndex = {
              'Januari': 1, 'Februari': 2, 'Maret': 3, 'April': 4,
              'Mei': 5, 'Juni': 6, 'Juli': 7, 'Agustus': 8,
              'September': 9, 'Oktober': 10, 'November': 11, 'Desember': 12
            };

            final aBulan = bulanIndex[aParts[0]] ?? 0;
            final bBulan = bulanIndex[bParts[0]] ?? 0;
            final aTahun = int.tryParse(aParts[1]) ?? 0;
            final bTahun = int.tryParse(bParts[1]) ?? 0;

            // Urutkan tahun dulu, lalu bulan (descending)
            if (aTahun != bTahun) {
              return bTahun.compareTo(aTahun); // Tahun terbaru dulu
            }
            return bBulan.compareTo(aBulan); // Bulan terbaru dulu
          }
        } catch (e) {
          print('Error sorting: $e');
        }
        return 0;
      });

    // Buat map baru dengan urutan yang benar
    final Map<String, List<Jurnal>> sortedMap = {};
    for (var key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }

    return sortedMap;
  }

  // FORMAT TANGGAL: dd/MM/yyyy
  String _formatTanggal(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  // FORMAT UANG: "Rp 1.000.000"
  String _formatUang(double amount) {
    if (amount == 0) return '0';
    return 'Rp ${amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    final jurnalByPeriode = _kelompokkanPerPeriode();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text("CUKB", style: TextStyle(color: Colors.white)),
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

            // Tampilkan per periode
            ...jurnalByPeriode.entries.map((entry) {
              return Builder(
                builder: (context) => _periodeSection(entry.key, entry.value, context),
              );
            }),
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
            Icon(
              Icons.receipt_long,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada data jurnal',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.penanda,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _periodeSection(String periode, List<Jurnal> jurnals, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "Periode $periode",
            style: const TextStyle(color: Colors.white),
          ),
        ),

        const SizedBox(height: 12),

        // Isi jurnal untuk periode ini
        Builder(
          builder: (innerContext) => _jurnalList(jurnals, innerContext),
        ),

        const SizedBox(height: 12),

        // Tombol print dan excel (jika perlu)
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
      constraints: const BoxConstraints(
        maxHeight: 500,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.layar_primer,
        borderRadius: BorderRadius.circular(4),
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
      decoration: BoxDecoration(
        color: AppColors.layar_primer,
        borderRadius: BorderRadius.circular(4),
      ),
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
                    headingRowColor: WidgetStateProperty.all(Colors.black),
                    headingTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    dataRowColor: WidgetStateProperty.all(const Color(0xFFC9BBFF)),
                    border: TableBorder.all(color: Colors.black, width: 1),
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
                      // Data rows dari jurnal details
                      ...jurnal.details.map((detail) {
                        final namaAkun = detail.akun?.nama ?? _namaAkunCache[detail.akunId] ?? 'Akun ${detail.akunId}';

                        return DataRow(
                          cells: [
                            DataCell(Text(_formatTanggal(jurnal.tanggal))),
                            DataCell(Text(namaAkun)),
                            DataCell(Text(_formatUang(detail.debit))),
                            DataCell(Text(_formatUang(detail.kredit))),
                          ],
                        );
                      }),

                      // Total row
                      DataRow(
                        cells: [
                          const DataCell(Text("")),
                          const DataCell(Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(
                            _formatUang(jurnal.totalDebit),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataCell(Text(
                            _formatUang(jurnal.totalKredit),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(width: 30),

                  // Tombol Edit
                  Container(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EditSaldoPage(jurnal: jurnal),
                          ),
                          ).then((value) {
                            if (value == true){
                              _loadDataDariDatabase();
                            }
                        }
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tombol_edit,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        "Edit",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Bagian Keterangan
            Row(
              children: [
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  color: Colors.black,
                  child: const Text(
                    "Keterangan",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8CEFF),
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        jurnal.keterangan,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _excelButton() {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.excel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: FaIcon(FontAwesomeIcons.fileExcel, color: Colors.black),
    );
  }

  Widget _printButton() {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.print,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: const Icon(Icons.print, color: Colors.black),
    );
  }
}