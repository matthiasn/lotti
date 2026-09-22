package com.matthiasn.lotti

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/**
 * One-shot device location over the AOSP [LocationManager].
 *
 * Replaces the `location` Flutter plugin, whose Android side is built on
 * Google Play Services' fused location provider. Everything here is part of
 * Android itself or AndroidX, so the app works on de-Googled devices and
 * builds for F-Droid without proprietary code.
 *
 * `getCurrentLocation` asks for permission when it has not been granted yet,
 * then answers with a map of the fix, or null when permission is refused,
 * location is switched off, or no fix arrives in time and no recent one is
 * known. The Dart side falls back to IP geolocation on null.
 */
class LottiLocationPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        /** Must match `AndroidLocationSource.channelName` on the Dart side. */
        const val CHANNEL = "com.matthiasn.lotti/location"
        private const val PERMISSION_REQUEST_CODE = 0x10c4
        private const val DEFAULT_TIMEOUT_MS = 10_000L

        /** A last-known fix older than this describes somewhere else. */
        private const val MAX_LAST_KNOWN_AGE_MS = 15 * 60 * 1000L
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activityBinding: ActivityPluginBinding? = null

    /** Continuations waiting on the one permission dialog on screen. */
    private val pendingPermission = mutableListOf<(Boolean) -> Unit>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        // Nothing will answer a dialog whose activity is gone.
        resolvePermission(false)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() {
        // A rotation keeps the dialog's result coming to the new activity, so
        // pending requests stay queued rather than being refused.
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getCurrentLocation" -> {
                val timeoutMs =
                    call.argument<Number>("timeoutMs")?.toLong() ?: DEFAULT_TIMEOUT_MS
                withPermission { granted ->
                    if (granted) currentLocation(timeoutMs, result) else result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun isGranted(permission: String) =
        ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasAnyLocationPermission() =
        isGranted(Manifest.permission.ACCESS_FINE_LOCATION) ||
            isGranted(Manifest.permission.ACCESS_COARSE_LOCATION)

    private fun withPermission(onDecided: (Boolean) -> Unit) {
        if (hasAnyLocationPermission()) {
            onDecided(true)
            return
        }
        val activity = activityBinding?.activity
        if (activity == null) {
            onDecided(false)
            return
        }
        pendingPermission.add(onDecided)
        // Only the first caller opens the dialog; later ones wait for it.
        if (pendingPermission.size > 1) return
        // Both together, so Android 12+ can offer "approximate" as a choice.
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        resolvePermission(grantResults.any { it == PackageManager.PERMISSION_GRANTED })
        return true
    }

    private fun resolvePermission(granted: Boolean) {
        val waiting = pendingPermission.toList()
        pendingPermission.clear()
        waiting.forEach { it(granted) }
    }

    @SuppressLint("MissingPermission") // Checked by withPermission.
    private fun currentLocation(timeoutMs: Long, result: Result) {
        val manager = context.getSystemService(LocationManager::class.java)
        if (manager == null || !LocationManagerCompat.isLocationEnabled(manager)) {
            result.success(null)
            return
        }
        val provider = preferredProvider(manager)
        if (provider == null) {
            result.success(null)
            return
        }

        val signal = CancellationSignal()
        var answered = false
        fun answer(location: Location?) {
            if (answered) return
            answered = true
            mainHandler.removeCallbacksAndMessages(signal)
            result.success((location ?: recentLastKnown(manager))?.toMap())
        }

        try {
            mainHandler.postAtTime(
                {
                    signal.cancel()
                    answer(null)
                },
                signal,
                SystemClock.uptimeMillis() + timeoutMs,
            )
            LocationManagerCompat.getCurrentLocation(
                manager,
                provider,
                signal,
                ContextCompat.getMainExecutor(context),
            ) { location -> answer(location) }
        } catch (e: SecurityException) {
            // Permission was revoked between the check and the request.
            if (!answered) {
                answered = true
                mainHandler.removeCallbacksAndMessages(signal)
                result.error("location_permission", e.message, null)
            }
        }
    }

    /**
     * Android's own fused provider (API 31+, part of AOSP rather than Play
     * Services) blends GPS and network; before it, the network provider
     * answers fastest and GPS is the last resort. GPS needs the precise
     * permission, which the user may have declined in favour of approximate.
     */
    private fun preferredProvider(manager: LocationManager): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            manager.hasProvider(LocationManager.FUSED_PROVIDER) &&
            manager.isProviderEnabled(LocationManager.FUSED_PROVIDER)
        ) {
            return LocationManager.FUSED_PROVIDER
        }
        if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            return LocationManager.NETWORK_PROVIDER
        }
        if (isGranted(Manifest.permission.ACCESS_FINE_LOCATION) &&
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER)
        ) {
            return LocationManager.GPS_PROVIDER
        }
        return null
    }

    /** The freshest fix any enabled provider remembers, if it is recent. */
    @SuppressLint("MissingPermission") // Checked by withPermission.
    private fun recentLastKnown(manager: LocationManager): Location? {
        val now = SystemClock.elapsedRealtimeNanos()
        return manager.getProviders(true)
            .mapNotNull { provider ->
                try {
                    manager.getLastKnownLocation(provider)
                } catch (e: SecurityException) {
                    null
                }
            }
            .filter { (now - it.elapsedRealtimeNanos) / 1_000_000 <= MAX_LAST_KNOWN_AGE_MS }
            .maxByOrNull { it.elapsedRealtimeNanos }
    }

    private fun Location.toMap(): Map<String, Any?> = mapOf(
        "latitude" to latitude,
        "longitude" to longitude,
        "altitude" to if (hasAltitude()) altitude else null,
        "accuracy" to if (hasAccuracy()) accuracy.toDouble() else null,
        "heading" to if (hasBearing()) bearing.toDouble() else null,
        "speed" to if (hasSpeed()) speed.toDouble() else null,
        "speedAccuracy" to
            if (hasSpeedAccuracy()) speedAccuracyMetersPerSecond.toDouble() else null,
    )
}
