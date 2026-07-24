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
                val sleepHoursStr = widgetData.getString("sleep_hours", "--") ?: "--"

                val recoveryVal = recoveryStr.toIntOrNull() ?: 0
                val sleepVal = sleepStr.toIntOrNull() ?: 0
                val strainFloat = strainStr.toFloatOrNull() ?: 0.0f
                val strainVal = (strainFloat * 10f).roundToInt()
                val stressVal = stressStr.toIntOrNull() ?: 0

                // 1. RECOVERY PILLAR
                setTextViewText(R.id.overview_recovery, if (recoveryStr == "--") "--" else "$recoveryStr%")
                setProgressBar(R.id.recovery_progress, 100, recoveryVal.coerceIn(0, 100), false)
                val recSub = when {
                    recoveryStr == "--" -> "Score"
                    recoveryVal >= 66 -> "Optimal"
                    recoveryVal >= 34 -> "Moderate"
                    else -> "Resting"
                }
                setTextViewText(R.id.overview_rec_sub, recSub)

                // 2. STRAIN PILLAR
                setTextViewText(R.id.overview_strain, if (strainStr == "--") "--" else strainStr)
                setProgressBar(R.id.strain_progress, 210, strainVal.coerceIn(0, 210), false)

                // 3. SLEEP PILLAR
                setTextViewText(R.id.overview_sleep, if (sleepStr == "--") "--" else "$sleepStr%")
                setProgressBar(R.id.sleep_progress, 100, sleepVal.coerceIn(0, 100), false)
                setTextViewText(R.id.overview_sleep_sub, if (sleepHoursStr == "--") "Quality" else "${sleepHoursStr}h")

                // 4. STRESS PILLAR
                setTextViewText(R.id.overview_stress, if (stressStr == "--") "--" else "$stressStr%")
                setProgressBar(R.id.stress_progress, 100, stressVal.coerceIn(0, 100), false)
                val stressSub = when {
                    stressStr == "--" -> "Balance"
                    stressVal <= 25 -> "Relaxed"
                    stressVal <= 50 -> "Balanced"
                    stressVal <= 75 -> "Elevated"
                    else -> "High"
                }
                setTextViewText(R.id.overview_stress_sub, stressSub)

                // Set click listener to launch app and update
                WidgetThemeHelper.setOnClickLaunchApp(context, this, widgetId)

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
                        R.id.label_stress,
                        R.id.overview_rec_sub,
                        R.id.overview_strain_sub,
                        R.id.overview_sleep_sub,
                        R.id.overview_stress_sub,
                        R.id.widget_title,
                        R.id.widget_subtitle
                    )
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
