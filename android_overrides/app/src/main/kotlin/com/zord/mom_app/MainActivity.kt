package com.zord.mom_app

import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.OpenableColumns
import android.provider.Settings
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Opens the system screens that keep reminders alive on OPPO/ColorOS and
 * Samsung, and lets her pick audio files to add as sounds.
 */
class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private var pickDir: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mom_app/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(
                        mapOf(
                            "battery" to ignoresBatteryOptimizations(),
                            "exactAlarm" to canScheduleExactAlarms(),
                            "fullScreen" to canUseFullScreenIntent(),
                        )
                    )
                    "openBattery" -> { openBatterySettings(); result.success(null) }
                    "openExactAlarm" -> { openExactAlarmSettings(); result.success(null) }
                    "openFullScreen" -> { openFullScreenSettings(); result.success(null) }
                    "openAutostart" -> { openAutostartSettings(); result.success(null) }
                    "pickAudio" -> pickAudio(File(call.argument<String>("dir")!!), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickAudio(dir: File, result: MethodChannel.Result) {
        pendingPick?.success(null)
        pendingPick = result
        pickDir = dir
        val open = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("audio/*")
        try {
            startActivityForResult(open, PICK_AUDIO)
        } catch (e: ActivityNotFoundException) {
            try {
                startActivityForResult(Intent(Intent.ACTION_GET_CONTENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("audio/*"), PICK_AUDIO)
            } catch (e: ActivityNotFoundException) {
                pendingPick = null
                result.error("no_picker", e.message, null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_AUDIO) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPick ?: return
        val dir = pickDir ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        // Copy off the main thread: recordings can be several MB.
        Thread {
            try {
                val path = copyAudio(uri, dir)
                runOnUiThread { result.success(path) }
            } catch (e: Exception) {
                runOnUiThread { result.error("copy_failed", e.message, null) }
            }
        }.start()
    }

    /** Copies [uri] into [dir] under its own name (made unique); returns the path. */
    private fun copyAudio(uri: Uri, dir: File): String {
        dir.mkdirs()
        var name = (displayName(uri) ?: "sound").replace(Regex("[\\\\/:*?\"<>|]"), "_")
        if (!name.contains('.')) {
            val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(contentResolver.getType(uri))
            name += "." + (ext ?: "mp3")
        }
        val base = name.substringBeforeLast('.')
        val ext = name.substringAfterLast('.')
        var file = File(dir, name)
        var n = 2
        while (file.exists()) file = File(dir, "$base ${n++}.$ext")
        val input = contentResolver.openInputStream(uri) ?: throw IllegalStateException("unreadable")
        input.use { src -> file.outputStream().use { src.copyTo(it) } }
        return file.absolutePath
    }

    private fun displayName(uri: Uri): String? =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        }

    private fun ignoresBatteryOptimizations(): Boolean =
        (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .isIgnoringBatteryOptimizations(packageName)

    private fun canScheduleExactAlarms(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            (getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()

    private fun canUseFullScreenIntent(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .canUseFullScreenIntent()

    private fun packageUri(): Uri = Uri.parse("package:$packageName")

    private fun openBatterySettings() {
        if (!ignoresBatteryOptimizations() &&
            tryStart(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri()))
        ) return
        if (tryStart(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))) return
        openAppDetails()
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            tryStart(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, packageUri()))
        ) return
        openAppDetails()
    }

    private fun openFullScreenSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            tryStart(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, packageUri()))
        ) return
        openAppDetails()
    }

    private fun openAutostartSettings() {
        val candidates = listOf(
            // OPPO / ColorOS (different versions)
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"),
            // Samsung battery screen
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
        )
        for (component in candidates) {
            if (tryStart(Intent().setComponent(component))) return
        }
        openAppDetails()
    }

    private fun openAppDetails() {
        tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri()))
    }

    private fun tryStart(intent: Intent): Boolean =
        try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }

    companion object {
        private const val PICK_AUDIO = 4711
    }
}
