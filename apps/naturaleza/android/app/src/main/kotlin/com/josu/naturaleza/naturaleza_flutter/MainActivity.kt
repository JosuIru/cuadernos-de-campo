package com.josu.naturaleza.naturaleza_flutter

import android.hardware.GeomagneticField
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Declinación magnética (modelo WMM que trae Android) para pasar el
        // rumbo de la brújula a norte verdadero en «¿Quién canta?».
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "naturaleza/declinacion_magnetica")
            .setMethodCallHandler { llamada, resultado ->
                if (llamada.method != "declinacion") {
                    resultado.notImplemented()
                    return@setMethodCallHandler
                }
                val latitud = llamada.argument<Double>("latitud")
                val longitud = llamada.argument<Double>("longitud")
                val altitud = llamada.argument<Double>("altitud") ?: 0.0
                if (latitud == null || longitud == null) {
                    resultado.error("argumentos", "Faltan latitud o longitud", null)
                    return@setMethodCallHandler
                }
                val campo = GeomagneticField(
                    latitud.toFloat(), longitud.toFloat(), altitud.toFloat(), System.currentTimeMillis()
                )
                resultado.success(campo.declination.toDouble())
            }
    }
}
