import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/warna_cukb.dart';
import '../../controllers/database_helper.dart';
import '../widgets/app_drawer.dart';
import '../../controllers/akun_controller.dart';
import '../../models/akun.dart';
import '../../models/jurnal.dart'; // TAMBAH IMPORT INI
// TAMBAH IMPORT INI

class EditSaldoPage extends StatefulWidget {
  final Jurnal jurnal; // PARAMETER WAJIB, TIDAK NULLABLE

  const EditSaldoPage({super.key, required this.jurnal}); // UPDATE CONSTRUCTOR

  @override
  State<EditSaldoPage> createState() => _EditSaldoPageState();
}

class _EditSaldoPageState extends State<EditSaldoPage> {
  List<RowInputJurnal> listRows = [];
  late TextEditingController _tanggalController;
  late TextEditingController _keteranganController;
  final AkunController _akunController = AkunController();
  List<Akun> _akunList = [];
  final List<Akun?> _selectedAkuns = [];

  // FORMAT TANGGAL SEDERHANA
  String _formatTanggalSederhana(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  @override
  void initState() {
    super.initState();

    // INITIALIZE DENGAN DATA JURNAL YANG AKAN DIEDIT
    _tanggalController = TextEditingController(
      text: _formatTanggalSederhana(widget.jurnal.tanggal),
    );

    _keteranganController = TextEditingController(
      text: widget.jurnal.keterangan,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAkunData().then((_) {
        // LOAD DATA JURNAL KE FORM
        _loadJurnalDataToForm(widget.jurnal);
      });
    });
  }

  // METHOD UNTUK LOAD DATA JURNAL KE FORM
  void _loadJurnalDataToForm(Jurnal jurnal) {
    // CLEAR EXISTING ROWS
    listRows.clear();
    _selectedAkuns.clear();

    // UNTUK SETIAP DETAIL JURNAL, BUAT ROW
    for (var detail in jurnal.details) {
      _selectedAkuns.add(null); // PLACEHOLDER
      listRows.add(
        RowInputJurnal(
          onAdd: _tambahRow,
          debitController: TextEditingController(
            text: detail.debit == 0 ? '' : detail.debit.toString(),
          ),
          kreditController: TextEditingController(
            text: detail.kredit == 0 ? '' : detail.kredit.toString(),
          ),
          onAkunChanged: (value) {
            final index = listRows.length - 1;
            if (index < _selectedAkuns.length) {
              _selectedAkuns[index] = value;
            }
          },
          akunList: _akunList,
          initialAkunId: detail.akunId,
          isEditMode: true, // TAMBAH PARAMETER INI
        ),
      );
    }

    // SET SELECTED AKUNS SETELAH AKUN LIST TERLOAD
    Future.delayed(Duration.zero, () {
      for (int i = 0; i < jurnal.details.length; i++) {
        final detail = jurnal.details[i];
        final matchingAkun = _akunList.where((a) => a.id == detail.akunId);
        if (matchingAkun.isNotEmpty) {
          _selectedAkuns[i] = matchingAkun.first;
        }
      }
      setState(() {});
    });
  }

  Future<void> _loadAkunData() async {
    try {
      final akun = await _akunController.getSemuaAkun();
      setState(() {
        _akunList = akun;
      });
    } catch (e) {
      print('Error loading akun: $e');
    }
  }

  void _tambahRow() {
    setState(() {
      _selectedAkuns.add(null);
      final rowIndex = listRows.length;
      listRows.add(
        RowInputJurnal(
          onAdd: _tambahRow,
          debitController: TextEditingController(),
          kreditController: TextEditingController(),
          onAkunChanged: (value) {
            if (rowIndex < _selectedAkuns.length) {
              _selectedAkuns[rowIndex] = value;
            }
          },
          akunList: _akunList,
          isEditMode: true, // TAMBAH PARAMETER INI
        ),
      );
    });
  }

  // UPDATE JURNAL YANG SUDAH ADA
  Future<void> _updateJurnal() async {
    if (listRows.length < 2) {
      _showValidationDialog('Error', 'Minimal 2 akun');
      return;
    }

    double debit = 0, kredit = 0;

    for (int i = 0; i < listRows.length; i++) {
      if (_selectedAkuns[i] == null) {
        _showValidationDialog('Error', 'Baris ${i + 1}: Pilih akun terlebih dahulu');
        return;
      }

      final d = double.tryParse(listRows[i].debitController.text) ?? 0;
      final k = double.tryParse(listRows[i].kreditController.text) ?? 0;

      if (d == 0 && k == 0) {
        _showValidationDialog('Error', 'Baris ${i + 1}: Isi debit atau kredit');
        return;
      }

      debit += d;
      kredit += k;
    }

    if (debit != kredit) {
      _showValidationDialog('Error', 'Debit ($debit) ≠ Kredit ($kredit)');
      return;
    }

    try {
      final db = await DatabaseHelper().database;
      final tgl = DateFormat("dd/MM/yyyy").parse(_tanggalController.text);

      // UPDATE JURNAL YANG SUDAH ADA
      await db.transaction((txn) async {
        // 1. UPDATE HEADER JURNAL
        await txn.update(
          'jurnal_umum',
          {
            'tanggal': tgl.toIso8601String(),
            'keterangan': _keteranganController.text,
          },
          where: 'id = ?',
          whereArgs: [widget.jurnal.id],
        );

        // 2. HAPUS DETAILS LAMA
        await txn.delete(
          'jurnal_detail',
          where: 'jurnal_id = ?',
          whereArgs: [widget.jurnal.id],
        );

        // 3. INSERT DETAILS BARU
        for (int i = 0; i < listRows.length; i++) {
          final row = listRows[i];
          final d = double.tryParse(row.debitController.text) ?? 0;
          final k = double.tryParse(row.kreditController.text) ?? 0;

          if (d > 0 || k > 0) {
            await txn.insert('jurnal_detail', {
              'jurnal_id': widget.jurnal.id!,
              'akun_id': _selectedAkuns[i]!.id!,
              'debit': d,
              'kredit': k,
            });
          }
        }
      });

      _showSuccessDialog('Jurnal berhasil diupdate!');

    } catch (e) {
      _showValidationDialog('Error', 'Gagal mengupdate: $e');
    }
  }

  Future<void> _showValidationDialog(String title, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: Colors.red)),
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
        icon: Icon(Icons.check_circle, color: Colors.green, size: 50),
        title: Text('Berhasil', style: TextStyle(color: Colors.green)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // RETURN TRUE UNTUK REFRESH
            },
            child: Text('OK', style: TextStyle(color: AppColors.list_period)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text("CUKB", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(selectedMenu: 'saldo'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // BAGIAN EDIT SALDO
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 55,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.penanda,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: (){
                                Navigator.pop(context);
                              },
                              icon: Icon(Icons.arrow_back),
                              color: Colors.white,
                            ),
                            Text(
                              "Edit Jurnal",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // BAGIAN FORM INPUT
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 337,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.layar_primer,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(5),
                        ),
                      ),
                      child: ListView(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Text(
                                  'Akun',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.list_period,
                                  ),
                                ),
                                const SizedBox(width: 60),
                                Text(
                                  'Debit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.list_period,
                                  ),
                                ),
                                const SizedBox(width: 60),
                                Text(
                                  'Kredit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.list_period,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 10,
                                ),
                                child: Column(
                                  children: listRows
                                      .map(
                                        (row) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: row,
                                    ),
                                  )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Padding(
                            padding: const EdgeInsets.all(20),
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
                                          border: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              width: 10.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.calendar_month),
                                      onPressed: () async {
                                        DateTime? pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: widget.jurnal.tanggal,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (pickedDate != null) {
                                          setState(() {
                                            _tanggalController.text =
                                                DateFormat("dd/MM/yyyy").format(pickedDate);
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  "Keterangan",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.list_period,
                                  ),
                                ),
                                TextFormField(
                                  controller: _keteranganController,
                                  decoration: const InputDecoration(
                                    border: UnderlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // TOMBOL UPDATE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: 120,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.list_period,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: _updateJurnal, // PANGGIL METHOD UPDATE
                  child: Text(
                    'Update',
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// UPDATE RowInputJurnal UNTUK MODE EDIT
class RowInputJurnal extends StatefulWidget {
  final Function() onAdd;
  final TextEditingController debitController;
  final TextEditingController kreditController;
  final ValueChanged<Akun?> onAkunChanged;
  final List<Akun> akunList;
  final int? initialAkunId;
  final bool isEditMode; // TAMBAH PARAMETER INI

  const RowInputJurnal({
    super.key,
    required this.onAdd,
    required this.debitController,
    required this.kreditController,
    required this.onAkunChanged,
    required this.akunList,
    this.initialAkunId,
    required this.isEditMode, // TAMBAH INI
  });

  @override
  State<RowInputJurnal> createState() => _RowInputJurnalState();
}

class _RowInputJurnalState extends State<RowInputJurnal> {
  Akun? _selectedAkun;

  @override
  void initState() {
    super.initState();
    // SET INITIAL AKUN JIKA ADA
    if (widget.initialAkunId != null) {
      final matchingAkun = widget.akunList.where((a) => a.id == widget.initialAkunId);
      if (matchingAkun.isNotEmpty) {
        _selectedAkun = matchingAkun.first;
        widget.onAkunChanged(matchingAkun.first);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD1C9FF),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 50),
              child: _buildAkunDropdown(),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: widget.debitController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "—",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: const UnderlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                isDense: true,
              ),
              onChanged: (value) {
                if (value.isNotEmpty && widget.isEditMode) {
                  widget.kreditController.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: widget.kreditController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "—",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: const UnderlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                isDense: true,
              ),
              onChanged: (value) {
                if (value.isNotEmpty && widget.isEditMode) {
                  widget.debitController.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 30,
            height: 30,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.tombol_edit,
                borderRadius: BorderRadius.circular(5),
              ),
              child: IconButton(
                icon: const Icon(Icons.add, size: 15),
                padding: EdgeInsets.zero,
                onPressed: widget.onAdd,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAkunDropdown() {
    if (widget.akunList.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          'Belum ada akun',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return DropdownButtonFormField<Akun?>(
      initialValue: _selectedAkun,
      isExpanded: true,
      hint: Text(
        'Pilih Akun',
        style: TextStyle(color: Colors.grey, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      items: widget.akunList.map((akun) {
        return DropdownMenuItem<Akun?>(
          value: akun,
          child: Text(
            akun.nama,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (Akun? value) {
        setState(() => _selectedAkun = value);
        widget.onAkunChanged(value);
      },
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      icon: const Icon(Icons.arrow_drop_down, size: 20),
      style: const TextStyle(fontSize: 13, color: Colors.black),
    );
  }
}