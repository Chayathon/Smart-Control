import 'package:get/get.dart';
import 'package:smart_control/mic.dart';
import 'package:smart_control/screens/home_screen.dart';
import 'package:smart_control/screens/login/login_screen.dart';
import 'package:smart_control/screens/playlist/playlist_screen.dart';
import 'package:smart_control/screens/settings/schedule/schedule_screen.dart';
import 'package:smart_control/screens/settings/system/system_screen.dart';
import 'package:smart_control/screens/song/song_screen.dart';
import 'package:smart_control/screens/splash_screen/splash_screen.dart';
import 'package:smart_control/screens/monitoring/monitoring_screen.dart';

import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.home, page: () => const HomeScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(name: AppRoutes.playlist, page: () => const PlaylistScreen()),
    GetPage(name: AppRoutes.song, page: () => const SongScreen()),
    GetPage(name: AppRoutes.monitoring, page: () => const MonitoringScreen()),
    GetPage(name: AppRoutes.system, page: () => const SystemScreen()),
    GetPage(name: AppRoutes.schedule, page: () => const ScheduleScreen()),
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.test, page: () => const MicPage()),
  ];
}
