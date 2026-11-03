package com.phytodoctor.fieldapp

import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.phytodoctor.fieldapp/share"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareText") {
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
            } else {
                result.notImplemented()
            }
        }
    }
}
