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
                val rhr = widgetData.getString("rhr", "--") ?: "--"
                val hrv = widgetData.getString("hrv", "--") ?: "--"
                val rhrVal = rhr.toIntOrNull() ?: 0

                setTextViewText(R.id.widget_heart_rhr, rhr)
                setProgressBar(R.id.heart_progress, 120, rhrVal, false)
                setTextViewText(R.id.widget_heart_hrv, "HRV: $hrv ms")

                WidgetThemeHelper.setOnClickLaunchApp(context, this, widgetId)

                WidgetThemeHelper.applyTheme(
                    context, this, widgetData,
                    R.drawable.widget_bg_heart,
                    R.drawable.widget_bg_vitals_light,
                    intArrayOf(R.id.widget_heart_rhr),
                    intArrayOf(R.id.widget_heart_hrv)
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
