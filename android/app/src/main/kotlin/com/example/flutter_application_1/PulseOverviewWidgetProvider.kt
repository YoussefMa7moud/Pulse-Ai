package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseOverviewWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_overview).apply {
                val recovery = widgetData.getString("recovery_score", "--")
                val sleep = widgetData.getString("sleep_score", "--")
                val strain = widgetData.getString("strain_score", "--")
                val steps = widgetData.getString("steps", "--")
                
                setTextViewText(R.id.overview_recovery, recovery)
                setTextViewText(R.id.overview_sleep, sleep)
                setTextViewText(R.id.overview_strain, strain)
                setTextViewText(R.id.overview_steps, steps)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
