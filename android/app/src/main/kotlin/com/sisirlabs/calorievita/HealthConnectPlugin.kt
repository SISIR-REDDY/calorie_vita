package com.sisirlabs.calorievita

import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.ZoneId

@RequiresApi(Build.VERSION_CODES.P)
class HealthConnectPlugin : MethodChannel.MethodCallHandler {
    var context: Context? = null
    private var healthConnectClient: HealthConnectClient? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkAvailability" -> checkAvailability(result)
            "requestPermissions" -> requestPermissions(result)
            "getTodaySteps" -> getTodaySteps(result)
            "getTodayCalories" -> getTodayCalories(result)
            "getTodayWorkouts" -> getTodayWorkouts(result)
            "getTodayData" -> getTodayData(result)
            "openHealthConnectSettings" -> openHealthConnectSettings(result)
            else -> result.notImplemented()
        }
    }

    private fun checkAvailability(result: MethodChannel.Result) {
        try {
            val ctx = context ?: return result.error("NO_CONTEXT", "Context not set", null)
            
            // Check if Health Connect is actually installed on the device
            val sdkStatus = HealthConnectClient.getSdkStatus(ctx)
            
            when (sdkStatus) {
                HealthConnectClient.SDK_AVAILABLE -> {
                    // Health Connect is installed and available
                    val client = HealthConnectClient.getOrCreate(ctx)
                    healthConnectClient = client
                    result.success(true)
                }
                HealthConnectClient.SDK_UNAVAILABLE -> {
                    // Health Connect is not installed
                    result.success(false)
                }
                HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> {
                    // Health Connect needs to be updated
                    result.success(false)
                }
                else -> {
                    // Unknown status, assume not available
                    result.success(false)
                }
            }
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val ctx = context ?: return@launch result.error("NO_CONTEXT", "Context not set", null)
                val client = HealthConnectClient.getOrCreate(ctx)
                healthConnectClient = client

                // Define required permissions for Health Connect - Both calorie types for smart fallback
                val permissions = setOf(
                    androidx.health.connect.client.permission.HealthPermission.getReadPermission(StepsRecord::class),
                    androidx.health.connect.client.permission.HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
                    androidx.health.connect.client.permission.HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
                    androidx.health.connect.client.permission.HealthPermission.getReadPermission(ExerciseSessionRecord::class)
                )

                // Check if permissions are already granted
                val granted = client.permissionController.getGrantedPermissions()
                
                if (granted.containsAll(permissions)) {
                    // All permissions already granted
                    result.success(true)
                } else {
                    // Some permissions missing - need to request them
                    // Note: Health Connect SDK 1.1.0-alpha07 requires users to grant permissions
                    // through the Health Connect app settings manually
                    // The app cannot programmatically request permissions like regular Android permissions
                    
                    // Return false to indicate permissions not granted
                    // Flutter code should guide user to Health Connect settings
                    result.success(false)
                }
            } catch (e: Exception) {
                result.error("PERMISSION_ERROR", e.message, null)
            }
        }
    }

    private fun getTodaySteps(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val ctx = context ?: return@launch withContext(Dispatchers.Main) { result.error("NO_CONTEXT", "Context not set", null) }
                val client = healthConnectClient ?: HealthConnectClient.getOrCreate(ctx)
                healthConnectClient = client

                val today = LocalDate.now()
                val startOfDay = today.atStartOfDay(ZoneId.systemDefault())
                val endOfDay = today.atTime(23, 59, 59).atZone(ZoneId.systemDefault())

                val request = AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(
                        startOfDay.toInstant(),
                        endOfDay.toInstant()
                    )
                )

                val response = client.aggregate(request)
                val steps = (response[StepsRecord.COUNT_TOTAL] as? Long)?.toInt() ?: 0

                withContext(Dispatchers.Main) {
                    result.success(steps)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("STEPS_ERROR", e.message, null)
                }
            }
        }
    }

    private fun getTodayCalories(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val ctx = context ?: return@launch withContext(Dispatchers.Main) { result.error("NO_CONTEXT", "Context not set", null) }
                val client = healthConnectClient ?: HealthConnectClient.getOrCreate(ctx)
                healthConnectClient = client

                val today = LocalDate.now()
                val startOfDay = today.atStartOfDay(ZoneId.systemDefault())
                val endOfDay = today.atTime(23, 59, 59).atZone(ZoneId.systemDefault())

                // Try active calories first, fallback to total if not available
                val activeRequest = AggregateRequest(
                    metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(
                        startOfDay.toInstant(),
                        endOfDay.toInstant()
                    )
                )
                val activeResponse = client.aggregate(activeRequest)
                val activeCaloriesRaw = (activeResponse[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL] as? androidx.health.connect.client.units.Energy)
                val activeCalories = activeCaloriesRaw?.inKilocalories ?: 0.0
                
                // Fallback to total calories if active is 0
                val calories = if (activeCalories > 0.0) {
                    activeCalories
                } else {
                    val totalRequest = AggregateRequest(
                        metrics = setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(
                            startOfDay.toInstant(),
                            endOfDay.toInstant()
                        )
                    )
                    val totalResponse = client.aggregate(totalRequest)
                    val totalCaloriesRaw = (totalResponse[TotalCaloriesBurnedRecord.ENERGY_TOTAL] as? androidx.health.connect.client.units.Energy)
                    totalCaloriesRaw?.inKilocalories ?: 0.0
                }

                withContext(Dispatchers.Main) {
                    result.success(calories)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("CALORIES_ERROR", e.message, null)
                }
            }
        }
    }

    private fun getTodayWorkouts(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val ctx = context ?: return@launch withContext(Dispatchers.Main) { result.error("NO_CONTEXT", "Context not set", null) }
                val client = healthConnectClient ?: HealthConnectClient.getOrCreate(ctx)
                healthConnectClient = client

                val today = LocalDate.now()
                val startOfDay = today.atStartOfDay(ZoneId.systemDefault())
                val endOfDay = today.atTime(23, 59, 59).atZone(ZoneId.systemDefault())

                val request = ReadRecordsRequest(
                    ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        startOfDay.toInstant(),
                        endOfDay.toInstant()
                    )
                )

                val response = client.readRecords(request)
                val sessions = response.records.size
                var totalDuration = 0.0

                response.records.forEach { record ->
                    val startSeconds = record.startTime.epochSecond
                    val endSeconds = record.endTime.epochSecond
                    val duration = (endSeconds - startSeconds) / 60.0
                    totalDuration += duration
                }

                val workoutData = mapOf(
                    "sessions" to sessions,
                    "duration" to totalDuration
                )

                withContext(Dispatchers.Main) {
                    result.success(workoutData)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("WORKOUTS_ERROR", e.message, null)
                }
            }
        }
    }

    private fun getTodayData(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val ctx = context ?: return@launch withContext(Dispatchers.Main) { result.error("NO_CONTEXT", "Context not set", null) }
                val client = healthConnectClient ?: HealthConnectClient.getOrCreate(ctx)
                healthConnectClient = client

                val today = LocalDate.now()
                val startOfDay = today.atStartOfDay(ZoneId.systemDefault())
                val endOfDay = today.atTime(23, 59, 59).atZone(ZoneId.systemDefault())

                // Get steps
                val stepsRequest = AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(
                        startOfDay.toInstant(),
                        endOfDay.toInstant()
                    )
                )
                val stepsResponse = client.aggregate(stepsRequest)
                val steps = (stepsResponse[StepsRecord.COUNT_TOTAL] as? Long)?.toInt() ?: 0

                // Get calories - Try active first, fallback to total if active is empty
                // Google Fit often writes to TotalCaloriesBurnedRecord but displays active calories in UI
                
                // Try active calories first
                val activeRequest = AggregateRequest(
                    metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(
                        startOfDay.toInstant(),
                        endOfDay.toInstant()
                    )
                )
                val activeResponse = client.aggregate(activeRequest)
                val activeCaloriesRaw = (activeResponse[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL] as? androidx.health.connect.client.units.Energy)
                val activeCalories = activeCaloriesRaw?.inKilocalories ?: 0.0
                
                android.util.Log.d("HealthConnect", "📊 Native: Active calories: $activeCalories kcal")
                
                // If active calories is 0, try total calories as fallback
                val calories = if (activeCalories > 0.0) {
                    android.util.Log.d("HealthConnect", "✅ Native: Using active calories (exercise only)")
                    activeCalories
                } else {
                    // Fallback to total calories
                    val totalRequest = AggregateRequest(
                        metrics = setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(
                            startOfDay.toInstant(),
                            endOfDay.toInstant()
                        )
                    )
                    val totalResponse = client.aggregate(totalRequest)
                    val totalCaloriesRaw = (totalResponse[TotalCaloriesBurnedRecord.ENERGY_TOTAL] as? androidx.health.connect.client.units.Energy)
                    val totalCalories = totalCaloriesRaw?.inKilocalories ?: 0.0
                    
                    android.util.Log.d("HealthConnect", "📊 Native: Total calories: $totalCalories kcal")
                    android.util.Log.d("HealthConnect", "💡 Native: Active calories not available, using total calories")
                    
                    totalCalories
                }
                
                android.util.Log.d("HealthConnect", "✅ Native: Final calories value: $calories kcal")

                // Get workouts
                val workoutRequest = ReadRecordsRequest(
                    ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        startOfDay.toInstant(),
                        endOfDay.toInstant()
                    )
                )
                val workoutResponse = client.readRecords(workoutRequest)
                val sessions = workoutResponse.records.size
                var totalDuration = 0.0

                workoutResponse.records.forEach { record ->
                    val startSeconds = record.startTime.epochSecond
                    val endSeconds = record.endTime.epochSecond
                    val duration = (endSeconds - startSeconds) / 60.0
                    totalDuration += duration
                }

                val data = mapOf(
                    "steps" to steps,
                    "caloriesBurned" to calories,
                    "workoutSessions" to sessions,
                    "workoutDuration" to totalDuration
                )

                android.util.Log.d("HealthConnect", "✅ Native: Returning data - Steps: $steps, Calories: $calories, Workouts: $sessions, Duration: $totalDuration mins")

                withContext(Dispatchers.Main) {
                    result.success(data)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("DATA_ERROR", e.message, null)
                }
            }
        }
    }

    private fun openHealthConnectSettings(result: MethodChannel.Result) {
        try {
            val ctx = context ?: return result.error("NO_CONTEXT", "Context not set", null)
            
            val healthConnectPackage = "com.google.android.apps.healthdata"
            val packageManager = ctx.packageManager
            
            // Try multiple methods to open Health Connect app directly
            // Method 1: Launch Health Connect app directly via package name (BEST - opens the app itself)
            try {
                val launchIntent = packageManager.getLaunchIntentForPackage(healthConnectPackage)
                if (launchIntent != null) {
                    launchIntent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    ctx.startActivity(launchIntent)
                    android.util.Log.d("HealthConnect", "✅ Method 1: Launched Health Connect app directly")
                    result.success(true)
                    return
                }
            } catch (e: Exception) {
                android.util.Log.w("HealthConnect", "Method 1 failed: ${e.message}")
            }
            
            // Method 2: Direct Health Connect permissions screen (opens app to permissions page)
            try {
                val intent = android.content.Intent("androidx.health.ACTION_MANAGE_HEALTH_PERMISSIONS")
                intent.putExtra("android.provider.extra.HEALTH_PERMISSIONS_PACKAGE_NAME", ctx.packageName)
                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                ctx.startActivity(intent)
                android.util.Log.d("HealthConnect", "✅ Method 2: Opened Health Connect permissions screen")
                result.success(true)
                return
            } catch (e: Exception) {
                android.util.Log.w("HealthConnect", "Method 2 failed: ${e.message}")
            }
            
            // Method 3: Open Health Connect via explicit intent action
            try {
                val intent = android.content.Intent()
                intent.setClassName(healthConnectPackage, "$healthConnectPackage.HomeActivity")
                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                ctx.startActivity(intent)
                android.util.Log.d("HealthConnect", "✅ Method 3: Opened Health Connect via HomeActivity")
                result.success(true)
                return
            } catch (e: Exception) {
                android.util.Log.w("HealthConnect", "Method 3 failed: ${e.message}")
            }
            
            // Method 4: Open Play Store to install/update Health Connect
            try {
                android.util.Log.w("HealthConnect", "Health Connect not accessible, opening Play Store")
                val playStoreIntent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                playStoreIntent.data = android.net.Uri.parse("market://details?id=$healthConnectPackage")
                playStoreIntent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                
                ctx.startActivity(playStoreIntent)
                android.util.Log.d("HealthConnect", "✅ Method 4: Opened Play Store")
                result.success(true)
                return
            } catch (e: Exception) {
                android.util.Log.w("HealthConnect", "Method 4 failed: ${e.message}")
            }
            
            // Method 5: Fallback to browser Play Store link
            try {
                val browserIntent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                browserIntent.data = android.net.Uri.parse("https://play.google.com/store/apps/details?id=$healthConnectPackage")
                browserIntent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                ctx.startActivity(browserIntent)
                android.util.Log.d("HealthConnect", "✅ Method 5: Opened browser Play Store")
                result.success(true)
                return
            } catch (e: Exception) {
                android.util.Log.e("HealthConnect", "Method 5 failed: ${e.message}")
            }
            
            // If all methods fail
            result.error("SETTINGS_ERROR", "Could not open Health Connect settings", null)
            
        } catch (e: Exception) {
            android.util.Log.e("HealthConnect", "❌ All methods failed: ${e.message}")
            result.error("SETTINGS_ERROR", e.message, null)
        }
    }
}

