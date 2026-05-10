import 'package:dartz/dartz.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/error/failures.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/data/datasources/remote/customs_requests_remote_data_source.dart';
import 'package:import_service_app/data/local/car_inventory_state_holder.dart';
import 'package:import_service_app/data/local/default_cars_seed.dart';
import 'package:import_service_app/data/models/request_form_model.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class CarsRepositoryImpl implements CarsRepository {
  CarsRepositoryImpl({
    required CarInventoryStateHolder carInventory,
    required CustomsRequestsRemoteDataSource remoteDataSource,
    required AuthSessionController session,
    required SharedPreferences sharedPreferences,
  })  : _carInventory = carInventory,
        _remoteDataSource = remoteDataSource,
        _session = session,
        _prefs = sharedPreferences;

  static const Duration _networkLatency = Duration(milliseconds: 420);

  final CarInventoryStateHolder _carInventory;
  final CustomsRequestsRemoteDataSource _remoteDataSource;
  final AuthSessionController _session;
  final SharedPreferences _prefs;

  @override
  Future<Either<Failure, List<CarListItem>>> listVehicles({
    int? limit,
    int? offset,
    String? status,
  }) async {
    try {
      if (!_session.isDemo) {
        final remoteItems = await _remoteDataSource.listRequests(
          limit: limit,
          offset: offset,
          status: status,
        );
        await _carInventory.replaceAll(remoteItems);
        return Right(remoteItems);
      }
      return Right(_carInventory.items);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CarListItem>> getVehicle(String id) async {
    if (id.isEmpty) {
      return const Left(CacheFailure('Пустой идентификатор заявки'));
    }
    try {
      if (!_session.isDemo) {
        final item = await _remoteDataSource.getRequestById(id);
        await _carInventory.upsertItem(item);
        return Right(item);
      }
      for (final e in _carInventory.items) {
        if (e.id == id) {
          return Right(e);
        }
      }
      return const Left(CacheFailure('Заявка не найдена'));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CarListItem>> createVehicle(
    RequestFormModel form, {
    void Function(int done, int total)? onUploadProgress,
  }) async {
    try {
      if (!_session.isDemo) {
        final created = await _remoteDataSource.createRequest(
          form,
          onUploadProgress: onUploadProgress,
        );
        final remoteItems = await _remoteDataSource.listRequests();
        await _carInventory.replaceAll(remoteItems);
        return Right(created);
      }
      await Future<void>.delayed(_networkLatency);
      final vin = form.vin.trim();
      final item = CarListItem(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        ownerFullName: form.personFullName.trim(),
        carMake: form.carBrand.trim(),
        carModel: form.carModel.trim(),
        vin: vin,
        status: RequestStatus.newRequest,
      );
      await _carInventory.add(item);
      return Right(item);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> bootstrapDemoRequests() async {
    final pendingDemoByPrefs =
        _prefs.getBool(SessionPreferencesKeys.demoUserActive) ?? false;
    if (!_session.isDemo && !pendingDemoByPrefs) {
      AppLog.trace('bootstrap: skip (not demo, prefs not pending)', tag: 'CarsRepo');
      return const Right(null);
    }
    try {
      const seed = DefaultCarsSeed.items;
      await _carInventory.replaceAll(List<CarListItem>.from(seed));
      AppLog.trace('bootstrapDemo: replaceAll, count=${seed.length}', tag: 'CarsRepo');
      return const Right(null);
    } catch (e) {
      AppLog.error('bootstrapDemo', error: e, tag: 'CarsRepo');
      return Left(CacheFailure(e.toString()));
    }
  }
}
