package com.example.aiyardimci

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.aiyardimci/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "muteSystem" -> {
                        am.adjustStreamVolume(
                            AudioManager.STREAM_SYSTEM,
                            AudioManager.ADJUST_MUTE,
                            0
                        )
                        result.success(null)
                    }
                    "unmuteSystem" -> {
                        am.adjustStreamVolume(
                            AudioManager.STREAM_SYSTEM,
                            AudioManager.ADJUST_UNMUTE,
                            0
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
