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

  // Mapping: { Negara: { Provinsi: [Daftar Kota] } }
  Map<String, Map<String, List<String>>> negaraDataLengkap = {};
  List<String> daftarNegara = [];
  List<String> daftarProvinsi = [];
  List<String> daftarKota = [];

  String? _negara;
  String? _provinsi;
  String? _kota;
  String? _fotoPath;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

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
    try {
      final jsonString = await rootBundle.loadString('assets/data_negara/negara_provinsi.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;

      // Transformasi JSON ke Map bertingkat
      negaraDataLengkap = data.map((key, value) {
        return MapEntry(
            key,
            (value as Map<String, dynamic>).map(
                    (k, v) => MapEntry(k, List<String>.from(v))
            )
        );
      });

      setState(() {
        daftarNegara = negaraDataLengkap.keys.toList();
      });
    } catch (e) {
      debugPrint("Error loading JSON: $e");
    }
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
        if (_negara != null) {
          daftarProvinsi = negaraDataLengkap[_negara]?.keys.toList() ?? [];
          _provinsi = profil.provinsi;

          if (_provinsi != null) {
            daftarKota = negaraDataLengkap[_negara]?[_provinsi] ?? [];
            _kota = profil.kota;
          }
        }
        _fotoPath = profil.fotoPath;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        if (_fotoPath != null) {
          final oldFile = File(_fotoPath!);
          if (await oldFile.exists()) await oldFile.delete();
        }
        final String fileName = "logo_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}";
        final File localImage = await File(image.path).copy('${directory.path}/$fileName');
        setState(() => _fotoPath = localImage.path);
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
      kota: _kota,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool hasValidImage = _fotoPath != null && File(_fotoPath!).existsSync();

    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'pengaturan'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.penanda,
        title: const Text('Profil Perusahaan', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsetsGeometry.symmetric(vertical: 60),
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
                            ? DecorationImage(image: FileImage(File(_fotoPath!)), fit: BoxFit.contain)
                            : null,
                      ),
                      child: !hasValidImage ? const Icon(Icons.add_a_photo, size: 50, color: Colors.grey) : null,
                    ),
                  ),
                ],
              ),
            ),
            // Form Inputs
            Expanded(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                margin: const EdgeInsets.symmetric(vertical: 40),
                padding: const EdgeInsets.all(15),
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

                      const SizedBox(height: 10),
                      const Text("  Negara", style: TextStyle(fontSize: 12)),
                      _chipField(
                        items: daftarNegara,
                        value: _negara,
                        onChanged: (v) {
                          setState(() {
                            _negara = v;
                            daftarProvinsi = negaraDataLengkap[v]?.keys.toList() ?? [];
                            _provinsi = null;
                            daftarKota = [];
                            _kota = null;
                          });
                        },
                      ),

                      const SizedBox(height: 12),
                      const Text("  Provinsi", style: TextStyle(fontSize: 12)),
                      _chipField(
                        items: daftarProvinsi,
                        value: _provinsi,
                        onChanged: (v) {
                          setState(() {
                            _provinsi = v;
                            daftarKota = negaraDataLengkap[_negara]?[v] ?? [];
                            _kota = null;
                          });
                        },
                      ),

                      const SizedBox(height: 12),
                      const Text("  Kota", style: TextStyle(fontSize: 12)),
                      _chipField(
                        items: daftarKota,
                        value: _kota,
                        onChanged: (v) => setState(() => _kota = v),
                      ),

                      const SizedBox(height: 12),
                      const Text("  Alamat", style: TextStyle(fontSize: 12)),
                      _lineField(_alamatController),

                      const SizedBox(height: 30),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.penanda,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _simpanProfil,
                          child: const Text("Simpan Profil", style: TextStyle(color: Colors.white)),
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
    return TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder())
    );
  }

  Widget _chipField({required List<String> items, required String? value, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: (items.contains(value)) ? value : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.view,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
      dropdownColor: AppColors.view,
      onChanged: onChanged,
    );
  }
}