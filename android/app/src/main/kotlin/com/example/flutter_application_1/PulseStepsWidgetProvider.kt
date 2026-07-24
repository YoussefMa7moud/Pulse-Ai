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
                val steps = widgetData.getString("steps", "0") ?: "0"
                val distance = widgetData.getString("distance_km", "0.0") ?: "0.0"
                val stepsVal = steps.replace(",", "").toIntOrNull() ?: 0

                setTextViewText(R.id.widget_steps_count, steps)
                setProgressBar(R.id.steps_progress, 10000, stepsVal, false)
                setTextViewText(R.id.widget_steps_distance, "$distance km")

                WidgetThemeHelper.setOnClickLaunchApp(context, this, widgetId)

                WidgetThemeHelper.applyTheme(
                    context, this, widgetData,
                    R.drawable.widget_bg_activity,
                    R.drawable.widget_bg_activity_light,
                    intArrayOf(R.id.widget_steps_count),
                    intArrayOf(R.id.widget_steps_distance)
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
