import 'package:geolocator/geolocator.dart';

/// Un objeto de utilidad para manejar la ubicación.
class LocationService {
  /// Determina la posición actual del dispositivo.
  ///
  /// Lanza una excepción (String) si los servicios están deshabilitados
  /// o si los permisos son denegados (de forma temporal o permanente).
  static Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Verificar si los servicios de ubicación están habilitados.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Los servicios de ubicación están deshabilitados. Por favor, actívalos.');
    }

    // 2. Verificar el estado actual de los permisos.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Si están denegados, solicitarlos.
      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied) {
        // Los permisos siguen denegados después de la solicitud.
        return Future.error(
            'Los permisos de ubicación fueron denegados. No se puede obtener la ubicación.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Los permisos están denegados permanentemente. 
      return Future.error(
          'Los permisos de ubicación están denegados permanentemente. Actívalos manualmente en la configuración de la aplicación.');
    }

    // 3. Si todo está bien, obtener la posición actual del dispositivo.
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );
  }
}