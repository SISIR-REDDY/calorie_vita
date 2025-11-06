package com.sisirlabs.calorievita

import android.content.SharedPreferences
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.RequiresApi
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@RequiresApi(Build.VERSION_CODES.P)
class MainActivity : FlutterActivity() {
    private lateinit var healthConnectPlugin: HealthConnectPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register Health Connect plugin
        healthConnectPlugin = HealthConnectPlugin()
        healthConnectPlugin.context = applicationContext
        val methodChannel = io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "health_connect")
        methodChannel.setMethodCallHandler(healthConnectPlugin)
    }
} 