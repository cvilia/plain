package com.cvilia.plain

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.pm.PackageManager
import android.os.Build
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "app/security"
    private val widgetChannelName = "app/widget"
    private val filePickerChannelName = "app/file_picker"
    private val notificationChannelName = "app/notification"
    private var securityChannel: MethodChannel? = null
    private var isSecure = true // Default: enable privacy overlay

    private var pendingFileResult: MethodChannel.Result? = null

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

        // File picker: ACTION_GET_CONTENT → copy to cache → return path
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filePickerChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFile" -> {
                        val mime = (call.argument<String>("mime")) ?: "*/*"
                        val ext = call.argument<String>("extension")
                        if (pendingFileResult != null) {
                            result.error("busy", "Picker already open", null)
                            return@setMethodCallHandler
                        }
                        pendingFileResult = result
                        try {
                            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = mime
                                if (!ext.isNullOrEmpty()) {
                                    putExtra(Intent.EXTRA_MIME_TYPES, mimeTypesForExtension(ext))
                                }
                            }
                            startActivityForResult(
                                Intent.createChooser(intent, "选择文件"),
                                REQUEST_PICK_FILE
                            )
                        } catch (e: Exception) {
                            pendingFileResult = null
                            result.error("intent", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
        }

        // Local notifications (recurring due / confirm)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val id = (call.argument<Int>("id")) ?: 0
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val payload = call.argument<String>("payload")
                        ensureNotificationChannel()
                        showLocalNotification(id, title, body, payload)
                        result.success(null)
                    }
                    "cancel" -> {
                        val id = (call.argument<Int>("id")) ?: 0
                        NotificationManagerCompat.from(this).cancel(id)
                        result.success(null)
                    }
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            val granted = ActivityCompat.checkSelfPermission(
                                this, Manifest.permission.POST_NOTIFICATIONS
                            ) == PackageManager.PERMISSION_GRANTED
                            if (!granted) {
                                ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    REQUEST_POST_NOTIFICATIONS
                                )
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            result.success(true)
                        } else {
                            result.success(true)
                        }
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_PICK_FILE) {
            val pending = pendingFileResult
            pendingFileResult = null
            if (pending == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != RESULT_OK || data?.data == null) {
                pending.success(null) // cancelled
                return
            }
            val uri = data.data!!
            try {
                val path = copyUriToCache(uri)
                pending.success(path)
            } catch (e: Exception) {
                pending.error("copy", e.message, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun copyUriToCache(uri: Uri): String {
        val name = queryDisplayName(uri) ?: "picked_${System.currentTimeMillis()}"
        val out = File(cacheDir, name)
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(out).use { output ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("Cannot open input stream")
        return out.absolutePath
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && cursor.moveToFirst()) {
                return cursor.getString(idx)
            }
        }
        return uri.lastPathSegment
    }

    private fun mimeTypesForExtension(ext: String): Array<String> {
        val e = ext.removePrefix(".").lowercase()
        return when (e) {
            "db", "sqlite", "sqlite3" -> arrayOf(
                "application/octet-stream",
                "application/vnd.sqlite3",
                "application/x-sqlite3",
                "*/*"
            )
            else -> arrayOf("*/*")
        }
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

    private fun ensureNotificationChannel() {
        val mgr = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            NOTIF_CHANNEL_ID,
            "周期记账",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "周期记账到期提醒与确认"
        }
        mgr.createNotificationChannel(channel)
    }

    private fun showLocalNotification(id: Int, title: String, body: String, payload: String?) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = "com.cvilia.plain.NOTIFY"
            payload?.let { putExtra("payload", it) }
        }
        val pending = PendingIntent.getActivity(
            this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < 33
        ) {
            NotificationManagerCompat.from(this).notify(id, notification)
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

    companion object {
        private const val REQUEST_PICK_FILE = 7101
        private const val REQUEST_POST_NOTIFICATIONS = 7102
        private const val NOTIF_CHANNEL_ID = "recurring_due"
    }
}
