package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseSleepWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_sleep).apply {
                val score = widgetData.getString("sleep_score", "--") ?: "--"
                val duration = widgetData.getString("sleep_hours", "--") ?: "--"
                val scoreVal = score.toIntOrNull() ?: 0
                setTextViewText(R.id.widget_sleep_score, if (score == "--") "--" else "$score")
                setProgressBar(R.id.sleep_progress, 100, scoreVal, false)
                setTextViewText(R.id.widget_sleep_duration, "$duration hrs")

                WidgetThemeHelper.applyTheme(
                    context, this, widgetData,
                    R.drawable.widget_bg_sleep,
                    R.drawable.widget_bg_sleep_light,
                    intArrayOf(R.id.widget_sleep_score),
                    intArrayOf(R.id.widget_sleep_duration)
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
