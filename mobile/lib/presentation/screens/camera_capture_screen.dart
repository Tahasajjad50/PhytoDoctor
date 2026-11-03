import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({Key? key}) : super(key: key);

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  bool _isCaptured = false;
  String _capturedId = '';

  void _takePicture() {
    setState(() {
      _isCaptured = true;
      _capturedId = 'PHOTO_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
  }

  void _retake() {
    setState(() {
      _isCaptured = false;
      _capturedId = '';
    });
  }

  void _confirm() {
    Navigator.pop(context, _capturedId);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'In-App Hardware Camera',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.alertCrimson,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'LIVE SENSOR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Viewfinder Container
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera Simulation Viewport
                  Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2820), // Dark botanical lens shade
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isCaptured ? Icons.photo : Icons.camera_enhance_outlined,
                            size: 64,
                            color: _isCaptured ? AppTheme.cropGreen : Colors.white38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isCaptured
                                ? 'Photo Ready for Inspection'
                                : 'Align Shop Board or Crop Field in Frame',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Viewfinder Crosshairs
                  if (!_isCaptured)
                    Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                      ),
                    ),

                  // Watermark Overlay Banner (Lower Third)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'PHYTO DOCTOR FIELD AUDIT',
                                style: TextStyle(
                                  color: Color(0xFF81C784),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'GPS ACCURACY: ±12.4m',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Coordinates: 31.5204° N, 74.3587° E • Timestamp: $timeStr',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Shutter & Action Bar
            Container(
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              color: Colors.black,
              child: _isCaptured
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _retake,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Retake', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white60),
                            minimumSize: const Size(130, 48),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _confirm,
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Confirm Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cropGreen,
                            minimumSize: const Size(140, 48),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Large Shutter Button (52px+ touch target)
                        GestureDetector(
                          onTap: _takePicture,
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
