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

                // For SDK 1.1.0-alpha07, permissions are handled differently
                // Check if we can access data (which requires permissions)
                try {
                    // Try to get granted permissions - if this works, permissions are likely granted
                    val granted = client.permissionController.getGrantedPermissions()
                    // If we can get granted permissions, assume we have access
                    result.success(granted.isNotEmpty())
                } catch (e: Exception) {
                    // If we can't check permissions, return false
                    // User will need to grant permissions manually through Health Connect app
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

                val request = AggregateRequest(
                    metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(
                        startOfDay.toInstant(),
                        endOfDay.toInstant()
                    )
                )

                val response = client.aggregate(request)
                val calories = (response[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL] as? Double) ?: 0.0

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

                // Get calories
                val caloriesRequest = AggregateRequest(
                    metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(
                        startOfDay.toInstant(),
                        endOfDay.toInstant()
                    )
                )
                val caloriesResponse = client.aggregate(caloriesRequest)
                val calories = (caloriesResponse[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL] as? Double) ?: 0.0

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

