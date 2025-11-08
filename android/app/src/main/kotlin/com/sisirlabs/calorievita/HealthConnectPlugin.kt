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
            else -> result.notImplemented()
        }
    }

    private fun checkAvailability(result: MethodChannel.Result) {
        try {
            val ctx = context ?: return result.error("NO_CONTEXT", "Context not set", null)
            val client = HealthConnectClient.getOrCreate(ctx)
            healthConnectClient = client
            result.success(true)
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
}

