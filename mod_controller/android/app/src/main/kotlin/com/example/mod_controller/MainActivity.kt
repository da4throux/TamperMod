package com.example.mod_controller

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIFI_CHANNEL = "com.example.mod_controller/wifi"
    private val DEVICE_CHANNEL = "com.example.mod_controller/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWiFiSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Cannot open WiFi settings", e.message)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    val isArc = packageManager.hasSystemFeature("org.chromium.arc") || 
                                packageManager.hasSystemFeature("org.chromium.arc.device_management") ||
                                (Build.DEVICE?.contains("cheets", ignoreCase = true) == true) ||
                                (Build.PRODUCT?.contains("cheets", ignoreCase = true) == true)
                    val isHatch = (Build.DEVICE?.contains("hatch", ignoreCase = true) == true) ||
                                  (Build.BOARD?.contains("hatch", ignoreCase = true) == true) ||
                                  (Build.PRODUCT?.contains("hatch", ignoreCase = true) == true) ||
                                  (Build.HARDWARE?.contains("hatch", ignoreCase = true) == true)
                    
                    val info = mapOf(
                        "isChromeOs" to isArc,
                        "isHatch" to isHatch,
                        "board" to (Build.BOARD ?: ""),
                        "device" to (Build.DEVICE ?: ""),
                        "product" to (Build.PRODUCT ?: ""),
                        "model" to (Build.MODEL ?: ""),
                        "brand" to (Build.BRAND ?: ""),
                        "hardware" to (Build.HARDWARE ?: "")
                    )
                    result.success(info)
                }
                else -> result.notImplemented()
            }
        }
    }
}
