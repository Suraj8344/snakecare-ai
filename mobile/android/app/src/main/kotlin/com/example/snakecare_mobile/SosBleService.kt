package com.example.snakecare_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class SosBleService : Service() {
    companion object {
        const val ACTION_START = "org.snakecare.START_BLE_SOS"
        const val ACTION_STOP = "org.snakecare.STOP_BLE_SOS"
        const val EXTRA_PAYLOAD = "payload"
        private const val CHANNEL_ID = "snakecare_offline_sos"
        private const val NOTIFICATION_ID = 112
        private const val MANUFACTURER_ID = 0x0D05
    }

    private val callback = object : AdvertiseCallback() {}

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopBroadcast()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val payload = intent?.getStringExtra(EXTRA_PAYLOAD).orEmpty()
        startForeground(NOTIFICATION_ID, notification())
        startBroadcast(payload)
        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        stopBroadcast()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startBroadcast(payload: String) {
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val advertiser = manager.adapter?.bluetoothLeAdvertiser ?: return
        advertiser.stopAdvertising(callback)
        val compactPayload = payload.toByteArray(Charsets.UTF_8).copyOfRange(
            0,
            minOf(payload.toByteArray(Charsets.UTF_8).size, 22),
        )
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .build()
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addManufacturerData(MANUFACTURER_ID, compactPayload)
            .build()
        advertiser.startAdvertising(settings, data, callback)
    }

    private fun stopBroadcast() {
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        manager.adapter?.bluetoothLeAdvertiser?.stopAdvertising(callback)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Offline SOS broadcast",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Visible while SnakeCare broadcasts an emergency BLE beacon"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun notification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_dialog_alert)
        .setContentTitle("SnakeCare offline SOS active")
        .setContentText("Broadcasting an emergency relay beacon nearby")
        .setOngoing(true)
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setContentIntent(
            PendingIntent.getActivity(
                this,
                0,
                packageManager.getLaunchIntentForPackage(packageName),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            ),
        )
        .build()
}
