import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/warna_cukb.dart';
import '../../controllers/database_helper.dart';
import '../widgets/app_drawer.dart';
import '../../controllers/akun_controller.dart';
import '../../models/akun.dart';

class JurnalRowModel {
  final TextEditingController debitController = TextEditingController();
  final TextEditingController kreditController = TextEditingController();
  Akun? selectedAkun;

  void clear() {
    debitController.clear();
    kreditController.clear();
    selectedAkun = null;
  }

  void dispose() {
    debitController.dispose();
    kreditController.dispose();
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
  double _totalDebitSemua = 0;
  double _totalKreditSemua = 0;

  @override
  void initState() {
    super.initState();
    _tanggalController.text = DateFormat("dd/MM/yyyy").format(DateTime.now());
    _rowDataList.add(JurnalRowModel());
    _rowDataList.add(JurnalRowModel());

    Future.delayed(const Duration(milliseconds: 50), () async {
      if (mounted) {
        await _loadAkunData();
        await _hitungTotalSemuaJurnal();
      }
    });
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

  Future<void> _hitungTotalSemuaJurnal() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(debit), 0) as total_debit,
        COALESCE(SUM(kredit), 0) as total_kredit 
      FROM jurnal_detail
    ''');

      if (result.isNotEmpty && mounted) {
        final totalDebit = result.first['total_debit'] as num? ?? 0;
        final totalKredit = result.first['total_kredit'] as num? ?? 0;

        setState(() {
          _totalDebitSemua = totalDebit.toDouble();
          _totalKreditSemua = totalKredit.toDouble();
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
    if (_rowDataList.length < 2) {
      _showValidationDialog('Perhatian', 'Minimal 2 akun diperlukan');
      return;
    }

    double totalDebit = 0, totalKredit = 0;
    final List<Map<String, dynamic>> details = [];
    final List<String> errors = [];

    for (int i = 0; i < _rowDataList.length; i++) {
      final row = _rowDataList[i];
      if (row.selectedAkun == null) {
        errors.add('Baris ${i + 1}: Pilih akun');
        continue;
      }

      final debitText = row.debitController.text.replaceAll(',', '.').trim();
      final kreditText = row.kreditController.text.replaceAll(',', '.').trim();
      final debit = double.tryParse(debitText) ?? 0;
      final kredit = double.tryParse(kreditText) ?? 0;

      if (debit < 0 || kredit < 0) {
        errors.add('Baris ${i + 1}: Nilai tidak boleh negatif');
      } else if (debit == 0 && kredit == 0) {
        errors.add('Baris ${i + 1}: Isi debit atau kredit');
      } else if (debit > 0 && kredit > 0) {
        errors.add('Baris ${i + 1}: Hanya isi debit ATAU kredit');
      } else {
        totalDebit += debit;
        totalKredit += kredit;
        details.add({
          'akun_id': row.selectedAkun!.id!,
          'debit': debit,
          'kredit': kredit,
        });
      }
    }

    if (errors.isNotEmpty) {
      _showValidationDialog('Perhatian', errors.join('\n'));
      return;
    }

    if ((totalDebit - totalKredit).abs() > 0.01) {
      _showValidationDialog(
          'Tidak Balance!',
          'Total Debit: ${_formatUang(totalDebit)}\n'
              'Total Kredit: ${_formatUang(totalKredit)}\n'
              'Selisih: ${_formatUang((totalDebit - totalKredit).abs())}'
      );
      return;
    }

    try {
      final db = await DatabaseHelper().database;
      final tgl = DateFormat("dd/MM/yyyy").parse(_tanggalController.text);

      await db.transaction((txn) async {
        final jurnalId = await txn.insert('jurnal_umum', {
          'tanggal': tgl.toIso8601String(),
          'keterangan': _keteranganController.text.trim(),
        });

        for (var detail in details) {
          await txn.insert('jurnal_detail', {
            'jurnal_id': jurnalId,
            'akun_id': detail['akun_id'],
            'debit': detail['debit'],
            'kredit': detail['kredit'],
          });
        }
      });

      await _hitungTotalSemuaJurnal();
      _showSuccessDialog('Jurnal berhasil disimpan!');
    } catch (e) {
      _showValidationDialog('Error', 'Gagal menyimpan: $e');
    }
  }

  String _formatUang(double uang) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    return 'Rp ${format.format(uang)}';
  }

  Future<void> _showValidationDialog(String title, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(message),
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
        content: Text(message),
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
      _tambahRow();
      _tambahRow();
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
        title: const Text("Akuntansi", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Bagian Saldo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _tempatSaldo('Saldo Debit', _totalDebitSemua),
                    const SizedBox(height: 5),
                    _tempatSaldo('Saldo Kredit', _totalKreditSemua),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Box Form Utama
              SizedBox(
                width: screenWidth * 0.9,
                child: Column(
                  children: [
                    // Header Isi Saldo
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

                    // Body Form (TANPA HEIGHT STATIS 337)
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
                          // Header Tabel
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                Expanded(flex: 5, child: Text('Akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.list_period))),
                                Expanded(flex: 2, child: Center(child: Text('Debit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.list_period)))),
                                Expanded(flex: 4, child: Center(child: Text('Kredit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.list_period)))),
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

                          // List Input Rows (Menggunakan Column agar bisa di-scroll oleh SingleChildScrollView luar)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              children: _rowDataList.asMap().entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: RowInputJurnal(
                                    onDelete: () => _hapusRow(entry.key),
                                    debitController: entry.value.debitController,
                                    kreditController: entry.value.kreditController,
                                    akunList: _akunList,
                                    selectedAkun: entry.value.selectedAkun,
                                    onAkunChanged: (value) => setState(() => entry.value.selectedAkun = value),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          const Divider(height: 30),

                          // Input Tanggal & Keterangan
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
                                  decoration: const InputDecoration(hintText: "Contoh: Pembelian peralatan kantor...", hintStyle: TextStyle(fontSize: 12, color: Colors.grey), border: UnderlineInputBorder()),
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

              // Tombol Simpan
              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
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
}

class RowInputJurnal extends StatelessWidget {
  final Function() onDelete;
  final TextEditingController debitController;
  final TextEditingController kreditController;
  final ValueChanged<Akun?> onAkunChanged;
  final List<Akun> akunList;
  final Akun? selectedAkun;

  const RowInputJurnal({super.key, required this.onDelete, required this.debitController, required this.kreditController, required this.onAkunChanged, required this.akunList, this.selectedAkun});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFD1C9FF), borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.white.withOpacity(0.6))),
      child: Row(
        children: [
          Expanded(flex: 4, child: DropdownButtonFormField<Akun?>(isExpanded: true, value: selectedAkun, hint: const Text('Pilih Akun', style: TextStyle(color: Colors.grey, fontSize: 13)), items: akunList.map((akun) => DropdownMenuItem(value: akun, child: Text(akun.nama, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(), onChanged: onAkunChanged, decoration: const InputDecoration(border: InputBorder.none, isDense: true), icon: const Icon(Icons.arrow_drop_down, size: 18), style: const TextStyle(fontSize: 13, color: Colors.black))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(
              controller: debitController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(hintText: "—", isDense: true),
              onChanged: (v) => v.isNotEmpty ? kreditController.clear() : null)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(controller: kreditController, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13), decoration: const InputDecoration(hintText: "—", isDense: true), onChanged: (v) => v.isNotEmpty ? debitController.clear() : null)),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }
}