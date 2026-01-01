import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
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
  String? _fotoPath;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  // Penting: Bersihkan controller saat page ditutup
  @override
  void dispose() {
    _namaController.dispose();
    _industriController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    await _loadNegaraProvinsi();
    await _loadProfil();
  }

  Future<void> _loadNegaraProvinsi() async {
    final jsonString = await rootBundle.loadString('assets/data_negara/negara_provinsi.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    negaraProvinsi = data.map((key, value) => MapEntry(key, List<String>.from(value)));
    daftarNegara = negaraProvinsi.keys.toList();
    if (_negara != null) {
      daftarProvinsi = negaraProvinsi[_negara] ?? [];
    }
    setState(() {});
  }

  Future<void> _loadProfil() async {
    setState(() => _isLoading = true);
    final profil = await _controller.getProfil();
    if (profil != null) {
      String? pathValid;
      if (profil.fotoPath != null) {
        final file = File(profil.fotoPath!);
        if (await file.exists()) {
          pathValid = profil.fotoPath;
        }
      }

      setState(() {
        _namaController.text = profil.nama;
        _industriController.text = profil.jenisIndustri ?? '';
        _alamatController.text = profil.alamat ?? '';
        _negara = profil.negara;
        if (_negara != null) {
          daftarProvinsi = negaraProvinsi[_negara] ?? [];
        }
        _provinsi = profil.provinsi;
        _fotoPath = pathValid;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Mendukung segala jenis file gambar (JPG, PNG, WEBP, dll)
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // Kompresi sedikit agar performa lancar
    );

    if (image != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();

        // Hapus file lama jika ada agar penyimpanan tidak penuh
        if (_fotoPath != null) {
          final oldFile = File(_fotoPath!);
          if (await oldFile.exists()) await oldFile.delete();
        }

        final String fileName = "logo_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}";
        final File localImage = await File(image.path).copy('${directory.path}/$fileName');

        setState(() {
          _fotoPath = localImage.path;
        });
      } catch (e) {
        debugPrint("Error saving image: $e");
      }
    }
  }

  Future<void> _simpanProfil() async {
    if (_namaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama perusahaan harus diisi')));
      return;
    }

    final profil = ProfilPerusahaan(
      nama: _namaController.text,
      jenisIndustri: _industriController.text,
      negara: _negara,
      provinsi: _provinsi,
      alamat: _alamatController.text,
      fotoPath: _fotoPath,
    );

    try {
      await _controller.simpanProfil(profil);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil disimpan'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || daftarNegara.isEmpty) {
      return Scaffold(backgroundColor: AppColors.background, body: const Center(child: CircularProgressIndicator()));
    }

    // Cek validitas file untuk tampilan
    final bool hasValidImage = _fotoPath != null && File(_fotoPath!).existsSync();

    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'pengaturan'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.penanda,
        title: const Text('Profil Perusahaan', style: TextStyle(fontSize: 20, color: Colors.white)),
        leading: Builder(builder: (context) => IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        )),
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
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        image: hasValidImage
                            ? DecorationImage(
                            image: FileImage(File(_fotoPath!)),
                            fit: BoxFit.contain
                        )
                            : null,
                      ),
                      child: !hasValidImage
                          ? const Icon(Icons.add_a_photo, size: 50, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                margin: const EdgeInsets.symmetric(vertical: 70),
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFBFC4FF),
                  borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Nama Perusahaan", style: TextStyle(fontSize: 12)),
                      _lineField(_namaController),
                      const SizedBox(height: 14),
                      const Text("Jenis Industri", style: TextStyle(fontSize: 12)),
                      _lineField(_industriController),
                      const SizedBox(height: 24),
                      const Text("Tempat Perusahaan:", style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      const Text("  Negara", style: TextStyle(fontSize: 12)),
                      _chipField(
                        items: daftarNegara,
                        value: _negara,
                        onChanged: (v) {
                          setState(() {
                            _negara = v;
                            daftarProvinsi = negaraProvinsi[v] ?? [];
                            _provinsi = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text("  Provinsi", style: TextStyle(fontSize: 12)),
                      _chipField(
                        items: daftarProvinsi,
                        value: _provinsi,
                        onChanged: (v) => setState(() => _provinsi = v),
                      ),
                      const SizedBox(height: 12),
                      const Text("  Alamat", style: TextStyle(fontSize: 12)),
                      _lineField(_alamatController),
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.penanda,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _simpanProfil,
                          child: const Text("Simpan Profil", style: TextStyle(fontSize: 16)),
                        ),
                      ),
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
    return TextFormField(controller: controller, decoration: const InputDecoration(border: UnderlineInputBorder()));
  }

  Widget _chipField({required List<String> items, required String? value, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      value: (items.contains(value)) ? value : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.view,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
      dropdownColor: Colors.deepPurple,
      onChanged: onChanged,
    );
  }
}