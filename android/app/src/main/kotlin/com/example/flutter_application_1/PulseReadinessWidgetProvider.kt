package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseReadinessWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_readiness).apply {
                val score = widgetData.getString("readiness_score", "--")
                val energy = widgetData.getString("energy_score", "--")
                setTextViewText(R.id.widget_readiness_score, score)
                setTextViewText(R.id.widget_readiness_energy, "Energy: $energy%")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
