package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseRecoveryWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_recovery).apply {
                val score = widgetData.getString("recovery_score", "--") ?: "--"
                val scoreVal = score.toIntOrNull() ?: 0
                setTextViewText(R.id.widget_recovery_score, if (score == "--") "--" else "$score%")
                setProgressBar(R.id.recovery_progress, 100, scoreVal, false)

                WidgetThemeHelper.applyTheme(
                    context, this, widgetData,
                    R.drawable.widget_bg_recovery,
                    R.drawable.widget_bg_recovery_light,
                    intArrayOf(R.id.widget_recovery_score),
                    intArrayOf()
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
