import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/warna_cukb.dart';
import '../../controllers/database_helper.dart';
import '../widgets/app_drawer.dart';
import '../../controllers/akun_controller.dart';
import '../../models/akun.dart';
import '../../models/jurnal_umum_header.dart';

// STRUKTUR DATA: Menggunakan JurnalRowModel seperti di HomePage
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

class EditSaldoPage extends StatefulWidget {
  final Jurnal jurnal; // Parameter dari halaman daftar jurnal

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
    // Inisialisasi Header dengan data yang ada
    _tanggalController.text = DateFormat("dd/MM/yyyy").format(widget.jurnal.tanggal);
    _keteranganController.text = widget.jurnal.keterangan;

    // Load data akun, kemudian load detail jurnal
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
        setState(() {
          _akunList = akun;
        });
      }
    } catch (e) {
      print('Error loading akun: $e');
    }
  }

  // LOGIKA LOAD: Memindahkan data widget.jurnal ke _rowDataList
  void _loadExistingDetails() {
    setState(() {
      _rowDataList.clear();
      for (var detail in widget.jurnal.details) {
        final row = JurnalRowModel();

        // Konversi nominal ke string, buang .0 jika ada
        row.debitController.text = detail.debit == 0
            ? ''
            : (detail.debit % 1 == 0 ? detail.debit.toInt().toString() : detail.debit.toString());
        row.kreditController.text = detail.kredit == 0
            ? ''
            : (detail.kredit % 1 == 0 ? detail.kredit.toInt().toString() : detail.kredit.toString());

        // Cari akun yang sesuai di dalam _akunList
        if (_akunList.isNotEmpty) {
          try {
            row.selectedAkun = _akunList.firstWhere((a) => a.id == detail.akunId);
          } catch (_) {
            row.selectedAkun = null;
          }
        }
        _rowDataList.add(row);
      }
    });
  }

  void _tambahRow() {
    setState(() {
      _rowDataList.add(JurnalRowModel());
    });
  }

  void _hapusRow(int index) {
    if (_rowDataList.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimal harus ada 1 baris"), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() {
      _rowDataList[index].dispose();
      _rowDataList.removeAt(index);
    });
  }

  Future<void> _updateJurnal() async {
    if (_rowDataList.length < 2) {
      _showValidationDialog('Perhatian', 'Minimal 2 akun diperlukan');
      return;
    }

    double totalDebit = 0, totalKredit = 0;
    final List<Map<String, dynamic>> details = [];

    for (int i = 0; i < _rowDataList.length; i++) {
      final row = _rowDataList[i];
      if (row.selectedAkun == null) continue;

      final debit = double.tryParse(row.debitController.text.replaceAll(',', '.')) ?? 0;
      final kredit = double.tryParse(row.kreditController.text.replaceAll(',', '.')) ?? 0;

      if (debit > 0 || kredit > 0) {
        totalDebit += debit;
        totalKredit += kredit;
        details.add({
          'akun_id': row.selectedAkun!.id,
          'debit': debit,
          'kredit': kredit,
        });
      }
    }

    if ((totalDebit - totalKredit).abs() > 0.01) {
      _showValidationDialog('Tidak Balance!', 'Debit: $totalDebit, Kredit: $totalKredit');
      return;
    }

    try {
      final db = await DatabaseHelper().database;
      final tgl = DateFormat("dd/MM/yyyy").parse(_tanggalController.text);

      await db.transaction((txn) async {
        // UPDATE Header
        await txn.update('jurnal_umum', {
          'tanggal': tgl.toIso8601String(),
          'keterangan': _keteranganController.text.trim(),
        }, where: 'id = ?', whereArgs: [widget.jurnal.id]);

        // HAPUS detail lama
        await txn.delete('jurnal_detail', where: 'jurnal_id = ?', whereArgs: [widget.jurnal.id]);

        // INSERT detail baru
        for (var detail in details) {
          await txn.insert('jurnal_detail', {
            'jurnal_id': widget.jurnal.id,
            'akun_id': detail['akun_id'],
            'debit': detail['debit'],
            'kredit': detail['kredit'],
          });
        }
      });

      _showSuccessDialog('Jurnal berhasil diperbarui!');
    } catch (e) {
      _showValidationDialog('Error', 'Gagal update: $e');
    }
  }

  // --- UI COMPONENTS: Mengikuti struktur visual HomePage ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'jurnal'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text("Akuntansi", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildFormCard(),
              const SizedBox(height: 10),
              _buildUpdateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Padding(
      // Padding luar yang konsisten di semua sisi
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        // Memaksa kotak untuk melebar penuh sesuai ruang yang tersedia (setelah dipotong padding)
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Edit Jurnal (Kotak Atas)
          Container(
            height: 55,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF000000),
                  Color(0xFF222222),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Icon(Icons.edit_note, color: Colors.white70, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    "Edit Jurnal",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body Form (Kotak Bawah)
          Container(
            // Menghapus width statis agar lebarnya otomatis sejajar dengan header di atasnya
            decoration: BoxDecoration(
              color: AppColors.layar_primer,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildTableHeader(),
                _buildRowList(),
                _buildInputSection("Tanggal", _tanggalController, isDate: true),
                _buildInputSection("Keterangan", _keteranganController, isMultiline: true),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('Akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.list_period))),
          Expanded(flex: 2, child: Center(child: Text('Debit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.list_period)))),
          Expanded(flex: 4, child: Center(child: Text('Kredit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.list_period)))),
          SizedBox(
            width: 30, height: 30,
            child: Container(
              decoration: BoxDecoration(color: AppColors.tombol_edit, borderRadius: BorderRadius.circular(5)),
              child: IconButton(icon: const Icon(Icons.add, size: 15), padding: EdgeInsets.zero, onPressed: _tambahRow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowList() {
    return Padding(
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
              onAkunChanged: (val) => setState(() => entry.value.selectedAkun = val),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputSection(String label, TextEditingController controller, {bool isDate = false, bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: AppColors.list_period)),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  readOnly: isDate,
                  maxLines: isMultiline ? null : 1,
                  decoration: const InputDecoration(border: UnderlineInputBorder()),
                ),
              ),
              if (isDate)
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
                      setState(() => _tanggalController.text = DateFormat("dd/MM/yyyy").format(picked));
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Align(
          alignment: Alignment.centerLeft, // Memastikan tombol ke sisi kiri
          child: Container(
            width: MediaQuery.of(context).size.width * 0.3,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0E0077),
                  Color(0xFF3A2AD8),
                ],
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
                padding: EdgeInsets.zero,
              ),
              onPressed: _updateJurnal,
              child: const Text(
                'Update',
                style: TextStyle(fontSize: 15, color: Colors.white),
              ),
            ),
          ),
        )
    );
  }

  // --- DIALOGS (Identik dengan Home) ---
  void _showValidationDialog(String title, String message) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(color: Colors.red)),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK', style: TextStyle(color: AppColors.list_period)))],
    ));
  }

  void _showSuccessDialog(String message) {
    showDialog(context: context, builder: (context) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
      title: const Text('Berhasil', style: TextStyle(color: Colors.green)),
      content: Text(message),
      actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context, true); }, child: Text('OK', style: TextStyle(color: AppColors.list_period)))],
    ));
  }
}

// WIDGET ROW: Identik dengan HomePage
class RowInputJurnal extends StatelessWidget {
  final VoidCallback onDelete;
  final TextEditingController debitController;
  final TextEditingController kreditController;
  final ValueChanged<Akun?> onAkunChanged;
  final List<Akun> akunList;
  final Akun? selectedAkun;

  const RowInputJurnal({
    super.key,
    required this.onDelete,
    required this.debitController,
    required this.kreditController,
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
          Expanded(flex: 4, child: _buildAkunDropdown()),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _buildTextField(debitController, kreditController)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _buildTextField(kreditController, debitController)),
          const SizedBox(width: 8),
          IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              padding: EdgeInsets.zero,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, TextEditingController opposite) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(hintText: "—", border: UnderlineInputBorder(), isDense: true),
      onChanged: (val) { if (val.isNotEmpty) opposite.clear(); },
    );
  }

  Widget _buildAkunDropdown() {
    return DropdownButtonFormField<Akun?>(
      isExpanded: true,
      value: selectedAkun,
      hint: const Text('Pilih Akun', style: TextStyle(color: Colors.grey, fontSize: 13)),
      items: akunList.map((akun) => DropdownMenuItem(value: akun, child: Text(akun.nama, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onAkunChanged,
      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
    );
  }
}
