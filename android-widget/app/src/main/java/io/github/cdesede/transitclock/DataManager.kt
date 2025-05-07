package io.github.cdesede.transitclock

import android.util.Base64
import android.util.Log
import androidx.core.content.edit
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

import android.content.Context
import android.content.SharedPreferences

object DataManager {
    private const val PREF_NAME = "transit_prefs"
    private const val KEY_DATA = "stored_data"


    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
    }

    fun formatTime(time: String): String {
        val formatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME
        val datetime = OffsetDateTime.parse(time, formatter)
        return datetime.format(DateTimeFormatter.ofPattern("HH:mm"))
    }

    fun formatTripTime(departure: String, arrival: String): String {
        return "${formatTime(departure)} -> ${formatTime(arrival)}"
    }

    fun saveEstimatesCache(context: Context, appWidgetId: Int, estimates: String) {
        context.getSharedPreferences("widget_cache", Context.MODE_PRIVATE)
            .edit() {
                putString("estimates_$appWidgetId", estimates)
            }
    }

    fun loadEstimatesCache(context: Context, appWidgetId: Int): String {
        return context.getSharedPreferences("widget_cache", Context.MODE_PRIVATE)
            .getString("estimates_$appWidgetId", "No data") ?: "No data"
    }

    fun isAfterNearestTrip(cachedData: String): Boolean {
        return try {
            val estimates = JSONArray(cachedData)
            if (estimates.length() == 0) return true // No trips, need refresh

            val firstEstimate = estimates.getJSONObject(0)
            val departureTimeStr = firstEstimate.getString("departure_time")
            val formatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME
            val departureTime = OffsetDateTime.parse(departureTimeStr, formatter)
            val now = OffsetDateTime.now()

            now.isAfter(departureTime)
        } catch (e: Exception) {
            true // In case of bad data, always refresh
        }
    }

    fun fetchLegs(config: WidgetConfig, client: OkHttpClient, context: Context, appWidgetId: Int) {
        Log.v("debug", "Fetch legs")
        val auth = Base64.encodeToString("${config.username}:${config.password}".toByteArray(), Base64.NO_WRAP)

        val refreshRequest = Request.Builder()
            .url("${config.url}/api/trips/force_refresh")
            .addHeader("Authorization", "Basic $auth")
            .build()
        client.newCall(refreshRequest).execute().close()
        Log.v("debug", "Forced refresh")

        val legsRequest = Request.Builder()
            .url("${config.url}/api/trips/")
            .addHeader("Authorization", "Basic $auth")
            .build()

        client.newCall(legsRequest).execute().use { response ->
            if (!response.isSuccessful) return
            val body = response.body?.string() ?: ""
            Log.v("debug", body)
            val obj = JSONObject(body)
            val legs = obj.getJSONArray("legs")

            val allEstimates = JSONArray()
            Log.v("debug", "${legs.length()} legs")

            for (i in 0 until legs.length()) {
                val item = legs.getJSONObject(i)
                val estimateArray = fetchEstimates(config, client, item.getInt("id"))
                if (estimateArray != null) {
                    for (j in 0 until estimateArray.length()) {
                        val estimate = estimateArray.getJSONObject(j)
                        estimate.put("leg", item)
                        allEstimates.put(estimate)
                    }
                }
            }

            saveEstimatesCache(context, appWidgetId, allEstimates.toString())
        }
    }

    fun fetchEstimates(config: WidgetConfig, client: OkHttpClient, id: Int): JSONArray? {
        val auth =
            Base64.encodeToString("${config.username}:${config.password}".toByteArray(), Base64.NO_WRAP)

        val estimateRequest = Request.Builder()
            .url("${config.url}/api/trips/${id}/next")
            .addHeader("Authorization", "Basic $auth")
            .build()
        client.newCall(estimateRequest).execute().use { response ->
            if (!response.isSuccessful) return null
            val body = response.body?.string() ?: return null
            return JSONObject(body).optJSONArray("estimates")
        }
    }
}
