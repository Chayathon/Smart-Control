import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:smart_control/core/services/deep_link_service.dart';
import 'package:smart_control/routes/app_pages.dart';
import 'package:smart_control/routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Initialize deep link service
  await DeepLinkService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'GetX Navigation Demo',
      debugShowCheckedModeBanner: false,
      getPages: AppPages.pages,
      theme: ThemeData(fontFamily: 'Kanit'),
      initialRoute: AppRoutes.splash,
    );
  }
}
