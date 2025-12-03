import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:smart_control/routes/app_routes.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    _appLinks = AppLinks();
    _isInitialized = true;

    // Handle initial link (app opened from link)
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink);
    }

    // Handle links while app is running
    _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    print('🔗 Deep link received: $uri');
    
    // Parse the path from the URI
    // Example: smartcontrol://stream -> path is "stream"
    final path = uri.host.isNotEmpty ? uri.host : uri.path;
    
    switch (path) {
      case 'stream':
        _navigateToStream();
        break;
      case 'playlist':
        Get.toNamed(AppRoutes.playlist);
        break;
      case 'home':
        Get.toNamed(AppRoutes.home);
        break;
      default:
        print('⚠️ Unknown deep link path: $path');
        // Default to home if unknown
        Get.toNamed(AppRoutes.home);
    }
  }

  void _navigateToStream() {
    // Check if we're already on the stream screen
    if (Get.currentRoute == AppRoutes.stream) {
      print('📍 Already on stream screen');
      return;
    }
    
    // Navigate to stream screen
    Get.toNamed(AppRoutes.stream);
  }
}
