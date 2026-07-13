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
                val score = widgetData.getString("readiness_score", "--") ?: "--"
                val energy = widgetData.getString("energy_score", "--") ?: "--"
                val scoreVal = score.toIntOrNull() ?: 0
                setTextViewText(R.id.widget_readiness_score, if (score == "--") "--" else "$score")
                setProgressBar(R.id.readiness_progress, 100, scoreVal, false)
                setTextViewText(R.id.widget_readiness_energy, "Energy: $energy%")

                WidgetThemeHelper.applyTheme(
                    context, this, widgetData,
                    R.drawable.widget_bg_accent,
                    R.drawable.widget_bg_accent_light,
                    intArrayOf(R.id.widget_readiness_score),
                    intArrayOf(R.id.widget_readiness_energy)
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
