import 'dart:convert';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

/// View MC letter image in a dialog (staff, admin, or supervisor).
Future<void> showMcLetterDialog(
  BuildContext context, {
  required String requestId,
  String? staffId,
  bool asAdmin = false,
  bool asSupervisor = false,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _McLetterDialog(
      requestId: requestId,
      staffId: staffId,
      asAdmin: asAdmin,
      asSupervisor: asSupervisor,
    ),
  );
}

class _McLetterDialog extends StatefulWidget {
  final String requestId;
  final String? staffId;
  final bool asAdmin;
  final bool asSupervisor;

  const _McLetterDialog({
    required this.requestId,
    this.staffId,
    required this.asAdmin,
    this.asSupervisor = false,
  });

  @override
  State<_McLetterDialog> createState() => _McLetterDialogState();
}

class _McLetterDialogState extends State<_McLetterDialog> {
  bool _loading = true;
  String? _error;
  String? _dataUrl;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = widget.asAdmin
          ? await ApiService.getAdminLeaveMcLetter(widget.requestId)
          : widget.asSupervisor
              ? await ApiService.getSupervisorLeaveMcLetter(widget.requestId)
              : await ApiService.getLeaveMcLetter(widget.requestId, staffId: widget.staffId);
      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _loading = false;
          _dataUrl = data['mcLetter'] as String?;
          _fileName = data['mcLetterFileName'] as String?;
        });
      } else {
        setState(() {
          _loading = false;
          _error = result['message'] as String? ?? 'Could not load MC letter';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Connection error while loading MC letter';
      });
    }
  }

  ImageProvider? _imageProvider() {
    final url = _dataUrl;
    if (url == null || url.isEmpty) return null;
    try {
      final base64 = url.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
      return MemoryImage(base64Decode(base64));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _imageProvider();
    return AlertDialog(
      backgroundColor: context.appColors.card,
      title: Text(
        'MC letter',
        style: TextStyle(color: context.appColors.textPrimary),
      ),
      content: SizedBox(
        width: 320,
        child: _loading
            ? SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(color: context.appColors.accentBlue)),
              )
            : _error != null
                ? Text(_error!, style: TextStyle(color: Colors.redAccent))
                : img == null
                    ? Text('MC image not available', style: TextStyle(color: context.appColors.textSecondary))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_fileName != null && _fileName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _fileName!,
                                style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                              ),
                            ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4,
                              child: Image(image: img, fit: BoxFit.contain),
                            ),
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: TextStyle(color: context.appColors.accentBlue)),
        ),
      ],
    );
  }
}
