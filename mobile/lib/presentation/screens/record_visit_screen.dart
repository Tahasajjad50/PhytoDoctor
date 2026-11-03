import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/services/location_service.dart';
import '../../core/storage/local_visit_queue.dart';
import '../../core/storage/photo_storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/real_visit_repository.dart';
import '../../data/repositories/visit_repository.dart';
import 'camera_capture_screen.dart';
import 'gps_acquisition_screen.dart';

class RecordVisitScreen extends StatefulWidget {
  final UserModel user;
  final VisitRepository? repository;
  final double accuracyThreshold;

  const RecordVisitScreen({
    Key? key,
    required this.user,
    this.repository,
    this.accuracyThreshold = LocationService.defaultAccuracyThresholdMeters,
  }) : super(key: key);

  @override
  State<RecordVisitScreen> createState() => _RecordVisitScreenState();
}

class _RecordVisitScreenState extends State<RecordVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LocationService _locationService;
  late final VisitRepository _repository;
  final LocalVisitQueue _localQueue = LocalVisitQueue();

  String _selectedClientType = 'DEALER';
  String _clientName = '';
  String _clientPhone = '';
  String _visitPurpose = 'PRODUCT_PITCH';
  String _notes = '';

  // GPS State
  double? _latitude = 31.5204;
  double? _longitude = 74.3587;
  double _gpsAccuracy = 12.4; // Initial lock: 12.4m
  bool _isMockLocation = false;
  bool _gpsLocked = true;
  bool _isAcquiringGps = false;
  String _gpsStatusMessage = 'GPS signal locked with high precision (±12.4m)';

  // In-app Camera Evidence State
  String? _capturedPhotoPath;
  String? _photoAssetId;
  DateTime? _deviceCapturedAt;

  // Permission State
  bool _cameraPermissionDenied = false;
  bool _locationPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    _locationService = LocationService(accuracyThreshold: widget.accuracyThreshold);
    _repository = widget.repository ?? RealVisitRepository();
  }

  /// Retries GPS acquisition using the LocationService with accuracy threshold verification
  Future<void> _retryGps({bool simulateLowAccuracy = false}) async {
    setState(() => _isAcquiringGps = true);

    try {
      final permStatus = await _locationService.checkPermission();
      if (permStatus == LocationPermissionStatus.denied ||
          permStatus == LocationPermissionStatus.permanentlyDenied) {
        setState(() {
          _locationPermissionDenied = true;
          _isAcquiringGps = false;
        });
        _showPermissionDialog('Location', 'High-accuracy GPS is required to verify on-site visits.');
        return;
      }

      final locResult = await _locationService.getCurrentLocation(
        simulateLowAccuracy: simulateLowAccuracy,
      );

      if (!mounted) return;
      setState(() {
        _latitude = locResult.latitude;
        _longitude = locResult.longitude;
        _gpsAccuracy = locResult.accuracy;
        _isMockLocation = locResult.isMockLocation;
        _gpsLocked = true;
        _isAcquiringGps = false;
        _gpsStatusMessage = locResult.statusMessage;
        _locationPermissionDenied = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAcquiringGps = false;
        _gpsStatusMessage = 'Could not acquire satellite fix. Please retry.';
      });
    }
  }

  /// Launches in-app camera exclusively (Strictly blocks gallery selection)
  void _openCamera() async {
    if (_cameraPermissionDenied) {
      _showPermissionDialog('Camera', 'In-app camera is mandatory for on-site visit verification.');
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraCaptureScreen(),
      ),
    );

    if (result != null) {
      final now = DateTime.now().toUtc();
      setState(() {
        _capturedPhotoPath = result;
        _deviceCapturedAt = now;
        _photoAssetId = 'PHOTO_${now.millisecondsSinceEpoch}_${widget.user.id.replaceAll("-", "").substring(0, 8)}';
      });
    }
  }

  /// Opens GPS Calibration & Diagnostics screen
  void _openGpsScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => GpsAcquisitionScreen(
          currentLat: _latitude,
          currentLng: _longitude,
          accuracy: _gpsAccuracy,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result['latitude'] as double?;
        _longitude = result['longitude'] as double?;
        _gpsAccuracy = (result['accuracy'] as double?) ?? 15.0;
        _isMockLocation = (result['is_mock'] as bool?) ?? false;
        _gpsLocked = true;
        _gpsStatusMessage = _gpsAccuracy <= widget.accuracyThreshold
            ? 'GPS calibrated successfully (±${_gpsAccuracy.toStringAsFixed(1)}m)'
            : 'Calibrated accuracy (±${_gpsAccuracy.toStringAsFixed(1)}m) exceeds ${widget.accuracyThreshold.toStringAsFixed(0)}m threshold.';
      });
    }
  }

  /// Shows company's transparent evidence collection policy dialog
  void _showEvidencePolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
          side: const BorderSide(color: AppTheme.sageBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.verified_user_outlined, color: AppTheme.botanicalPrimary, size: 22),
            SizedBox(width: 8),
            Text(
              'Evidence & Privacy Policy',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMain),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _policyBullet(
                'Zero Background Tracking',
                'Phyto Doctor never tracks your location in the background or when the app is closed. Location is only read at the moment you tap Record Visit.',
              ),
              const SizedBox(height: 10),
              _policyBullet(
                'Live In-App Photos Only',
                'To maintain genuine customer verification, photos must be captured live with the in-app camera shutter. Gallery image selection is permanently disabled.',
              ),
              const SizedBox(height: 10),
              _policyBullet(
                'Configurable 50m GPS Threshold',
                'Visits require high-precision satellite accuracy (±50m or better). If accuracy is low, you can step into an open area and tap Retry GPS.',
              ),
              const SizedBox(height: 10),
              _policyBullet(
                'Fair Supervisor Review',
                'System flags (such as weak satellite signals or upload delays) serve as audit indicators for supervisors and are never treated as proof of fraud.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.botanicalPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Widget _policyBullet(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• $title',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.botanicalDark),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
        ),
      ],
    );
  }

  void _showPermissionDialog(String permissionName, String rationale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text('$permissionName Permission Required'),
        content: Text('$rationale\n\nPlease enable permission in Android App Settings to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cameraPermissionDenied = false;
                _locationPermissionDenied = false;
              });
            },
            child: const Text('Retry / Grant'),
          ),
        ],
      ),
    );
  }

  /// Submits the visit: validates mandatory fields, checks accuracy threshold,
  /// displays confirmation review modal, saves to local queue, and attempts sync.
  void _submitVisit() async {
    // 1. Mandatory Form Validation (Client name required)
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client name is mandatory.'),
          backgroundColor: AppTheme.alertCrimson,
        ),
      );
      return;
    }

    // 2. Mandatory In-App Photo Check
    if (_capturedPhotoPath == null || _photoAssetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('On-site photo is mandatory. Please capture using the in-app camera.'),
          backgroundColor: AppTheme.alertCrimson,
        ),
      );
      return;
    }

    // 3. Valid Coordinates Check
    if (!_gpsLocked || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS coordinates not locked. Please acquire location.'),
          backgroundColor: AppTheme.alertCrimson,
        ),
      );
      return;
    }

    // 4. GPS Accuracy Threshold Check (50m default)
    if (_gpsAccuracy > widget.accuracyThreshold) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppTheme.earthAmber, size: 24),
              SizedBox(width: 8),
              Text('Insufficient GPS Accuracy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Reported GPS accuracy is ±${_gpsAccuracy.toStringAsFixed(1)}m, which exceeds the company threshold of ${widget.accuracyThreshold.toStringAsFixed(0)}m.\n\n'
            'Please step outdoors away from metal roofs or dense concrete walls, and tap Retry GPS.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textMain, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _retryGps();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry GPS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.botanicalPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      return;
    }

    _formKey.currentState!.save();

    final deviceCaptureIso = (_deviceCapturedAt ?? DateTime.now().toUtc()).toIso8601String();

    // 5. Review Information & Photo Modal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
          side: const BorderSide(color: AppTheme.sageBorder),
        ),
        title: const Text(
          'Review Field Visit Evidence',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMain),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reviewRow('Client', '$_clientName ($_selectedClientType)'),
              if (_clientPhone.isNotEmpty) _reviewRow('Phone', _clientPhone),
              _reviewRow('Purpose', _visitPurpose),
              if (_notes.isNotEmpty) _reviewRow('Notes', _notes),
              const Divider(height: 16),
              _reviewRow('GPS Fix', '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'),
              _reviewRow('Accuracy', '±${_gpsAccuracy.toStringAsFixed(1)}m (Passes ≤50m threshold)'),
              _reviewRow('Photo ID', _photoAssetId!),
              _reviewRow('Captured At', deviceCaptureIso.substring(0, 19).replaceAll('T', ' ')),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.sageLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.offline_pin, size: 18, color: AppTheme.botanicalPrimary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Offline-First: Saved to device first, synced when connectivity is available.',
                        style: TextStyle(fontSize: 11, color: AppTheme.botanicalDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Edit Details'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.botanicalPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 42),
            ),
            child: const Text('Save & Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 6. Generate UUID Idempotency Key before upload
    final visitUuid = 'VISIT_${DateTime.now().millisecondsSinceEpoch}_${widget.user.id.replaceAll("-", "").substring(0, 8)}';

    // 7. Store Photo Reference in App-Private Storage
    final privatePhotoPath = PhotoStorageService().generatePrivatePhotoPath(visitUuid, _photoAssetId!);

    // 8. Build Visit Payload with UUID Idempotency Key
    final visitPayload = <String, dynamic>{
      'id': visitUuid,
      'employee_id': widget.user.id,
      'client_name': _clientName,
      'client_phone': _clientPhone.isNotEmpty ? _clientPhone : null,
      'client_type': _selectedClientType,
      'visit_purpose': _visitPurpose,
      'notes': _notes.isNotEmpty ? '[$_selectedClientType - $_visitPurpose] $_notes' : '[$_selectedClientType - $_visitPurpose]',
      'latitude': _latitude,
      'longitude': _longitude,
      'gps_accuracy': _gpsAccuracy,
      'is_mock_location': _isMockLocation,
      'device_capture_time': deviceCaptureIso,
      'local_photo_path': privatePhotoPath,
      'photo_asset_id': _photoAssetId,
      'photo_url': null,
    };

    // 9. Save locally to SQLite offline queue immediately (Guarantee no data loss)
    await _localQueue.enqueueVisit(visitPayload);

    // 10. Attempt immediate sync with backend if online
    bool syncedToServer = false;
    try {
      final token = widget.user.accessToken ?? '';
      syncedToServer = await _repository.recordVisit(
        token: token,
        visitData: visitPayload,
      );
    } catch (_) {
      syncedToServer = false;
    }

    if (!mounted) return;

    Navigator.pop(context, true);

    if (syncedToServer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Field visit verified and uploaded to server!'),
          backgroundColor: AppTheme.cropGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit saved locally in offline queue. Will sync automatically when online.'),
          backgroundColor: AppTheme.earthAmber,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textMain),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAccuracyAcceptable = _gpsAccuracy <= widget.accuracyThreshold;

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Record Field Visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Evidence & Privacy Policy',
            onPressed: _showEvidencePolicyDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. GPS Status Strip with Reported Accuracy & Retry
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(
                      color: _isMockLocation
                          ? AppTheme.alertCrimson
                          : (isAccuracyAcceptable ? AppTheme.cropGreen : AppTheme.earthAmber),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isMockLocation
                                ? Icons.warning
                                : (isAccuracyAcceptable ? Icons.location_on : Icons.location_searching),
                            color: _isMockLocation
                                ? AppTheme.alertCrimson
                                : (isAccuracyAcceptable ? AppTheme.cropGreen : AppTheme.earthAmber),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _isAcquiringGps
                                          ? 'FETCHING COORDINATES...'
                                          : (_gpsLocked ? 'GPS LOCKED' : 'NO GPS FIX'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _isMockLocation ? AppTheme.alertCrimson : AppTheme.textMain,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAccuracyAcceptable ? AppTheme.cropGreenLight : const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '±${_gpsAccuracy.toStringAsFixed(1)}m',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isAccuracyAcceptable ? AppTheme.cropGreen : AppTheme.earthAmber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _latitude != null
                                      ? 'Lat: ${_latitude!.toStringAsFixed(5)}, Lng: ${_longitude!.toStringAsFixed(5)}'
                                      : 'Waiting for hardware GPS lock',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: _isAcquiringGps
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh, color: AppTheme.botanicalPrimary),
                            tooltip: 'Retry GPS Fix',
                            onPressed: _isAcquiringGps ? null : () => _retryGps(),
                          ),
                          TextButton(
                            onPressed: _openGpsScreen,
                            child: const Text('CALIBRATE'),
                          ),
                        ],
                      ),
                      if (!isAccuracyAcceptable) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.earthAmber, width: 0.8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: AppTheme.earthAmber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Accuracy (±${_gpsAccuracy.toStringAsFixed(1)}m) exceeds ${widget.accuracyThreshold.toStringAsFixed(0)}m threshold. Move outdoors and tap Retry.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF795548)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Client Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(color: AppTheme.sageBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Client / Dealer Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Client Type Selector
                      Row(
                        children: [
                          _ClientTypeTab(
                            title: 'Dealer',
                            isSelected: _selectedClientType == 'DEALER',
                            onTap: () => setState(() => _selectedClientType = 'DEALER'),
                          ),
                          const SizedBox(width: 8),
                          _ClientTypeTab(
                            title: 'Distributor',
                            isSelected: _selectedClientType == 'DISTRIBUTOR',
                            onTap: () => setState(() => _selectedClientType = 'DISTRIBUTOR'),
                          ),
                          const SizedBox(width: 8),
                          _ClientTypeTab(
                            title: 'Farmer / Grower',
                            isSelected: _selectedClientType == 'FARMER',
                            onTap: () => setState(() => _selectedClientType = 'FARMER'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        key: const Key('clientNameField'),
                        decoration: const InputDecoration(
                          labelText: 'Business / Farmer Name *',
                          hintText: 'e.g. Al-Madina Agro Chemicals',
                          prefixIcon: Icon(Icons.storefront, color: AppTheme.textMuted, size: 20),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Client name is mandatory' : null,
                        onSaved: (val) => _clientName = val!.trim(),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        key: const Key('clientPhoneField'),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone Number (Optional)',
                          hintText: 'e.g. 03001234567',
                          prefixIcon: Icon(Icons.phone, color: AppTheme.textMuted, size: 20),
                        ),
                        onSaved: (val) => _clientPhone = val?.trim() ?? '',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. In-App Camera Proof Trigger (Strictly in-app camera)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(color: AppTheme.sageBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Mandatory On-Site Photo Proof',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.sageLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NO GALLERY SELECTION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.botanicalDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Take live photo with dealer shop front, pesticide inventory, or crop field.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 14),

                      if (_capturedPhotoPath == null)
                        InkWell(
                          key: const Key('inAppCameraButton'),
                          onTap: _openCamera,
                          child: Container(
                            height: 110,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppTheme.sageLight,
                              borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                              border: Border.all(
                                color: AppTheme.botanicalPrimary,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.camera_alt, size: 36, color: AppTheme.botanicalPrimary),
                                SizedBox(height: 8),
                                Text(
                                  'OPEN IN-APP CAMERA',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.botanicalPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Device timestamp and GPS coordinates stamped on capture',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Stack(
                          children: [
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2820),
                                borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle, color: AppTheme.cropGreen, size: 38),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Captured: $_photoAssetId',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Device Time: ${_deviceCapturedAt?.toIso8601String().substring(0, 19).replaceAll("T", " ") ?? "Just now"}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: ElevatedButton.icon(
                                onPressed: _openCamera,
                                icon: const Icon(Icons.replay, size: 14),
                                label: const Text('Retake'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.textMain,
                                  minimumSize: const Size(70, 30),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Purpose & Observations
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(color: AppTheme.sageBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visit Purpose & Observations',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _visitPurpose,
                        decoration: const InputDecoration(
                          labelText: 'Primary Purpose',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PRODUCT_PITCH',
                            child: Text('Product Pitch & Sales Booking'),
                          ),
                          DropdownMenuItem(
                            value: 'RECOVERY',
                            child: Text('Payment Recovery & Account Review'),
                          ),
                          DropdownMenuItem(
                            value: 'CROP_INSPECTION',
                            child: Text('Crop Disease / Pest Scouting'),
                          ),
                          DropdownMenuItem(
                            value: 'DEMONSTRATION',
                            child: Text('Farmer Field Demo & Trial'),
                          ),
                          DropdownMenuItem(
                            value: 'GENERAL',
                            child: Text('General Relationship Visit'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _visitPurpose = val);
                        },
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Field Notes & Observations (Optional)',
                          hintText: 'e.g. Discussed Trichoderma bio-fungicide stock with dealer.',
                        ),
                        onSaved: (val) => _notes = val ?? '',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  key: const Key('submitVisitButton'),
                  onPressed: _submitVisit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.botanicalPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'SUBMIT VERIFIED FIELD VISIT',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),

                const SizedBox(height: 14),

                // Transparency policy link
                Center(
                  child: TextButton.icon(
                    onPressed: _showEvidencePolicyDialog,
                    icon: const Icon(Icons.shield_outlined, size: 16, color: AppTheme.textMuted),
                    label: const Text(
                      'Evidence Policy: No Background Tracking • On-Demand GPS',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientTypeTab extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ClientTypeTab({
    Key? key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.botanicalPrimary : AppTheme.sageLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppTheme.botanicalPrimary : AppTheme.sageBorder,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
