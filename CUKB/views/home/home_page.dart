import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/warna_cukb.dart';
import '../../controllers/database_helper.dart';
import '../widgets/app_drawer.dart';
import '../../controllers/akun_controller.dart';
import '../../models/akun.dart';

// KELAS BARU: Untuk membungkus data setiap baris agar index tidak berantakan
class JurnalRowModel {
  final TextEditingController debitController = TextEditingController();
  final TextEditingController kreditController = TextEditingController();
  Akun? selectedAkun;

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
  // PERBAIKAN: Menggunakan List Data, bukan List Widget
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
    // PERBAIKAN: Memastikan urutan eksekusi yang benar
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAkunData();
      await _hitungTotalSemuaJurnal(); // Hitung total setelah UI siap
    });
  }

  @override
  void dispose() {
    // PERBAIKAN: Mencegah Memory Leak
    for (var row in _rowDataList) {
      row.dispose();
    }
    _tanggalController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _hitungTotalSemuaJurnal() async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery('''
      SELECT 
        SUM(debit) as total_debit,
        SUM(kredit) as total_kredit 
      FROM jurnal_detail
    ''');

    if (result.isNotEmpty && mounted) {
      final totalDebit = result.first['total_debit'] ?? 0;
      final totalKredit = result.first['total_kredit'] ?? 0;

      setState(() {
        _totalDebitSemua = (totalDebit is num) ? totalDebit.toDouble() : 0;
        _totalKreditSemua = (totalKredit is num) ? totalKredit.toDouble() : 0;
      });
    }
  }

  Future<void> _loadAkunData() async {
    try {
      final akun = await _akunController.getSemuaAkun();
      if (mounted) {
        setState(() {
          _akunList = akun;
          // PERBAIKAN: Hapus logika penambahan row di sini karena sudah dilakukan di initState
        });
      }
    } catch (e) {
      print('Error loading akun: $e');
    }
  }

  void _tambahRow() {
    setState(() {
      // PERBAIKAN: Menambah data model, widget akan dirender ulang otomatis
      _rowDataList.add(JurnalRowModel());
    });
  }

  Future<void> _simpanJurnal() async {
    // 1. Validasi Minimal Row
    if (_rowDataList.length < 2) {
      _showValidationDialog('Perhatian', 'Minimal 2 akun diperlukan');
      return;
    }

    // 2. Validasi Keterangan (Sering terlewat)
    if (_keteranganController.text.trim().isEmpty) {
      _showValidationDialog('Perhatian', 'Keterangan jurnal wajib diisi');
      return;
    }

    double debit = 0, kredit = 0;
    List<String> errorMessages = [];

    // 3. Loop Validasi Data
    for (int i = 0; i < _rowDataList.length; i++) {
      final row = _rowDataList[i];

      // Validasi Akun Belum Dipilih
      if (row.selectedAkun == null) {
        errorMessages.add('Baris ${i + 1}: Pilih akun terlebih dahulu');
        continue;
      }

      final dText = row.debitController.text.replaceAll(',', '.');
      final kText = row.kreditController.text.replaceAll(',', '.');

      final d = double.tryParse(dText) ?? 0;
      final k = double.tryParse(kText) ?? 0;

      // Validasi Negatif (Cek string input karena tryParse -5 jadi -5.0)
      if (d < 0 || k < 0 || dText.contains('-') || kText.contains('-')) {
        errorMessages.add('Baris ${i + 1}: Nilai tidak boleh negatif');
      }
      // Validasi Kosong
      else if (d == 0 && k == 0) {
        errorMessages.add('Baris ${i + 1}: Isi debit atau kredit');
      }
      // Validasi Double Isi
      else if (d > 0 && k > 0) {
        errorMessages.add('Baris ${i + 1}: Hanya boleh mengisi debit ATAU kredit');
      }

      debit += d;
      kredit += k;
    }

    if (errorMessages.isNotEmpty) {
      _showValidationDialog('Perhatian', errorMessages.join('\n'));
      return;
    }

    // 4. Validasi Balance (Gunakan epsilon untuk komparasi double agar presisi)
    if ((debit - kredit).abs() > 0.01) {
      _showValidationDialog('Kesalahan',
          'Total Debit: Rp ${formatUang(debit)}\n' +
              'Total Kredit: Rp ${formatUang(kredit)}\n\n' +
              'Nilai debit dan kredit harus sama!'
      );
      return;
    }

    // 5. Simpan ke DB
    try {
      final db = await DatabaseHelper().database;
      final tgl = DateFormat("dd/MM/yyyy").parse(_tanggalController.text);

      final jurnalId = await db.insert('jurnal_umum', {
        'tanggal': tgl.toIso8601String(),
        'keterangan': _keteranganController.text,
      });

      for (var row in _rowDataList) {
        final d = double.tryParse(row.debitController.text) ?? 0;
        final k = double.tryParse(row.kreditController.text) ?? 0;

        if (d > 0 || k > 0) {
          // row.selectedAkun sudah divalidasi tidak null
          await db.insert('jurnal_detail', {
            'jurnal_id': jurnalId,
            'akun_id': row.selectedAkun!.id!,
            'debit': d,
            'kredit': k,
          });
        }
      }

      await _hitungTotalSemuaJurnal();
      _showSuccessDialog('Jurnal berhasil disimpan!');

    } catch (e) {
      _showValidationDialog('Error', 'Gagal menyimpan: ${e.toString()}');
    }
  }

  String formatUang(double uang) {
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    return 'Rp ${format.format(uang)}';
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
      // PERBAIKAN: Dispose controllers lama sebelum clear list
      for(var row in _rowDataList) row.dispose();
      _rowDataList.clear();

      _keteranganController.clear();
      _tanggalController.text = DateFormat("dd/MM/yyyy").format(DateTime.now());
      _tambahRow();
      _tambahRow();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'mengisi'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.penanda,
        title: Text(
          'CUKB',
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 30),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 35),
                child: Column(
                  children: [
                    _tempatSaldo('Saldo Debit', _totalDebitSemua),
                    const SizedBox(height: 5),
                    _tempatSaldo('Saldo Kredit', _totalKreditSemua),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
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
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Text(
                                "Isi Saldo",
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
                              padding: EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Text(
                                    'Akun',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.list_period,
                                    ),
                                  ),
                                  SizedBox(width: 100),
                                  Text(
                                    'Debit',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.list_period,
                                    ),
                                  ),
                                  SizedBox(width: 60),
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
                                  padding: EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 10,
                                  ),
                                  child: Column(
                                    // PERBAIKAN: Mapping dari data model ke Widget
                                    // Ini memastikan data tidak tertukar saat rendering
                                    children: _rowDataList.map((dataRow) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: RowInputJurnal(
                                          onAdd: _tambahRow,
                                          debitController: dataRow.debitController,
                                          kreditController: dataRow.kreditController,
                                          akunList: _akunList,
                                          selectedAkun: dataRow.selectedAkun,
                                          onAkunChanged: (value) {
                                            setState(() {
                                              dataRow.selectedAkun = value;
                                            });
                                            // _hitungTotalSemuaJurnal hanya untuk DB,
                                            // jika ingin hitung live preview, tambahkan logic di sini
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 5),
                            Padding(
                              padding: EdgeInsets.all(20),
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
                                          DateTime? pickedDate =
                                          await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2100),
                                          );
                                          if (pickedDate != null) {
                                            setState(() {
                                              _tanggalController.text =
                                                  DateFormat(
                                                    "dd/MM/yyyy",
                                                  ).format(pickedDate);
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 5),
                            Padding(
                              padding: EdgeInsets.all(20),
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
              SizedBox(height: 10),
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
                    onPressed: _simpanJurnal,
                    child: Text(
                      'Tambah',
                      style: TextStyle(fontSize: 15, color: Colors.white),
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
      final format = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return format.format(uang);
    }

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 166,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
          Container(
            width: 166,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(0xFF8D8DCE),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              formatUang(jumlah),
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RowInputJurnal extends StatefulWidget {
  final Function() onAdd;
  final TextEditingController debitController;
  final TextEditingController kreditController;
  final ValueChanged<Akun?> onAkunChanged;
  final List<Akun> akunList;
  final Akun? selectedAkun; // Ditambahkan: Menerima state dari parent

  const RowInputJurnal({
    super.key,
    required this.onAdd,
    required this.debitController,
    required this.kreditController,
    required this.onAkunChanged,
    required this.akunList,
    this.selectedAkun, // Ditambahkan
  });

  @override
  State<RowInputJurnal> createState() => _RowInputJurnalState();
}

class _RowInputJurnalState extends State<RowInputJurnal> {
  // dihapus local state _selectedAkun karena sudah dihandle parent (Single Source of Truth)

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD1C9FF),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 50),
              child: _buildAkunDropdown(),
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: widget.debitController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "—",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: UnderlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                isDense: true,
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  widget.kreditController.clear();
                }
              },
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: widget.kreditController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "—",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: UnderlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                isDense: true,
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  widget.debitController.clear();
                }
              },
            ),
          ),
          SizedBox(width: 4),
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
        padding: EdgeInsets.symmetric(horizontal: 8),
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
      isExpanded: true,
      // PERBAIKAN: Menggunakan value dari parent agar sinkron
      value: widget.selectedAkun,
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
            style: TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (Akun? value) {
        widget.onAkunChanged(value);
      },
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      icon: Icon(Icons.arrow_drop_down, size: 20),
      style: TextStyle(fontSize: 13, color: Colors.black),
    );
  }
}