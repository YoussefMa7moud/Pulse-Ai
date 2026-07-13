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
                val score = widgetData.getString("sleep_score", "--")
                val duration = widgetData.getString("sleep_hours", "--")
                setTextViewText(R.id.widget_sleep_score, score)
                setTextViewText(R.id.widget_sleep_duration, "$duration hrs")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
