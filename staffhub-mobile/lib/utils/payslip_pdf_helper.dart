import 'dart:convert';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PayslipPdfHelper {
  static Future<String?> saveAndOpen({
    required String dataUrl,
    required String fileName,
  }) async {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return 'Invalid PDF data';
    final base64Part = dataUrl.substring(comma + 1);
    final bytes = base64Decode(base64Part);
    final dir = await getTemporaryDirectory();
    final safeName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      return result.message;
    }
    return null;
  }
}
