// lib/utils/location_service.dart

import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Determina y devuelve la posición actual del usuario.
  /// Solicita permisos si es necesario.
  static Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
          'Los servicios de ubicación están deshabilitados. Por favor actívalos en la configuración.');
    }

    // 2. Verificar los permisos de ubicación
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
            'Permiso de ubicación denegado. Por favor acepta los permisos para ver ofertas cercanas.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Los permisos de ubicación están denegados permanentemente. Actívalos en la configuración de la aplicación.');
    }

    // 3. Obtener la posición actual
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Calcula la distancia en kilómetros entre dos puntos
  static double calculateDistanceInKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final distanceInMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return distanceInMeters / 1000; // Convertir a kilómetros
  }

  /// Verifica si una oferta está dentro del radio especificado
  static bool isWithinRadius(
    Position userPosition,
    double offerLat,
    double offerLng,
    double maxDistanceKm,
  ) {
    final distance = calculateDistanceInKm(
      userPosition.latitude,
      userPosition.longitude,
      offerLat,
      offerLng,
    );
    return distance <= maxDistanceKm;
  }
}
