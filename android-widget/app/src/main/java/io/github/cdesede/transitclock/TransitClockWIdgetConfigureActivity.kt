package io.github.cdesede.transitclock

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.EditText
import androidx.core.content.edit
import io.github.cdesede.transitclock.databinding.TransitClockWidgetConfigureBinding

/**
 * The configuration screen for the [TransitClockWidget] AppWidget.
 */
class TransitClockWidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var binding: TransitClockWidgetConfigureBinding

    private var onClickListener = View.OnClickListener {
        val context = this@TransitClockWidgetConfigureActivity

        val url = binding.urlInput.text.toString()
        val username = binding.usernameInput.text.toString()
        val password = binding.passwordInput.text.toString()

        saveConfigPref(context, appWidgetId, url, username, password)

        val appWidgetManager = AppWidgetManager.getInstance(context)

        val resultValue = Intent().apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        setResult(RESULT_OK, resultValue)
        finish()
    }

    public override fun onCreate(icicle: Bundle?) {
        super.onCreate(icicle)
        setResult(RESULT_CANCELED)

        binding = TransitClockWidgetConfigureBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.addButton.setOnClickListener(onClickListener)

        // Find the widget id from the intent.
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        }

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        loadConfigPref(this, appWidgetId)?.let { config ->
            binding.urlInput.setText(config.url)
            binding.usernameInput.setText(config.username)
            binding.passwordInput.setText(config.password)
        }
    }
}

private const val PREFS_NAME = "io.github.cdesede.transitclock.transitclockWidget"
private const val PREF_PREFIX_KEY = "appwidget_"

data class WidgetConfig(val url: String, val username: String, val password: String)

private fun saveConfigPref(context: Context, appWidgetId: Int, url: String, username: String, password: String) {
    context.getSharedPreferences(PREFS_NAME, 0).edit() {
        putString("${PREF_PREFIX_KEY}${appWidgetId}_url", url)
        putString("${PREF_PREFIX_KEY}${appWidgetId}_username", username)
        putString("${PREF_PREFIX_KEY}${appWidgetId}_password", password)
    }
}

fun loadConfigPref(context: Context, appWidgetId: Int): WidgetConfig? {
    val prefs = context.getSharedPreferences(PREFS_NAME, 0)
    val url = prefs.getString("${PREF_PREFIX_KEY}${appWidgetId}_url", null) ?: return null
    val username = prefs.getString("${PREF_PREFIX_KEY}${appWidgetId}_username", "") ?: ""
    val password = prefs.getString("${PREF_PREFIX_KEY}${appWidgetId}_password", "") ?: ""
    return WidgetConfig(url, username, password)
}

fun deleteConfigPref(context: Context, appWidgetId: Int) {
    context.getSharedPreferences(PREFS_NAME, 0).edit() {
        remove("${PREF_PREFIX_KEY}${appWidgetId}_url")
        remove("${PREF_PREFIX_KEY}${appWidgetId}_username")
        remove("${PREF_PREFIX_KEY}${appWidgetId}_password")
    }
}
