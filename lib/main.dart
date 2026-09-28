import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'core/app_config.dart';
import 'data/api_client.dart';
import 'data/country_remote_data_source.dart';
import 'data/country_repository.dart';
import 'data/fallback_country_repository.dart';
import 'data/remote_country_repository.dart';
import 'data/static_country_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CountryTriviaApp(repository: _buildRepository()));
}

/// Wires the data graph: API first, checked-in list as the offline fallback.
CountryRepository _buildRepository() {
  final ApiClient apiClient = ApiClient(http.Client());
  return FallbackCountryRepository(
    RemoteCountryRepository(
      CountryRemoteDataSource(apiClient, path: AppConfig.countriesPath),
    ),
    StaticCountryRepository(),
  );
}
