package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseStrainWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_strain).apply {
                val score = widgetData.getString("strain_score", "--")
                val calories = widgetData.getString("calories", "--")
                setTextViewText(R.id.widget_strain_score, score)
                setTextViewText(R.id.widget_strain_calories, "$calories kcal")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
