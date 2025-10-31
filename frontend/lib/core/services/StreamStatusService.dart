// ignore_for_file: avoid_print, file_names
import 'dart:convert';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:smart_control/core/config/app_config.dart';

class StreamStatusService {
  Function(Map<String, dynamic>)? onStatusUpdate;

  void connect() {
    SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: AppConfig.ssePlaylistStatus,
      header: {
        "Accept": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
      },
    ).listen(
      (event) {
        if (event.event == 'status' && event.data != null) {
          try {
            final data = jsonDecode(event.data!);
            print("SSE status: $data");
            onStatusUpdate?.call(data);
          } catch (e) {
            print("Error parsing SSE data: $e");
          }
        }
      },
      onError: (error) {
        print("SSE Error: $error");
      },
    );
  }
}
