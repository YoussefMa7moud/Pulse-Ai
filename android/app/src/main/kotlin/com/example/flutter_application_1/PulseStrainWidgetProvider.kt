package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.roundToInt

class PulseStrainWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_strain).apply {
                val score = widgetData.getString("strain_score", "--") ?: "--"
                val calories = widgetData.getString("calories", "--") ?: "--"
                val scoreFloat = score.toFloatOrNull() ?: 0.0f
                val progressVal = (scoreFloat * 10f).roundToInt()

                setTextViewText(R.id.widget_strain_score, score)
                setProgressBar(R.id.strain_progress, 210, progressVal, false)
                setTextViewText(R.id.widget_strain_calories, "$calories kcal")

                WidgetThemeHelper.setOnClickLaunchApp(context, this, widgetId)

                WidgetThemeHelper.applyTheme(
                    context, this, widgetData,
                    R.drawable.widget_bg_strain,
                    R.drawable.widget_bg_strain_light,
                    intArrayOf(R.id.widget_strain_score),
                    intArrayOf(R.id.widget_strain_calories)
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
