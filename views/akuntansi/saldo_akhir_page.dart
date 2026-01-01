import '../akuntansi/saldo_akhir_detail_page.dart';
import 'package:flutter/material.dart';
import '../../config/warna_cukb.dart';
import '../../controllers/database_helper.dart';
import '../widgets/app_drawer.dart';
import '../../controllers/saldo_controller.dart';

class SaldoAkhirPage extends StatefulWidget {
  const SaldoAkhirPage({super.key});

  @override
  State<SaldoAkhirPage> createState() => _SaldoAkhirPageState();
}

class _SaldoAkhirPageState extends State<SaldoAkhirPage> {
  // TAMBAHKAN CONTROLLER
  final SaldoAkhirController _saldoController = SaldoAkhirController();
  final List<Map<String, dynamic>> _saldoPeriode = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeriodeDariDatabase();
  }

  // LOAD PERIODE DARI DATABASE - MENGGUNAKAN CONTROLLER
  Future<void> _loadPeriodeDariDatabase() async {
    setState(() => _isLoading = true);

    try {
      // Gunakan method dari controller
      final hasilQuery = await _saldoController.getSaldoPeriode();

      // Konversi ke format yang diinginkan
      final List<Map<String, dynamic>> periodeList = [];
      int id = 1;

      for (var row in hasilQuery) {
        final tahun = row['tahun'] as String? ?? '';
        final bulanNama = row['bulan_nama'] as String? ?? 'Januari';
        final bulanAngka = row['bulan_angka'] as String? ?? '01';
        final jumlahTransaksi = row['jumlah_transaksi'] as int? ?? 0;
        final totalDebit = (row['total_debit'] as num?)?.toDouble() ?? 0;
        final totalKredit = (row['total_kredit'] as num?)?.toDouble() ?? 0;

        // Hanya tampilkan periode yang punya transaksi
        if (jumlahTransaksi > 0) {
          periodeList.add({
            'id': id++,
            'bulan': bulanNama,
            'tahun': tahun,
            'bulan_angka': bulanAngka,
            'jumlah_transaksi': jumlahTransaksi,
            'total_debit': totalDebit,
            'total_kredit': totalKredit,
          });
        }
      }

      setState(() {
        _saldoPeriode.clear();
        _saldoPeriode.addAll(periodeList);
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading periode: $e');
      setState(() => _isLoading = false);
    }
  }

  // FUNGSI HAPUS PERIODE - MENGGUNAKAN DATABASE HELPER
  void _hapusPeriode(int id, String bulanAngka, String tahun) async {
    try {
      final db = await DatabaseHelper().database;

      await db.transaction((txn) async {
        // 1. Hapus semua details terlebih dahulu
        await txn.rawDelete('''
        DELETE FROM jurnal_detail 
        WHERE jurnal_id IN (
          SELECT id FROM jurnal_umum 
          WHERE strftime('%Y', tanggal) = ? 
            AND strftime('%m', tanggal) = ?
        )
      ''', [tahun, bulanAngka]);

        // 2. Hapus headers
        final result = await txn.rawDelete('''
        DELETE FROM jurnal_umum 
        WHERE strftime('%Y', tanggal) = ? 
          AND strftime('%m', tanggal) = ?
      ''', [tahun, bulanAngka]);

        return result;
      }).then((result) {
        if (result > 0) {
          setState(() {
            _saldoPeriode.removeWhere((item) => item['id'] == id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$result transaksi periode berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });

    } catch (e) {
      print('Error deleting periode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // KONFIRMASI HAPUS - TETAP SAMA
  void _konfirmasiHapus(int id, String bulan, String tahun, String bulanAngka) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Periode?'),
        content: Text('Apakah Anda yakin ingin menghapus SEMUA transaksi periode $bulan $tahun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _hapusPeriode(id, bulanAngka, tahun);
            },
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // NAVIGASI KE DETAIL PAGE - TETAP SAMA
  void _onItemPressed(int id, String bulan, String tahun) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaldoAkhirDetailPage(
          id: id,
          bulan: bulan,
          tahun: tahun,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text("Akuntansi", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(selectedMenu: 'saldo'),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(color: AppColors.penanda),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - TETAP SAMA
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 8),
                child: Text(
                  'Saldo Akhir',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 24, right: 24),
                child: Text(
                  'Data terurut secara menurun',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),

              Container(height: 1, color: Colors.grey[300], margin: EdgeInsets.symmetric(horizontal: 24)),

              // List Periode - TETAP SAMA
              Container(
                decoration: BoxDecoration(color: AppColors.layar_primer),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: _saldoPeriode.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: ScrollPhysics(),
                  itemCount: _saldoPeriode.length,
                  itemBuilder: (context, index) {
                    final periode = _saldoPeriode[index];
                    return _buildPeriodeItem(
                      id: periode['id'],
                      bulan: periode['bulan'],
                      tahun: periode['tahun'],
                      bulanAngka: periode['bulan_angka'],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('Tidak ada data periode', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            SizedBox(height: 8),
            Text('Belum ada transaksi yang tercatat', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  // _buildPeriodeItem - TETAP SAMA
  Widget _buildPeriodeItem({
    required int id,
    required String bulan,
    required String tahun,
    required String bulanAngka,
  }) {
    return InkWell(
      onTap: () => _onItemPressed(id, bulan, tahun),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                ),
                Text(
                  'Periode $bulan $tahun',
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            IconButton(
              onPressed: () => _konfirmasiHapus(id, bulan, tahun, bulanAngka),
              icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 22),
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(),
              tooltip: 'Hapus periode',
            ),
          ],
        ),
      ),
    );
  }
}