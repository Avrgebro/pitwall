/// Every path in the app, so screens never spell out URLs.
abstract final class Routes {
  static const setup = '/setup';

  static const home = '/home';

  static const vehicles = '/vehicles';
  static const addVehicle = '/vehicles/add';
  static String vehicle(String id) => '/vehicles/$id';
  static String vehicleName(String id) => '/vehicles/$id/name';
  static String vehicleAdapter(String id) => '/vehicles/$id/adapter';
  static String vehicleProfile(String id) => '/vehicles/$id/profile';
  static String vehicleValues(String id) => '/vehicles/$id/values';
  static String vehicleTripStart(String id) => '/vehicles/$id/trip-start';

  static const settings = '/settings';
  static const webhookSettings = '/settings/webhook';
  static const intervalSettings = '/settings/interval';
  static const backgroundChecks = '/settings/checks';
  static const about = '/settings/about';
  static const developer = '/settings/developer';
}
