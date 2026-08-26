package com.matthiasn.lotti

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity, not FlutterActivity: the health plugin's
// onAttachedToActivity casts the activity to ComponentActivity for the
// Health Connect permission launcher, and a plain FlutterActivity is not one.
// It failed to register on every start — "MainActivity cannot be cast to
// androidx.activity.ComponentActivity" in logcat — so health import on
// Android never had a working platform side.
class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(FlutterHealthFitPlugin())
        flutterEngine.plugins.add(FlutterNativeTimezonePlugin())
    }
} 