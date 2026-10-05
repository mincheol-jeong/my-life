package com.mincheol.mylife

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.provider.Settings

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.mincheol.mylife/payment_import").setMethodCallHandler { call, result ->
            try {
                val store = PaymentInbox(this)
                when (call.method) {
                    "status" -> {
                        val component = ComponentName(this, PaymentNotificationListener::class.java)
                        val access = if (Build.VERSION.SDK_INT >= 27) {
                            getSystemService(NotificationManager::class.java).isNotificationListenerAccessGranted(component)
                        } else {
                            Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                                ?.split(":")?.contains(component.flattenToString()) == true
                        }
                        val apps = packageManager.queryIntentActivities(
                            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0
                        ).filter { it.activityInfo.packageName != packageName }
                            .distinctBy { it.activityInfo.packageName }
                            .map { mapOf("id" to it.activityInfo.packageName, "name" to it.loadLabel(packageManager).toString()) }
                            .sortedBy { it["name"] }
                        result.success(mapOf("enabled" to store.enabled, "access" to access,
                            "selected" to store.selected.toList(), "apps" to apps))
                    }
                    "configure" -> {
                        store.configure(call.argument<Boolean>("enabled") == true,
                            call.argument<List<String>>("selected") ?: emptyList())
                        result.success(null)
                    }
                    "openAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "pending" -> result.success(store.pending())
                    "acknowledge" -> {
                        store.acknowledge(call.argument<List<String>>("ids") ?: emptyList())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("PAYMENT_IMPORT", "Device import failed", null) }
        }
    }
}
