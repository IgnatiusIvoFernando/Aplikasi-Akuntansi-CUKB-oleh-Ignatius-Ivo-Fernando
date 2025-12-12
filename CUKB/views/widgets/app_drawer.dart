import 'package:cukb/views/akuntansi/jurnal_umum_page.dart';
import 'package:cukb/views/akuntansi/saldo_akhir_page.dart';
import 'package:flutter/material.dart';
import '../../views/home/home_page.dart';
import '../../views/pengaturan/pengaturan_page.dart';

class AppDrawer extends StatefulWidget {
  final String selectedMenu;

  const AppDrawer({super.key, this.selectedMenu = ''});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? tappedMenu;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 250,
      backgroundColor: const Color(0xFFE8E4FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(width: 2, color: Colors.black),
              ),
              child: const Icon(Icons.person, size: 50),
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.black87,
            child: const Center(
              child: Text(
                "Nama Perusahaan",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          _buildMenuItem(
            id: "mengisi",
            title: "Mengisi Saldo",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            },
          ),
          const SizedBox(height: 5),
          _buildMenuItem(
            id: "jurnal",
            title: "Jurnal Umum",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const JurnalUmumPage()),
              );
              },
          ),
          const SizedBox(height: 5),
          _buildMenuItem(
            id: "saldo",
            title: "Saldo Akhir",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SaldoAkhirPage()),
              );            },
          ),
          const SizedBox(height: 5),
          _buildMenuItem(
            id: "pengaturan",
            title: "Pengaturan",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PengaturanPage()),
              );
            },
          ),

          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String id,
    required String title,
    required VoidCallback onTap,
  }) {
    bool isActive = widget.selectedMenu == id;
    bool isTapped = tappedMenu == id;

    return GestureDetector(
      onTapDown: (_) => setState(() => tappedMenu = id),
      onTapCancel: () => setState(() => tappedMenu = null),
      onTapUp: (_) {
        Future.delayed(const Duration(milliseconds: 120), () {
          setState(() => tappedMenu = null);
          onTap();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(left: isTapped ? 5 : 0),
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(colors: [Colors.blue, Colors.blueAccent])
              : const LinearGradient(
                  colors: [Color(0xFF2F2A60), Color(0xFF3A3470)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
        ),
        alignment: Alignment.centerLeft,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: TextStyle(
            color: Colors.white,
            fontSize: isTapped ? 16 : 15,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
          child: Text(title),
        ),
      ),
    );
  }
}
