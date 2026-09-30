package com.cvilia.plain

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "app/security"
    private val widgetChannelName = "app/widget"
    private var securityChannel: MethodChannel? = null
    private var isSecure = true // Default: enable privacy overlay

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Security channel: FLAG_SECURE for privacy overlay
        securityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        securityChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureFlag" -> {
                    val enabled = call.arguments as? Boolean ?: true
                    setSecureFlag(enabled)
                    result.success(null)
                }
                "setPrivacyOverlay" -> {
                    val enabled = call.arguments as? Boolean ?: true
                    setSecureFlag(enabled)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Widget channel: update snapshot
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateSnapshot" -> {
                        val data = call.arguments as? Map<*, *>
                        if (data != null) {
                            val prefs = getSharedPreferences("widget_snapshot", MODE_PRIVATE)
                            prefs.edit()
                                .putInt("monthExpenseCents", (data["monthExpenseCents"] as? Int) ?: 0)
                                .putInt("monthIncomeCents", (data["monthIncomeCents"] as? Int) ?: 0)
                                .putInt("entryCount", (data["entryCount"] as? Int) ?: 0)
                                .apply()

                            // Trigger widget update
                            val intent = Intent(this, MonthlySummaryWidgetProvider::class.java).apply {
                                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            }
                            sendBroadcast(intent)
                        }
                        result.success(null)
                    }
                    "reloadTimelines" -> {
                        val intent = Intent(this, MonthlySummaryWidgetProvider::class.java).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        }
                        sendBroadcast(intent)
                        result.success(null)
                    }
                    "initialIntent" -> {
                        result.success(handleInitialIntent())
                    }
                    else -> result.notImplemented()
                }
            }

        // Enable privacy overlay by default
        setSecureFlag(true)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: Intent?) {
        if (intent?.action == "com.cvilia.plain.OPEN_ENTRY") {
            val route = intent.getStringExtra("route") ?: "/entry"
            // Flutter will handle the route via initialIntent
        }
    }

    private fun handleInitialIntent(): String {
        val action = intent?.action
        return if (action == "com.cvilia.plain.OPEN_ENTRY") {
            intent?.getStringExtra("route") ?: "/entry"
        } else {
            "/"
        }
    }

    private fun setSecureFlag(enabled: Boolean) {
        isSecure = enabled
        runOnUiThread {
            if (enabled) {
                window.setFlags(
                    WindowManager.LayoutParams.FLAG_SECURE,
                    WindowManager.LayoutParams.FLAG_SECURE
                )
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }
}
