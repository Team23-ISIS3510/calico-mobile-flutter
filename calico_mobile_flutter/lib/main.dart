import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
