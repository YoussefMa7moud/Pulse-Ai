package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Get data from flutter shared preferences via home_widget
                val recovery = widgetData.getString("recovery_score", "--")
                val strain = widgetData.getString("strain_score", "--")
                val sleep = widgetData.getString("sleep_score", "--")

                setTextViewText(R.id.recovery_score, recovery)
                setTextViewText(R.id.strain_score, strain)
                setTextViewText(R.id.sleep_score, sleep)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
