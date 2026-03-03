import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/warna_cukb.dart';
import '../../controllers/database_helper.dart';
import '../widgets/app_drawer.dart';
import '../../controllers/akun_controller.dart';
import '../../models/akun.dart';
import '../../models/jurnal_umum_header.dart';

class JurnalRowModel {
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

class EditSaldoPage extends StatefulWidget {
  final Jurnal jurnal;

  const EditSaldoPage({super.key, required this.jurnal});

  @override
  State<EditSaldoPage> createState() => _EditSaldoPageState();
}

class _EditSaldoPageState extends State<EditSaldoPage> {
  final List<JurnalRowModel> _rowDataList = [];
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  final AkunController _akunController = AkunController();
  List<Akun> _akunList = [];

  @override
  void initState() {
    super.initState();
    _tanggalController.text = DateFormat(
      "dd/MM/yyyy",
    ).format(widget.jurnal.tanggal);
    _keteranganController.text = widget.jurnal.keterangan;

    Future.delayed(const Duration(milliseconds: 50), () async {
      if (mounted) {
        await _loadAkunData();
        _loadExistingDetails();
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

  Future<void> _loadAkunData() async {
    try {
      final akun = await _akunController.getSemuaAkun();
      if (mounted) {
        setState(() => _akunList = akun);
      }
    } catch (e) {
      print('Error loading akun: $e');
    }
  }

  // LOGIKA LOAD: Memetakan data database (nominal tunggal) ke UI
  void _loadExistingDetails() {
    setState(() {
      _rowDataList.clear();
      final formatter = NumberFormat.decimalPattern('id');

      for (var detail in widget.jurnal.details) {
        final row = JurnalRowModel();

        // Load nominal dengan format titik ribuan
        row.nominalController.text = detail.nominal == 0
            ? ''
            : formatter.format(detail.nominal.toInt());

        if (_akunList.isNotEmpty) {
          try {
            row.selectedAkun = _akunList.firstWhere((a) => a.id == detail.akunId);
          } catch (_) {
            row.selectedAkun = null;
          }
        }
        _rowDataList.add(row);
      }
      if (_rowDataList.isEmpty) _rowDataList.add(JurnalRowModel());
    });
  }

  void _tambahRow() {
    setState(() => _rowDataList.add(JurnalRowModel()));
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

  Future<void> _updateJurnal() async {
    final List<Map<String, dynamic>> details = [];

    // 1. Validasi dan Sanitasi Input
    for (int i = 0; i < _rowDataList.length; i++) {
      final row = _rowDataList[i];
      if (row.selectedAkun == null) continue;

      // Sanitasi nominal: Hapus titik pemisah ribuan
      final rawNominal = row.nominalController.text.replaceAll('.', '').trim();
      final nominal = double.tryParse(rawNominal) ?? 0;

      if (nominal > 0) {
        details.add({
          'akun_id': row.selectedAkun!.id,
          'nominal': nominal
        });
      }
    }

    if (details.isEmpty) {
      _showValidationDialog('Perhatian', 'Minimal 1 akun dengan nominal valid diperlukan');
      return;
    }

    try {
      final db = await DatabaseHelper().database;

      // Konversi format tanggal UI (dd/MM/yyyy) ke objek DateTime
      final tgl = DateFormat("dd/MM/yyyy").parse(_tanggalController.text);
      // Simpan dalam format ISO8601 atau YYYY-MM-DD sesuai standar SQLite Anda
      final String tglDb = tgl.toIso8601String();

      await db.transaction((txn) async {
        // 1. Update Header Jurnal
        await txn.update(
          'jurnal_umum',
          {
            'tanggal': tglDb,
            'keterangan': _keteranganController.text.trim(),
          },
          where: 'id = ?',
          whereArgs: [widget.jurnal.id],
        );

        // 2. Hapus Detail Lama (Atomic Operation)
        await txn.delete(
          'jurnal_detail',
          where: 'jurnal_id = ?',
          whereArgs: [widget.jurnal.id],
        );

        // 3. Masukkan Detail Baru hasil editing
        for (var detail in details) {
          await txn.insert('jurnal_detail', {
            'jurnal_id': widget.jurnal.id,
            'akun_id': detail['akun_id'],
            'nominal': detail['nominal'],
          });
        }
      });

      _showSuccessDialog('Data transaksi berhasil diperbarui!');
    } catch (e) {
      debugPrint("Update Error: $e");
      _showValidationDialog('Error Database', 'Gagal memperbarui data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'jurnal'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text(
          "Ctt. Daftar Transaksi",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildFormCard(screenWidth),
              const SizedBox(height: 10),
              _buildUpdateButton(screenWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(double screenWidth) {
    return SizedBox(
      width: screenWidth * 0.9,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 55,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF000000), Color(0xFF222222)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Icon(Icons.edit_note, color: Colors.white70, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    "Edit Data Transaksi",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.layar_primer,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(5),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // HEADER TABEL: Sesuai HomePage (Akun & Nominal)
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'Akun',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.list_period,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: Center(
                          child: Text(
                            'Nominal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.list_period,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.tombol_edit,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.add,
                            size: 15,
                            color: Colors.black,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: _tambahRow,
                        ),
                      ),
                    ],
                  ),
                ),
                // LIST BARIS: Menggunakan RowInputJurnal gaya HomePage
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
                          onAkunChanged: (value) =>
                              setState(() => entry.value.selectedAkun = value),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 30),
                // INPUT FOOTER: Tanggal & Keterangan
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Tanggal",
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.list_period,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tanggalController,
                              decoration: const InputDecoration(
                                border: UnderlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: widget.jurnal.tanggal,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(
                                  () => _tanggalController.text = DateFormat(
                                    "dd/MM/yyyy",
                                  ).format(picked),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Keterangan",
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.list_period,
                        ),
                      ),
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
    );
  }

  Widget _buildUpdateButton(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: screenWidth * 0.3,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFF0E0077), Color(0xFF3A2AD8)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3A2AD8).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            onPressed: _updateJurnal,
            child: const Text(
              'Update',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showValidationDialog(String title, String message) {
    showDialog(
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        title: const Text('Berhasil', style: TextStyle(color: Colors.green)),
        content: Text(textAlign: TextAlign.center,message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: Text('OK', style: TextStyle(color: AppColors.list_period)),
          ),
        ],
      ),
    );
  }
}

// WIDGET ROW: 100% Mengikuti logika dan tampilan HomePage
class RowInputJurnal extends StatelessWidget {
  final Function() onDelete;
  final TextEditingController nominalController;
  final ValueChanged<Akun?> onAkunChanged;
  final List<Akun> akunList;
  final Akun? selectedAkun;

  const RowInputJurnal({
    super.key,
    required this.onDelete,
    required this.nominalController,
    required this.onAkunChanged,
    required this.akunList,
    this.selectedAkun,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD1C9FF),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<Akun?>(
              isExpanded: true,
              value: selectedAkun,
              hint: const Text('Pilih Akun', style: TextStyle(color: Colors.grey, fontSize: 13)),
              items: _buildDropdownItems(),
              onChanged: onAkunChanged,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: TextFormField(
              controller: nominalController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(hintText: "—", isDense: true),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  String cleanText = value.replaceAll('.', '');
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
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<Akun?>> _buildDropdownItems() {
    List<DropdownMenuItem<Akun?>> menuItems = [];
    String? lastCategory;
    for (var akun in akunList) {
      String currentCategory = akun.kategoriNama ?? "Tanpa Kategori";
      if (currentCategory != lastCategory) {
        menuItems.add(DropdownMenuItem(
          enabled: false,
          value: null,
          child: Text(currentCategory.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
        ));
        lastCategory = currentCategory;
      }
      menuItems.add(DropdownMenuItem(
        value: akun,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(akun.nama, style: const TextStyle(fontSize: 12)),
        ),
      ));
    }
    return menuItems;
  }
}