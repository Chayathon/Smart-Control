import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:smart_control/core/network/api_service.dart';
import 'package:smart_control/widgets/song_upload/song_model.dart';

class SongService {
  // Utility methods
  static String normalizeYouTubeUrl(String raw) {
    final text = raw.trim();
    final short = RegExp(r'^https?:\/\/youtu\.be\/([A-Za-z0-9_-]{6,})');
    final m = short.firstMatch(text);
    if (m != null) {
      return 'https://www.youtube.com/watch?v=${m.group(1)!}';
    }
    return text;
  }

  static bool looksLikeYouTubeUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('youtube.com/watch') || u.contains('youtu.be/');
  }

  // API methods
  static Future<List<Song>> getSongs() async {
    final api = await ApiService.private();
    final result = await api.get("/song");

    if (result['ok'] == true) {
      return (result['data'] as List<dynamic>)
          .map((item) => Song.fromJson(item))
          .toList();
    } else {
      throw Exception('Failed to load songs');
    }
  }

  static Future<Song> getSongById(String id) async {
    final api = await ApiService.private();
    final result = await api.get("/song/$id");

    if (result['ok'] == true && result['data'] != null) {
      return Song.fromJson(result['data']);
    }

    throw Exception('Failed to get song');
  }

  static Future<Map<String, dynamic>> uploadSongFile({
    required String filePath,
    required String fileName,
    required String displayName,
  }) async {
    final normalizedFileName = fileName.toLowerCase().endsWith('.mp3')
        ? fileName
        : '$fileName.mp3';

    final formData = FormData.fromMap({
      'filename': displayName,
      'song': await MultipartFile.fromFile(
        filePath,
        filename: normalizedFileName,
        contentType: MediaType('audio', 'mpeg'),
      ),
    });

    final api = await ApiService.private();
    final res = await api.post<Map<String, dynamic>>(
      "/song/uploadSongFile",
      data: formData,
    );

    return res;
  }

  static Future<Map<String, dynamic>> uploadSongYouTube({
    required String youtubeUrl,
    String? name,
  }) async {
    final normalizedUrl = normalizeYouTubeUrl(youtubeUrl);

    if (!looksLikeYouTubeUrl(normalizedUrl)) {
      throw Exception('URL ไม่ใช่ลิงก์ YouTube ที่รองรับ');
    }

    final api = await ApiService.private();
    final payload = {
      "url": normalizedUrl,
      if (name != null && name.trim().isNotEmpty) "filename": name.trim(),
    };

    final res = await api.post<Map<String, dynamic>>(
      "/song/uploadSongYT",
      data: payload,
      options: Options(
        sendTimeout: const Duration(minutes: 1),
        receiveTimeout: const Duration(minutes: 6),
      ),
    );

    return res;
  }

  static Future<Map<String, dynamic>> updateSong(
    String id,
    String newName,
  ) async {
    final api = await ApiService.private();
    final res = await api.patch("/song/update/$id", data: {'newName': newName});

    return res;
  }

  static Future<Map<String, dynamic>> deleteSong(String id) async {
    final api = await ApiService.private();
    final res = await api.delete<Map<String, dynamic>>('/song/remove/$id');

    return res;
  }
}
