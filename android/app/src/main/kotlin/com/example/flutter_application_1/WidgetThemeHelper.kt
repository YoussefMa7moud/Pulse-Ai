package com.example.flutter_application_1

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews

object WidgetThemeHelper {

    fun setOnClickLaunchApp(context: Context, views: RemoteViews, widgetId: Int) {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val pendingIntent = PendingIntent.getActivity(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        } catch (_: Exception) {}
    }

    fun applyTheme(
        context: Context,
        views: RemoteViews,
        widgetData: SharedPreferences,
        darkBgRes: Int,
        lightBgRes: Int,
        primaryTextIds: IntArray,
        secondaryTextIds: IntArray
    ) {
        val themeMode = widgetData.getString("theme_mode", "dark") ?: "dark"
        val isDark = themeMode == "dark"

        // Set Background
        val bgRes = if (isDark) darkBgRes else lightBgRes
        try {
            views.setInt(R.id.widget_root, "setBackgroundResource", bgRes)
        } catch (_: Exception) {
            // Fallback if widget_root doesn't exist
        }

        // Text Colors
        val defaultPrimaryColor = if (isDark) Color.WHITE else Color.parseColor("#0F172A")
        val defaultSecondaryColor = if (isDark) Color.parseColor("#9CA3AF") else Color.parseColor("#64748B")

        val hexPrimary = widgetData.getString("color_primary", null)
        val hexSecondary = widgetData.getString("color_secondary", null)

        val primaryColor = parseColor(hexPrimary, defaultPrimaryColor)
        val secondaryColor = parseColor(hexSecondary, defaultSecondaryColor)

        primaryTextIds.forEach { id ->
            try { views.setTextColor(id, primaryColor) } catch (_: Exception) {}
        }
        secondaryTextIds.forEach { id ->
            try { views.setTextColor(id, secondaryColor) } catch (_: Exception) {}
        }
    }

    private fun parseColor(hex: String?, defaultColor: Int): Int {
        if (hex == null) return defaultColor
        val cleanedHex = if (hex.startsWith("#")) hex else "#$hex"
        return try {
            Color.parseColor(cleanedHex)
        } catch (_: Exception) {
            defaultColor
        }
    }
}
