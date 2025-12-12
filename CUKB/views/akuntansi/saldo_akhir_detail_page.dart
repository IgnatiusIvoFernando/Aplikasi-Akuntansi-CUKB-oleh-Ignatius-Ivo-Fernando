import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../config/warna_cukb.dart';
// TAMBAHKAN IMPORT
import '../../controllers/saldo_controller.dart';

class SaldoAkhirDetailPage extends StatefulWidget {
  final int id;
  final String bulan;
  final String tahun;

  SaldoAkhirDetailPage({
    super.key,
    required this.id,
    required this.bulan,
    required this.tahun,
  });

  @override
  State<SaldoAkhirDetailPage> createState() => _SaldoAkhirDetailPageState();
}

class _SaldoAkhirDetailPageState extends State<SaldoAkhirDetailPage> {
  // GANTI dengan controller
  final SaldoAkhirController _controller = SaldoAkhirController();
  List<Map<String, dynamic>> _akunList = [];
  bool _isLoading = true;

  // Mapping bulan nama ke angka
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
      // Konversi bulan nama ke angka
      final bulanAngka = _bulanAngka[widget.bulan] ?? '01';

      // Ambil data dari database menggunakan controller
      final data = await _controller.getSaldoAkhirByPeriode(bulanAngka, widget.tahun);

      // Format data untuk UI (tetap dengan color coding)
      _akunList = _formatDataUntukUI(data);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading saldo akhir: $e');
      setState(() => _isLoading = false);
    }
  }

  // Format data dari database ke format UI - MEMPERTAHANKAN TAMPILAN ASLI
  List<Map<String, dynamic>> _formatDataUntukUI(List<Map<String, dynamic>> data) {
    final List<Map<String, dynamic>> formattedList = [];

    for (var row in data) {
      final nama = row['nama'] as String? ?? '';
      final debit = (row['debit'] as num?)?.toDouble() ?? 0;
      final kredit = (row['kredit'] as num?)?.toDouble() ?? 0;

      // Tentukan warna berdasarkan nama akun (sesuai contoh asli)
      Color? color = _getColorForAccount(nama, debit, kredit);

      // Hanya tampilkan akun yang memiliki transaksi
      if (debit > 0 || kredit > 0) {
        formattedList.add({
          "nama": nama,
          "debit": debit,
          "kredit": kredit,
          "color": color,
        });
      }
    }

    // Urutkan sesuai contoh asli
    return _sortAccounts(formattedList);
  }

  // Helper: Tentukan warna berdasarkan nama akun (sesuai contoh asli)
  Color? _getColorForAccount(String nama, double debit, double kredit) {
    // Yellow untuk debit atau akun tertentu
    if (nama.contains('Kas') ||
        nama.contains('Pendapatan') ||
        nama.contains('Suplai') ||
        nama.contains('Peralatan') ||
        nama.contains('Hutang') ||
        nama.contains('Utilitas') ||
        nama.contains('Pinjaman') ||
        nama.contains('Modal') ||
        nama.contains('Penarikan') ||
        nama.contains('Gaji') ||
        nama.contains('Perlengkapan') ||
        nama.contains('Layanan') ||
        nama.contains('Servis')) {
      return Colors.yellow;
    }

    // Red untuk akun kontra/pengurang
    if (nama.contains('Akumulasi') ||
        nama.contains('Penyusutan') ||
        nama.contains('Beban') ||
        nama.contains('Biaya') ||
        nama.contains('Pajak') ||
        nama.contains('Sewa')) {
      return Colors.redAccent;
    }

    return null; // Default color
  }

  // Helper: Urutkan akun sesuai contoh asli
  List<Map<String, dynamic>> _sortAccounts(List<Map<String, dynamic>> accounts) {
    // Urutan prioritas berdasarkan contoh asli
    final order = [
      'Kas', 'Pendapatan', 'Suplai Layanan', 'Peralatan dan Perlengkapan', 'Peralatan Servis',
      'Akumulasi Penyusutan', 'Akun Hutang', 'Utilitas Hutang', 'Hutang Pinjaman', 'Modal Anak Marga',
      'Penarikan Anak Marga', 'Pendapatan Layanan',
      'Biaya Sewa', 'Beban Gaji', 'Pajak dan Lisensi', 'Beban Utilitas', 'Beban Perlengkapan Layanan', 'Beban Penyusutan'
    ];

    return accounts..sort((a, b) {
      final aIndex = order.indexWhere((name) => (a['nama'] as String).contains(name));
      final bIndex = order.indexWhere((name) => (b['nama'] as String).contains(name));

      if (aIndex == -1 && bIndex == -1) return a['nama'].compareTo(b['nama']);
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;

      return aIndex.compareTo(bIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalDebit = _akunList.fold(0.0, (sum, item) => sum + (item['debit'] as num).toDouble());
    double totalKredit = _akunList.fold(0.0, (sum, item) => sum + (item['kredit'] as num).toDouble());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("CUKB", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Judul - TETAP SAMA
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Text(
                      "Saldo Percobaan Layanan Perbaikan Perangkat",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      "Elektronik Anak Marga 31 ${widget.bulan} ${widget.tahun}",
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // TABEL - TETAP SAMA (data dari database)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Table(
                  border: TableBorder.all(color: Colors.black),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                  },
                  children: [
                    // Header
                    TableRow(
                      decoration: BoxDecoration(color: AppColors.layar_primer),
                      children: const [
                        _tableHeader("Nama Akun"),
                        _tableHeader("Debit"),
                        _tableHeader("Kredit"),
                      ],
                    ),

                    // Isi akun dari database
                    ..._akunList.map((akun) {
                      return TableRow(
                        decoration: BoxDecoration(
                          color: akun['color'] ?? Colors.white,
                        ),
                        children: [
                          _tableCell(akun['nama']),
                          _tableCell(_format(akun['debit'])),
                          _tableCell(_format(akun['kredit'])),
                        ],
                      );
                    }).toList(),

                    // Footer TOTAL - TETAP SAMA
                    TableRow(
                      decoration: BoxDecoration(color: Colors.greenAccent),
                      children: [
                        _tableHeader("TOTAL"),
                        _tableHeader(_format(totalDebit)),
                        _tableHeader(_format(totalKredit)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  _printButton(),
                  const SizedBox(width: 20),
                  _excelButton(),
                  const SizedBox(width: 20),
                  _printPreViewButton()
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // Format angka - TETAP SAMA
  static String _format(num value) {
    if (value == 0) return "";
    return "\Rp ${value.toStringAsFixed(2)}";
  }

  // Tombol - TETAP SAMA
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

  Widget _printPreViewButton() {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.view,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: const Icon(Icons.remove_red_eye, color: Colors.black),
    );
  }
}

// Widget header tabel - TETAP SAMA
class _tableHeader extends StatelessWidget {
  final String text;
  const _tableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

// Widget cell tabel - TETAP SAMA
class _tableCell extends StatelessWidget {
  final String text;
  const _tableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      alignment: Alignment.centerLeft,
      child: Text(text),
    );
  }
}