import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingOverlay {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Container(color: Colors.black.withOpacity(0.5)),
          Center(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/lottie/loading.json',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  Text(
                    "กำลังโหลด...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

// ตัวอย่างการใช้งานในแอป
// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(home: MyHomePage());
//   }
// }

// class MyHomePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Loading Overlay Example")),
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ElevatedButton(
//               onPressed: () {
//                 // แสดง Loading Overlay
//                 LoadingOverlay.show(context);
//                 // จำลองการโหลด 3 วินาที
//                 Future.delayed(Duration(seconds: 3), () {
//                   LoadingOverlay.hide();
//                   ScaffoldMessenger.of(
//                     context,
//                   ).showSnackBar(SnackBar(content: Text("โหลดเสร็จสิ้น")));
//                 });
//               },
//               child: Text("แสดง Loading"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
