package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseStepsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_steps).apply {
                val steps = widgetData.getString("steps", "0")
                val distance = widgetData.getString("distance_km", "0.0")
                setTextViewText(R.id.widget_steps_count, steps)
                setTextViewText(R.id.widget_steps_distance, "$distance km")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
