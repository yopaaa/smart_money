# Smart Money

Aplikasi pencatatan keuangan pribadi yang dibuat dengan Flutter. Smart Money membantu mencatat pemasukan, pengeluaran, dan transfer antar akun dalam satu tempat.

## Fitur Utama

- **Catat Transaksi** — Tambah transaksi pemasukan, pengeluaran, atau transfer antar akun. Setiap transaksi bisa dilengkapi catatan dan foto struk/bukti.
- **Input Suara** — Tambah transaksi lewat suara menggunakan Gemini AI. Cukup bicara, transaksi otomatis tercatat.
- **Kelola Akun** — Buat beberapa akun (kas, bank, e-wallet, dll) yang dikelompokkan berdasarkan jenisnya. Urutan akun dan grup bisa diatur sesuai kebutuhan.
- **Kategori Custom** — Buat dan atur urutan kategori pemasukan/pengeluaran sendiri.
- **Statistik** — Lihat ringkasan keuangan dalam bentuk grafik pie chart berdasarkan kategori dan periode waktu.
- **Galeri Struk** — Semua foto struk/bukti transaksi tersimpan rapi dan bisa dilihat di satu halaman galeri.
- **Backup & Restore** — Simpan data ke Google Drive atau file lokal (.smbak). Restore kapan saja di perangkat yang sama atau berbeda.
- **Sinkronisasi Foto** — Export foto struk ke `/sdcard/Pictures/SmartMoney` dan restore kembali jika diperlukan.
- **Laporan PDF** — Buat laporan bulanan dalam format PDF, bisa langsung di-share.
- **Export Data** — Export riwayat transaksi ke format CSV atau Excel.
- **Pengingat** — Atur notifikasi untuk mengingatkan mencatat transaksi.
- **Kunci PIN** — Lindungi data dengan PIN lock dan auto-lock.
- **Dark Mode** — Tampilan gelap yang nyaman di mata.
- **Multi Mata Uang** — Pilih mata uang yang sesuai.

## Screenshot

<!-- Tambahkan screenshot di sini -->

## Teknologi

- Flutter
- SQLite (sqflite) untuk penyimpanan lokal
- Google Sign-In & Google Drive API untuk backup cloud
- Gemini AI untuk input transaksi lewat suara

## Cara Menjalankan

1. Pastikan Flutter SDK sudah terinstall (versi ≥ 3.11.4)
2. Clone repository ini
3. Jalankan `flutter pub get`
4. Jalankan `flutter run`

Untuk build APK release:

```bash
flutter build apk --split-per-abi
```

File APK akan tersedia di `build/app/outputs/flutter-apk/`.



