import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive: initialise before any box is opened ───────────────────────────
  // hive_flutter calls Hive.init() with the app's documents directory so
  // box data survives app restarts.  We open the 'recommended_tutors' box
  // here at startup (typed as String — each value is a JSON blob) so
  // AnalyticsRepositoryImpl can call Hive.box() synchronously later without
  // needing an async box-open at call time.
  await Hive.initFlutter();
  await Hive.openBox<String>('recommended_tutors');

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDb2GN2-LekkIvCWHxosb4hAndg96JPSOo",
        authDomain: "calico-5980a.firebaseapp.com",
        projectId: "calico-5980a",
        storageBucket: "calico-5980a.firebasestorage.app",
        messagingSenderId: "1056254794426",
        appId: "1:1056254794426:web:c5180b737a674fd6188083",
        measurementId: "G-RT5XVGCN92",
      ),
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  runApp(const CalicoApp());
}
