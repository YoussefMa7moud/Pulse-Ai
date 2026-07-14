package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.roundToInt

class PulseOverviewWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_overview).apply {
                val recoveryStr = widgetData.getString("recovery_score", "--") ?: "--"
                val sleepStr = widgetData.getString("sleep_score", "--") ?: "--"
                val strainStr = widgetData.getString("strain_score", "--") ?: "--"
                val stressStr = widgetData.getString("stress_score", "--") ?: "--"

                val recoveryVal = recoveryStr.toIntOrNull() ?: 0
                val sleepVal = sleepStr.toIntOrNull() ?: 0
                val strainFloat = strainStr.toFloatOrNull() ?: 0.0f
                val strainVal = (strainFloat * 10f).roundToInt()
                val stressVal = stressStr.toIntOrNull() ?: 0

                // Recovery ring
                setTextViewText(R.id.overview_recovery, if (recoveryStr == "--") "--" else "$recoveryStr%")
                setProgressBar(R.id.recovery_progress, 100, recoveryVal, false)

                // Strain bar
                setTextViewText(R.id.overview_strain, strainStr)
                setProgressBar(R.id.strain_progress, 210, strainVal, false)

                // Sleep bar
                setTextViewText(R.id.overview_sleep, if (sleepStr == "--") "--" else "$sleepStr%")
                setProgressBar(R.id.sleep_progress, 100, sleepVal, false)

                // Stress bar
                setTextViewText(R.id.overview_stress, if (stressStr == "--") "--" else "$stressStr%")
                setProgressBar(R.id.stress_progress, 100, stressVal, false)

                WidgetThemeHelper.applyTheme(
                    context, this, widgetData,
                    R.drawable.widget_bg_vitals,
                    R.drawable.widget_bg_vitals_light,
                    intArrayOf(
                        R.id.overview_recovery,
                        R.id.overview_strain,
                        R.id.overview_sleep,
                        R.id.overview_stress
                    ),
                    intArrayOf(
                        R.id.label_rec,
                        R.id.label_strain,
                        R.id.label_sleep,
                        R.id.label_stress
                    )
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
