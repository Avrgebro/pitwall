/// Every path in the app, so screens never spell out URLs.
abstract final class Routes {
  static const setup = '/setup';

  static const home = '/home';

  static const vehicles = '/vehicles';
  static const addVehicle = '/vehicles/add';
  static String vehicle(String id) => '/vehicles/$id';
  static String vehicleValues(String id) => '/vehicles/$id/values';

  static const settings = '/settings';
  static const credits = '/settings/credits';
  static const developer = '/settings/developer';
}
