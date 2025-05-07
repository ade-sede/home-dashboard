package io.github.cdesede.transitclock

import android.Manifest
import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient

import kotlinx.coroutines.*
import org.json.JSONArray
import java.time.format.DateTimeFormatter
import android.util.Log
import androidx.annotation.RequiresPermission
import java.time.ZonedDateTime
import java.time.ZoneId


import io.github.cdesede.transitclock.DataManager.loadEstimatesCache

import io.github.cdesede.transitclock.DataManager.isAfterNearestTrip
import io.github.cdesede.transitclock.DataManager.fetchLegs
import io.github.cdesede.transitclock.DataManager.formatTime
import org.json.JSONObject
import kotlin.collections.joinToString


class TransitClockWidget : AppWidgetProvider() {
    @RequiresPermission(Manifest.permission.SCHEDULE_EXACT_ALARM)
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            deleteConfigPref(context, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)

        val intent = Intent(context, TransitClockWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis(),
            15 * 60 * 1000, // 15 minutes
            pendingIntent
        )
    }

    @RequiresPermission(Manifest.permission.SCHEDULE_EXACT_ALARM)
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.v("debug", intent.toString())

        if (intent.action == "io.github.cdesede.transitclock.ACTION_RELOAD") {
            Log.v("transitclockWidget", "Reload button pressed")
            val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    companion object {
        @RequiresPermission(Manifest.permission.SCHEDULE_EXACT_ALARM)
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.transit_clock_widget)
            val cachedData = loadEstimatesCache(context, appWidgetId)

            val reloadIntent = Intent(context, TransitClockWidget::class.java).apply {
                action = "io.github.cdesede.transitclock.ACTION_RELOAD"
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val reloadPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId, // important: unique requestCode per widget
                reloadIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.reload_button, reloadPendingIntent)

            // Setup config button
            val configIntent = Intent(context, TransitClockWidgetConfigureActivity::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val configPendingIntent = PendingIntent.getActivity(
                context, appWidgetId, configIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.config_button, configPendingIntent)
            CoroutineScope(Dispatchers.IO).launch {
                val needsRefresh = isAfterNearestTrip(cachedData)

                // Only fetch new data if necessary
                if (needsRefresh) {
                    val config = loadConfigPref(context, appWidgetId)

                    if (config != null) {
                        fetchLegs(config, OkHttpClient(), context, appWidgetId)
                    } else {
                        scheduleNextUpdate(context, System.currentTimeMillis() + 15_000L, appWidgetId)
                    }
                }

                withContext(Dispatchers.Main) {
                    // Clear old trips
                    views.removeAllViews(R.id.trips_container)

                    // Load updated cached data
                    val updatedData = loadEstimatesCache(context, appWidgetId)
                    var nextDepartureTime: Long? = null

                    try {
                        val estimates = JSONArray(updatedData)
                        val legEstimatesMap = mutableMapOf<Int, MutableList<JSONObject>>()

                        for (i in 0 until estimates.length()) {
                            val estimate = estimates.getJSONObject(i)
                            val legId = estimate.getJSONObject("leg").getInt("id")
                            legEstimatesMap.getOrPut(legId) { mutableListOf() }.add(estimate)
                        }

                        for ((_, estimatesList) in legEstimatesMap) {
                            val firstEstimate = estimatesList[0]
                            val leg = firstEstimate.getJSONObject("leg")

                            var earliestDeparture: Long? = null
                            val departuresText = estimatesList.joinToString(" • ") {
                                val timeStr = it.getString("departure_time")
                                val millis = ZonedDateTime.parse(timeStr, DateTimeFormatter.ISO_OFFSET_DATE_TIME)
                                    .withZoneSameInstant(ZoneId.systemDefault())
                                    .toInstant()
                                    .toEpochMilli()
                                if (earliestDeparture == null || millis < earliestDeparture!!) earliestDeparture = millis
                                formatTime(timeStr)
                            }

                            if (nextDepartureTime == null || (earliestDeparture != null && earliestDeparture < nextDepartureTime)) {
                                nextDepartureTime = earliestDeparture
                            }

                            val itemView = RemoteViews(context.packageName, R.layout.trip_item)
                            itemView.setTextViewText(R.id.line_short, leg.getString("line_short_name"))
                            itemView.setTextViewText(R.id.trip_text, leg.getString("trip_direction"))
                            itemView.setTextViewText(R.id.trip_time, departuresText)

                            views.addView(R.id.trips_container, itemView)
                        }

                    } catch (e: Exception) {
                        // Handle errors
                    }

                    if (nextDepartureTime != null) {
                        scheduleNextUpdate(context, nextDepartureTime, appWidgetId)
                    }


                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            }
        }

        @RequiresPermission(Manifest.permission.SCHEDULE_EXACT_ALARM)
        fun scheduleNextUpdate(context: Context, triggerAtMillis: Long, appWidgetId: Int) {
            cancelScheduledUpdate(context, appWidgetId)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TransitClockWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }

        fun cancelScheduledUpdate(context: Context, appWidgetId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TransitClockWidget::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }

        fun cancelAllScheduledUpdates(context: Context) {
            val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
            val ids = prefs.getStringSet("widget_ids", emptySet()) ?: emptySet()
            for (id in ids) {
                cancelScheduledUpdate(context, id.toInt())
            }
        }

        fun getNextTripTimeMillis(context: Context, appWidgetId: Int): Long {
            // Implement your logic to fetch the next trip time in millis
            return System.currentTimeMillis() + 10 * 60 * 1000 // fallback: 10 min later
        }
    }

}

