package com.example.snakecare_mobile

import android.Manifest
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "org.snakecare/emergency"
        private const val BLE_PERMISSION_REQUEST = 4102
    }

    private var pendingBlePayload: String? = null
    private var pendingBleResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capabilities" -> result.success(capabilities())
                    "prepareSms" -> prepareSms(
                        call.argument<String>("number").orEmpty(),
                        call.argument<String>("message").orEmpty(),
                        result,
                    )
                    "prepareMissedCall" -> prepareMissedCall(
                        call.argument<String>("number").orEmpty(),
                        result,
                    )
                    "startBleBroadcast" -> startBle(
                        call.argument<String>("payload").orEmpty(),
                        result,
                    )
                    "stopBleBroadcast" -> {
                        val intent = Intent(this, SosBleService::class.java)
                            .setAction(SosBleService.ACTION_STOP)
                        startService(intent)
                        result.success(true)
                    }
                    "signalInfo" -> signalInfo(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun capabilities(): Map<String, Any> {
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = manager.adapter
        val canReadBluetooth = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
        return mapOf(
            "platform" to "android",
            "smsComposer" to canHandle(Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:"))),
            "dialer" to canHandle(Intent(Intent.ACTION_DIAL, Uri.parse("tel:112"))),
            "bleAdvertiser" to (packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)),
            "bleEnabled" to (canReadBluetooth && adapter?.isEnabled == true),
            "foregroundService" to true,
        )
    }

    private fun prepareSms(number: String, message: String, result: MethodChannel.Result) {
        if (number.isBlank()) {
            result.error("MISSING_GATEWAY", "Configure a verified SMS gateway number first.", null)
            return
        }
        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:${Uri.encode(number)}"))
            .putExtra("sms_body", message)
        if (!canHandle(intent)) {
            result.error("SMS_UNAVAILABLE", "No SMS application is available.", null)
            return
        }
        startActivity(intent)
        result.success(true)
    }

    private fun prepareMissedCall(number: String, result: MethodChannel.Result) {
        if (number.isBlank()) {
            result.error("MISSING_GATEWAY", "Configure a verified missed-call gateway first.", null)
            return
        }
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${Uri.encode(number)}"))
        if (!canHandle(intent)) {
            result.error("DIALER_UNAVAILABLE", "No phone dialer is available.", null)
            return
        }
        startActivity(intent)
        result.success(true)
    }

    private fun startBle(payload: String, result: MethodChannel.Result) {
        if (payload.isBlank()) {
            result.error("INVALID_PAYLOAD", "The BLE SOS payload is empty.", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADVERTISE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingBlePayload = payload
            pendingBleResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.BLUETOOTH_CONNECT),
                BLE_PERMISSION_REQUEST,
            )
            return
        }
        launchBleService(payload, result)
    }

    private fun launchBleService(payload: String, result: MethodChannel.Result) {
        val intent = Intent(this, SosBleService::class.java)
            .setAction(SosBleService.ACTION_START)
            .putExtra(SosBleService.EXTRA_PAYLOAD, payload)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }
        result.success(true)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != BLE_PERMISSION_REQUEST) return
        val result = pendingBleResult
        val payload = pendingBlePayload
        pendingBleResult = null
        pendingBlePayload = null
        if (result == null || payload == null) return
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            launchBleService(payload, result)
        } else {
            result.error("PERMISSION_DENIED", "Bluetooth advertising permission was denied.", null)
        }
    }

    private fun signalInfo(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            result.success(mapOf("available" to false, "reason" to "Android 9 or newer required"))
            return
        }
        val hasPhonePermission =
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) ==
                PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        if (!hasPhonePermission) {
            result.success(mapOf("available" to false, "reason" to "Phone-state permission required"))
            return
        }
        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val strength = telephony.signalStrength
        result.success(
            mapOf(
                "available" to (strength != null),
                "level" to (strength?.level ?: -1),
                "isGsm" to (strength?.isGsm ?: false),
            ),
        )
    }

    private fun canHandle(intent: Intent): Boolean = intent.resolveActivity(packageManager) != null
}
