import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/warna_cukb.dart';
import '../../controllers/profil_controller.dart';
import '../../models/profil_perusahaan.dart';
import '../widgets/app_drawer.dart';

class ProfilPerusahaanPage extends StatefulWidget {
  const ProfilPerusahaanPage({super.key});

  @override
  State<ProfilPerusahaanPage> createState() => _ProfilPerusahaanPageState();
}

class _ProfilPerusahaanPageState extends State<ProfilPerusahaanPage> {
  final ProfilController _controller = ProfilController();
  final _namaController = TextEditingController();
  final _industriController = TextEditingController();
  final _alamatController = TextEditingController();

  Map<String, List<String>> negaraProvinsi = {};
  List<String> daftarNegara = [];
  List<String> daftarProvinsi = [];

  String? _negara;
  String? _provinsi;
  String? _mataUang;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPage();
  }
  Future<void> _initPage() async {
    await _loadNegaraProvinsi();
    await _loadProfil();
  }
  Future<void> _loadNegaraProvinsi() async {
    final jsonString = await rootBundle.loadString('assets/data_negara/negara_provinsi.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    negaraProvinsi = data.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
    );
    daftarNegara = negaraProvinsi.keys.toList();
    daftarProvinsi = negaraProvinsi[_negara] ?? [];

    setState(() {});
  }

  @override
  void dispose() {
    _namaController.dispose();
    _industriController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  Future<void> _loadProfil() async {
    setState(() => _isLoading = true);

    final profil = await _controller.getProfil();
    if (profil != null) {
      setState(() {
        _namaController.text = profil.nama;
        _industriController.text = profil.jenisIndustri ?? '';
        _alamatController.text = profil.alamat ?? '';
        _negara = profil.negara;
        _provinsi = profil.provinsi;
        _mataUang = profil.mataUang;
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _simpanProfil() async {
    if (_namaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama perusahaan harus diisi')),
      );
      return;
    }

    final profil = ProfilPerusahaan(
      nama: _namaController.text,
      jenisIndustri: _industriController.text,
      negara: _negara,
      provinsi: _provinsi,
      alamat: _alamatController.text,
      mataUang: _mataUang ?? 'IDR',
    );

    try {
      await _controller.simpanProfil(profil);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil berhasil disimpan')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || daftarNegara.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'pengaturan'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.penanda,
        title: const Text(
          'Profil Perusahaan',
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
        child: Row(
          children: [
            Container(
              width: 140,
              height: MediaQuery.of(context).size.height * 0.6,
              color: const Color(0xFF0E0077),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                margin: const EdgeInsets.symmetric(vertical: 70),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFBFC4FF),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Nama Perusahaan",
                        style: TextStyle(fontSize: 12),
                      ),
                      _lineField(_namaController),
                      const SizedBox(height: 14),

                      const Text(
                        "Jenis Industri",
                        style: TextStyle(fontSize: 12),
                      ),
                      _lineField(_industriController),
                      const SizedBox(height: 24),

                      const Text(
                        "Tempat Perusahaan:",
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      const Text("  Negara", style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 5),
                      _chipField(
                        items: daftarNegara,
                        value: _negara,
                        onChanged: (v) {
                          setState(() {
                            _negara = v;
                            daftarProvinsi = negaraProvinsi[v] ?? [];
                            _provinsi = null; // reset provinsi jika ganti negara
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      const Text("  Provinsi", style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 5),
                      _chipField(
                          items: daftarProvinsi,
                          value: _provinsi,
                          onChanged: (v) => setState(() => _provinsi = v),
                      ),
                      const SizedBox(height: 12),

                      const Text("  Alamat", style: TextStyle(fontSize: 12)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: _lineField(_alamatController),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.penanda,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _simpanProfil,
                          child: const Text(
                            "Simpan Profil",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(border: UnderlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _chipField({
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: (items.contains(value)) ? value : null,   // FIX UTAMA
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.view,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
          value: e,
          child: Text(e, style: const TextStyle(color: Colors.white)),
        ),
      )
          .toList(),
      dropdownColor: Colors.deepPurple,
      onChanged: onChanged,
    );
  }
}
