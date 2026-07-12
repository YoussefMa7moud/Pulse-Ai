package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseLargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout_large).apply {
                val recovery = widgetData.getString("recovery_score", "--")
                val strain = widgetData.getString("strain_score", "--")
                val sleep = widgetData.getString("sleep_score", "--")
                val aiInsight = widgetData.getString("ai_insight", "Loading AI Strategy...")

                setTextViewText(R.id.recovery_score_large, recovery)
                setTextViewText(R.id.strain_score_large, strain)
                setTextViewText(R.id.sleep_score_large, sleep)
                setTextViewText(R.id.ai_insight_text, aiInsight)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
