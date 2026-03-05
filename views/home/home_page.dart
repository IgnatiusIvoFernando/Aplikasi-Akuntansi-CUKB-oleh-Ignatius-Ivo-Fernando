import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/warna_cukb.dart';
import '../../controllers/database_helper.dart';
import '../widgets/app_drawer.dart';
import '../../controllers/akun_controller.dart';
import '../../models/akun.dart';
import 'package:fl_chart/fl_chart.dart';

class JurnalRowModel {
  // Kita tetap simpan debitController karena UI Anda menggunakannya sebagai input nominal tunggal
  final TextEditingController nominalController = TextEditingController();
  Akun? selectedAkun;

  void clear() {
    nominalController.clear();
    selectedAkun = null;
  }

  void dispose() {
    nominalController.dispose();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<JurnalRowModel> _rowDataList = [];
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  final AkunController _akunController = AkunController();
  List<Akun> _akunList = [];
  List<Map<String, dynamic>> _chartData = [];
  double _totalDebitSemua = 0;
  double _totalKreditSemua = 0;
  String? _selectedYear;
  List<String> _availableYears = [];
  @override
  @override
  void initState() {
    super.initState();

    // 1. Inisialisasi data sinkron
    _tanggalController.text = DateFormat("dd/MM/yyyy").format(DateTime.now());
    _rowDataList.add(JurnalRowModel());

    // 2. Jalankan fungsi initData() untuk menjalankan semua fungsi
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _initData();
      }
    });
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadAkunData(),
      _hitungTotalSemuaJurnal(),
      _loadAvailableYears(),
    ]);

    await _loadChartData();
  }

  @override
  void dispose() {
    for (var row in _rowDataList) {
      row.dispose();
    }
    _tanggalController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableYears() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
        "SELECT DISTINCT strftime('%Y', tanggal) as tahun FROM jurnal_umum ORDER BY tahun DESC"
    );

    if (mounted) {
      setState(() {
        List<String> years = result.map((e) => e['tahun'].toString()).toList();

        if (years.isEmpty) {
          years.add(DateTime.now().year.toString());
        }

        _availableYears = years;


        if (_selectedYear == null || !_availableYears.contains(_selectedYear)) {
          _selectedYear = _availableYears.first;
        }
      });
    }
  }
  /// Memuat data grafik berdasarkan filter yang dipilih
  Future<void> _loadChartData() async {
    if (_selectedYear == null) return;
    try {
      final db = await DatabaseHelper().database;
      final result = await db.rawQuery('''
      SELECT
        strftime('%m', j.tanggal) as bulan,
        SUM(CASE WHEN k.tipe = 'Masuk' THEN d.nominal ELSE 0 END) as masuk,
        SUM(CASE WHEN k.tipe = 'Keluar' THEN d.nominal ELSE 0 END) as keluar
      FROM jurnal_umum j
      JOIN jurnal_detail d ON j.id = d.jurnal_id
      JOIN akun a ON d.akun_id = a.id
      JOIN kategori_akun k ON a.kategori_id = k.id
      WHERE strftime('%Y', j.tanggal) = ?
      GROUP BY bulan
      ORDER BY bulan ASC
      ''', [_selectedYear]);

      if (mounted) {
        setState(() => _chartData = result);
      }
    } catch (e) {
      debugPrint('Error chart data: $e');
    }
  }
  // Mengambil total berdasarkan kategori 'Masuk' atau 'Keluar'
  Future<void> _hitungTotalSemuaJurnal() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN k.tipe = 'Masuk' THEN d.nominal ELSE 0 END) as total_masuk,
        SUM(CASE WHEN k.tipe = 'Keluar' THEN d.nominal ELSE 0 END) as total_keluar 
      FROM jurnal_detail d
      JOIN akun a ON d.akun_id = a.id
      JOIN kategori_akun k ON a.kategori_id = k.id
    ''');

      if (result.isNotEmpty && mounted) {
        setState(() {
          _totalDebitSemua = (result.first['total_masuk'] as num? ?? 0).toDouble();
          _totalKreditSemua = (result.first['total_keluar'] as num? ?? 0).toDouble();
        });
      }
    } catch (e) {
      print('Error menghitung total: $e');
    }
  }

  Future<void> _loadAkunData() async {
    try {
      final akun = await _akunController.getSemuaAkun();
      if (mounted) {
        setState(() {
          _akunList = akun;
        });
      }
    } catch (e) {
      print('Error loading akun: $e');
    }
  }

  void _tambahRow() {
    setState(() {
      _rowDataList.add(JurnalRowModel());
    });
  }

  void _hapusRow(int index) {
    if (_rowDataList.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Minimal harus ada 1 baris"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _rowDataList[index].dispose();
      _rowDataList.removeAt(index);
    });
  }

  Future<void> _simpanJurnal() async {
    // 1. Validasi awal: Pastikan ada data yang akan disimpan
    if (_rowDataList.isEmpty) {
      _showValidationDialog('Perhatian', 'Isi data terlebih dahulu');
      return;
    }

    final List<Map<String, dynamic>> details = [];
    final List<String> errors = [];

    // 2. Loop untuk memproses setiap baris input
    for (int i = 0; i < _rowDataList.length; i++) {
      final row = _rowDataList[i];

      // Validasi akun
      if (row.selectedAkun == null) {
        errors.add('Baris ${i + 1}: Pilih akun');
        continue;
      }

      // Kita hapus semua titik (.) agar "1.500.000" menjadi "1500000"
      final rawNominal = row.nominalController.text.replaceAll('.', '').trim();
      final nominal = double.tryParse(rawNominal) ?? 0;

      if (nominal <= 0) {
        errors.add('Baris ${i + 1}: Masukkan nominal valid');
      } else {
        details.add({
          'akun_id': row.selectedAkun!.id!,
          'nominal': nominal,
        });
      }
    }

    // 3. Tampilkan pesan error jika ada input yang salah
    if (errors.isNotEmpty) {
      _showValidationDialog('Perhatian', errors.join('\n'));
      return;
    }

    // 4. Proses simpan ke Database menggunakan Transaksi
    try {
      final db = await DatabaseHelper().database;

      await db.transaction((txn) async {
        // Format tanggal untuk SQLite (YYYY-MM-DD)
        final tgl = DateFormat("dd/MM/yyyy").parse(_tanggalController.text);
        final formatDb = DateFormat("yyyy-MM-dd").format(tgl);

        // Simpan ke tabel induk: jurnal_umum
        final jurnalId = await txn.insert('jurnal_umum', {
          'tanggal': formatDb,
          'keterangan': _keteranganController.text.trim(),
        });

        // Simpan ke tabel anak: jurnal_detail
        for (var detail in details) {
          await txn.insert('jurnal_detail', {
            'jurnal_id': jurnalId,
            'akun_id': detail['akun_id'],
            'nominal': detail['nominal'],
          });
        }
      });

      // 5. Refresh data tampilan (Saldo & Grafik) setelah berhasil simpan
      await _hitungTotalSemuaJurnal();
      await _loadAvailableYears();
      await _loadChartData();

      _showSuccessDialog('Data berhasil disimpan!');
    } catch (e) {
      _showValidationDialog('Error', 'Gagal menyimpan: $e');
    }
  }
  Future<void> _showValidationDialog(String title, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(textAlign: TextAlign.center,message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.list_period)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog(String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        title: const Text('Berhasil', style: TextStyle(color: Colors.green)),
        content: Text(textAlign: TextAlign.center,message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: Text('OK', style: TextStyle(color: AppColors.list_period)),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      for (var row in _rowDataList) row.dispose();
      _rowDataList.clear();
      _keteranganController.clear();
      _tanggalController.text = DateFormat("dd/MM/yyyy").format(DateTime.now());
      _rowDataList.add(JurnalRowModel());
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'mengisi'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text("Ctt. Daftar Transaksi", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _tempatSaldo('Uang Masuk', _totalDebitSemua),
                    const SizedBox(height: 5),
                    _tempatSaldo('Uang Keluar', _totalKreditSemua),
                  ],
                ),
              ),
              _buildMonthlyChart(),
              const SizedBox(height: 20),
              SizedBox(
                width: screenWidth * 0.9,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFF000000), Color(0xFF222222)],
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 2), blurRadius: 4)],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(Icons.edit_note, color: Colors.white.withOpacity(0.8), size: 24),
                            const SizedBox(width: 12),
                            const Text("Isi Saldo", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.layar_primer,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                Expanded(flex: 5, child: Text('Akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.list_period))),
                                Expanded(flex: 10, child: Center(child: Text('Nominal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.list_period)))),
                                Container(
                                  width: 30, height: 30,
                                  decoration: BoxDecoration(color: AppColors.tombol_edit, borderRadius: BorderRadius.circular(5)),
                                  child: IconButton(
                                    icon: const Icon(Icons.add, size: 15, color: Colors.black),
                                    padding: EdgeInsets.zero,
                                    onPressed: _tambahRow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              children: _rowDataList.asMap().entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: RowInputJurnal(
                                    onDelete: () => _hapusRow(entry.key),
                                    nominalController: entry.value.nominalController,
                                    akunList: _akunList,
                                    selectedAkun: entry.value.selectedAkun,
                                    onAkunChanged: (value) => setState(() => entry.value.selectedAkun = value),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(height: 30),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text("Tanggal", style: TextStyle(fontSize: 15, color: AppColors.list_period)),
                                Row(
                                  children: [
                                    Expanded(child: TextFormField(controller: _tanggalController, decoration: const InputDecoration(border: UnderlineInputBorder()))),
                                    IconButton(
                                      icon: const Icon(Icons.calendar_month),
                                      onPressed: () async {
                                        DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                        if (picked != null) setState(() => _tanggalController.text = DateFormat("dd/MM/yyyy").format(picked));
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text("Keterangan", style: TextStyle(fontSize: 15, color: AppColors.list_period)),
                                TextFormField(
                                  controller: _keteranganController,
                                  maxLines: null,
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: screenWidth * 0.3,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(colors: [Color(0xFF0E0077), Color(0xFF3A2AD8)]),
                      boxShadow: [BoxShadow(color: const Color(0xFF3A2AD8).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                      onPressed: _simpanJurnal,
                      child: const Text('Simpan', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tempatSaldo(String label, double jumlah) {
    String formatUang(double uang) {
      final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return format.format(uang);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 166, height: 43,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF333333), Color(0xFF000000)]),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 3), blurRadius: 5)],
          ),
          child: Text(label, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 2)])),
        ),
        Container(
          width: 166, height: 43,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFF8D8DCE), borderRadius: BorderRadius.circular(5), boxShadow: [const BoxShadow(color: Colors.black, offset: Offset(-2, 0), blurRadius: 3)]),
          child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(8.0), child: Text(formatUang(jumlah), style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)))),
        ),
      ],
    );
  }
  Widget _buildYearDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedYear,
          isDense: true,
          items: _availableYears.map((y) =>
              DropdownMenuItem(
                  value: y,
                  child: Text("Thn $y", style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (val) {
            setState(() => _selectedYear = val);
            _loadChartData();
          },
        ),
      ),
    );
  }
  Widget _buildMonthlyChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        height: 320,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.layar_primer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Grafik Transaksi", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.list_period)),
                _buildYearDropdown(), // Ganti tombol filter harian/bulanan dengan Dropdown ini
              ],
            ),
            const SizedBox(height: 15),
            _buildLegend(),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineTouchData: _lineTouchData(),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: _buildTitlesData(),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 11, // Selalu Jan-Des
                  minY: 0,
                  maxY: _getMaxValue(),
                  lineBarsData: [
                    _generateLineData(isMasuk: true),
                    _generateLineData(isMasuk: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildLegend() {
    return Row(
      children: [
        _buildLegendItem("Pemasukan", Colors.greenAccent[700]!),
        const SizedBox(width: 15),
        _buildLegendItem("Pengeluaran", Colors.redAccent[400]!),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.list_period)),
      ],
    );
  }
  /// Generate Line Data (Pemasukan/Pengeluaran)
  LineChartBarData _generateLineData({required bool isMasuk}) {
    List<FlSpot> spots = List.generate(12, (i) => FlSpot(i.toDouble(), 0));

    // Isi titik berdasarkan data dari DB yang tersedia
    for (var data in _chartData) {
      int bulanIdx = int.parse(data['bulan'].toString()) - 1;
      double val = (data[isMasuk ? 'masuk' : 'keluar'] as num).toDouble();
      spots[bulanIdx] = FlSpot(bulanIdx.toDouble(), val);
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: isMasuk ? Colors.greenAccent[700] : Colors.redAccent[400],
      barWidth: 3,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        color: (isMasuk ? Colors.greenAccent[700] : Colors.redAccent[400])!.withOpacity(0.1),
      ),
    );
  }

  /// Tooltip Nominal (Muncul saat disentuh)
  LineTouchData _lineTouchData() {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (spot) => Colors.black.withOpacity(0.8),
        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
          return touchedBarSpots.map((barSpot) {
            return LineTooltipItem(
              '${barSpot.bar.color == Colors.greenAccent[700] ? "Masuk" : "Keluar"}: \n',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              children: [
                TextSpan(
                  text: NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(barSpot.y),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 12),
                ),
              ],
            );
          }).toList();
        },
      ),
    );
  }

  /// Label Nama Bulan (Sumbu X)
  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 1, // Memastikan setiap bulan muncul
          getTitlesWidget: (double value, TitleMeta meta) {
            // Gunakan array bulan statis karena rentang selalu 12 bulan
            const months = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"];

            int index = value.toInt();

            // Validasi agar tidak error jika index di luar 0-11
            if (index >= 0 && index < 12) {
              return SideTitleWidget(
                meta: meta,
                space: 10,
                child: Text(
                    months[index],
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87)
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  /// Tinggi Maksimal Sumbu Y
  double _getMaxValue() {
    double maxVal = 0;
    for (var data in _chartData) {
      double masuk = (data['masuk'] as num? ?? 0).toDouble();
      double keluar = (data['keluar'] as num? ?? 0).toDouble();
      if (masuk > maxVal) maxVal = masuk;
      if (keluar > maxVal) maxVal = keluar;
    }
    // Jika tidak ada data, gunakan 1.000.000 sebagai skala default agar tidak crash
    return maxVal == 0 ? 1000000 : maxVal * 1.2;
  }
}


class RowInputJurnal extends StatelessWidget {
  final Function() onDelete;
  final TextEditingController nominalController; // Nama lebih jujur
  final ValueChanged<Akun?> onAkunChanged;
  final List<Akun> akunList;
  final Akun? selectedAkun;

  const RowInputJurnal({
    super.key,
    required this.onDelete,
    required this.nominalController,
    required this.onAkunChanged,
    required this.akunList,
    this.selectedAkun
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: const Color(0xFFD1C9FF),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withOpacity(0.6))
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<Akun?>(
              isExpanded: true,
              value: selectedAkun,
              hint: const Text('Pilih Akun', style: TextStyle(color: Colors.grey, fontSize: 13)),
              items: () {
                List<DropdownMenuItem<Akun?>> menuItems = [];
                String? lastCategory;

                for (var akun in akunList) {
                  String currentCategory = akun.kategoriNama ?? "Tanpa Kategori";

                  if (currentCategory != lastCategory) {
                    menuItems.add(
                      DropdownMenuItem<Akun?>(
                        enabled: false,
                        value: null,
                        child: Text(
                          currentCategory.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                      ),
                    );
                    lastCategory = currentCategory;
                  }

                  menuItems.add(
                    DropdownMenuItem<Akun?>(
                      value: akun,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(akun.nama, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  );
                }
                return menuItems;
              }(),
              onChanged: onAkunChanged,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: TextFormField(
              // --- BERUBAH DI SINI: Menggunakan nominalController ---
              controller: nominalController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(hintText: "—", isDense: true),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  String cleanText = value.replaceAll('.', '');
                  // Gunakan try-catch atau parse aman untuk mencegah crash jika user input aneh
                  int? val = int.tryParse(cleanText);
                  if (val != null) {
                    String formatted = NumberFormat.decimalPattern('id').format(val);
                    nominalController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints()
          ),
        ],
      ),
    );
  }
}
