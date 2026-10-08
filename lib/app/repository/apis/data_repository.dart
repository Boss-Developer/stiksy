import '../../mvvm/model/api_response_model/api_response.dart';
import '../../services/https_calls.dart';

/// Repository for general data/API calls.
class DataRepository {
  DataRepository({HttpsCalls? httpsCalls})
    : _httpsCalls = httpsCalls ?? HttpsCalls();

  final HttpsCalls _httpsCalls;

  /// Sample endpoint — replace with your real data calls.
  Future<ApiResponse<void>> fetchExample() async {
    final response = await _httpsCalls.getApiHits('example');
    return ApiResponse<void>(success: response.statusCode == 200);
  }
}
