package com.example.thesis_reader

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var volumeKeyChannel: MethodChannel? = null
    private var isVolumeKeyNavigationEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeKeyChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOLUME_KEY_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVolumeKeyNavigationEnabled" -> {
                        isVolumeKeyNavigationEnabled = call.arguments == true
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isVolumeKeyNavigationEnabled && event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeKeyChannel?.invokeMethod("volumeDown", null)
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeKeyChannel?.invokeMethod("volumeUp", null)
                    return true
                }
            }
        }

        return super.dispatchKeyEvent(event)
    }

    companion object {
        private const val VOLUME_KEY_CHANNEL = "thesis_reader/volume_keys"
    }
}
