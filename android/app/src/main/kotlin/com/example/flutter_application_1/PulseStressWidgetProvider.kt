package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseStressWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_stress).apply {
                val score = widgetData.getString("stress_score", "--") ?: "--"
                val recoveryStr = widgetData.getString("recovery_score", "--") ?: "--"
                val recovery = recoveryStr.toIntOrNull() ?: 50
                val level = if (recovery >= 67) "Optimal" else if (recovery >= 34) "Balanced" else "Stressed"
                setTextViewText(R.id.widget_stress_score, score)
                setTextViewText(R.id.widget_stress_level, level)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
