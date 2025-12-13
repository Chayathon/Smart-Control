// sos_binding.dart
import 'package:get/get.dart';
import 'package:sip_ua/sip_ua.dart'; 
// import 'package:your_project_name/sos_controller.dart'; // ถ้าคุณมี Controller

class SOSBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<SIPUAHelper>(SIPUAHelper()); 

    // ถ้าคุณใช้ Controller:
    // Get.lazyPut<SOSController>(() => SOSController(helper: Get.find()));
  }
}