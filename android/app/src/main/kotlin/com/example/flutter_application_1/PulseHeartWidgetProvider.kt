package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseHeartWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_heart).apply {
                val rhr = widgetData.getString("rhr", "--")
                val hrv = widgetData.getString("hrv", "--")
                setTextViewText(R.id.widget_heart_rhr, "$rhr bpm")
                setTextViewText(R.id.widget_heart_hrv, "HRV: $hrv ms")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
