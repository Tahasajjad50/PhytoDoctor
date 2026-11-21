package com.phytodoctor.fieldapp

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.provider.MediaStore
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.phytodoctor.fieldapp/native"
    private val LEGACY_CHANNEL = "com.phytodoctor.fieldapp/share"
    private val PERMISSION_REQUEST_CODE = 2001
    private val CAMERA_REQUEST_CODE = 2002

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingCameraResult: MethodChannel.Result? = null
    private var currentPhotoPath: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val handler = MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "shareText" -> {
                    val text = call.argument<String>("text")
                    val subject = call.argument<String>("subject")
                    val title = call.argument<String>("title") ?: "Share Credentials via"

                    try {
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            if (subject != null) {
                                putExtra(Intent.EXTRA_SUBJECT, subject)
                            }
                        }
                        val chooserIntent = Intent.createChooser(sendIntent, title)
                        startActivity(chooserIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                "requestPermissions" -> {
                    val permissions = arrayOf(
                        Manifest.permission.CAMERA,
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    )

                    val ungranted = permissions.filter {
                        ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                    }

                    if (ungranted.isEmpty()) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(this, ungranted.toTypedArray(), PERMISSION_REQUEST_CODE)
                    }
                }
                "checkPermissions" -> {
                    val cameraGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
                    val locationGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    result.success(mapOf(
                        "camera" to cameraGranted,
                        "location" to locationGranted
                    ))
                }
                "capturePhoto" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                        result.error("PERMISSION_DENIED", "Camera permission is required to capture field evidence.", null)
                        return@MethodCallHandler
                    }

                    try {
                        // Use durable app-private filesDir (never wiped by Android cache cleaners during low memory)
                        val imageDir = File(filesDir, "evidence_photos").apply { mkdirs() }
                        val imageFile = File(imageDir, "PHOTO_${System.currentTimeMillis()}.jpg")
                        currentPhotoPath = imageFile.absolutePath

                        val photoUri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            imageFile
                        )

                        val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                            putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }

                        pendingCameraResult = result
                        startActivityForResult(cameraIntent, CAMERA_REQUEST_CODE)
                    } catch (e: Exception) {
                        result.error("CAMERA_ERROR", e.message, null)
                    }
                }
                "getCurrentLocation" -> {
                    val fineGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val coarseGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

                    if (!fineGranted && !coarseGranted) {
                        result.error("PERMISSION_DENIED", "Location permission not granted", null)
                        return@MethodCallHandler
                    }

                    try {
                        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                        var bestLocation: Location? = null

                        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)) {
                            try {
                                if (locationManager.isProviderEnabled(provider)) {
                                    val loc = locationManager.getLastKnownLocation(provider)
                                    if (loc != null) {
                                        if (bestLocation == null || (loc.hasAccuracy() && loc.accuracy < (bestLocation?.accuracy ?: Float.MAX_VALUE))) {
                                            bestLocation = loc
                                        }
                                    }
                                }
                            } catch (_: Exception) {}
                        }

                        if (bestLocation != null) {
                            val isMock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                bestLocation.isMock
                            } else {
                                @Suppress("DEPRECATION")
                                bestLocation.isFromMockProvider
                            }
                            result.success(mapOf(
                                "latitude" to bestLocation.latitude,
                                "longitude" to bestLocation.longitude,
                                "accuracy" to (if (bestLocation.hasAccuracy()) bestLocation.accuracy.toDouble() else 15.0),
                                "isMock" to isMock,
                                "provider" to (bestLocation.provider ?: "gps")
                            ))
                        } else {
                            val listener = object : LocationListener {
                                override fun onLocationChanged(loc: Location) {
                                    locationManager.removeUpdates(this)
                                    val isMock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) loc.isMock else loc.isFromMockProvider
                                    result.success(mapOf(
                                        "latitude" to loc.latitude,
                                        "longitude" to loc.longitude,
                                        "accuracy" to (if (loc.hasAccuracy()) loc.accuracy.toDouble() else 15.0),
                                        "isMock" to isMock,
                                        "provider" to (loc.provider ?: "gps")
                                    ))
                                }
                                @Deprecated("Deprecated in Java")
                                override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
                                override fun onProviderEnabled(p: String) {}
                                override fun onProviderDisabled(p: String) {}
                            }
                            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                                locationManager.requestSingleUpdate(LocationManager.GPS_PROVIDER, listener, Looper.getMainLooper())
                            } else if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                                locationManager.requestSingleUpdate(LocationManager.NETWORK_PROVIDER, listener, Looper.getMainLooper())
                            } else {
                                result.error("LOCATION_UNAVAILABLE", "No location providers enabled on device", null)
                            }
                        }
                    } catch (e: Exception) {
                        result.error("LOCATION_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(handler)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LEGACY_CHANNEL).setMethodCallHandler(handler)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(allGranted)
            pendingPermissionResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CAMERA_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                val path = currentPhotoPath
                if (path != null && File(path).exists() && File(path).length() > 0) {
                    pendingCameraResult?.success(path)
                } else {
                    pendingCameraResult?.error("PHOTO_EMPTY", "Captured photo file not found or empty", null)
                }
            } else {
                pendingCameraResult?.success(null) // User dismissed/cancelled camera
            }
            pendingCameraResult = null
        }
    }
}
