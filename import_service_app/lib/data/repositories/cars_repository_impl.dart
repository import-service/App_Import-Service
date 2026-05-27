import 'dart:io';

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
import 'package:import_service_app/core/constants/customs_catalog.dart';
import 'package:import_service_app/domain/entities/car_list_item.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
import 'package:import_service_app/domain/entities/vehicle_finance_item.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:path/path.dart' as p;
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
      return const Right(null);
    }
    try {
      const seed = DefaultCarsSeed.items;
      await _carInventory.replaceAll(List<CarListItem>.from(seed));
      return const Right(null);
    } catch (e) {
      AppLog.error('bootstrapDemo', error: e, tag: 'CarsRepo');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CarListItem>> attachRequestFile({
    required String requestId,
    required String docType,
    required String localFilePath,
  }) async {
    final normalized = normalizeDocType(docType);
    if (normalized.isEmpty) {
      return const Left(CacheFailure('Не указан тип документа'));
    }
    try {
      if (_session.isDemo) {
        await Future<void>.delayed(_networkLatency);
        CarListItem? current;
        for (final e in _carInventory.items) {
          if (e.id == requestId) {
            current = e;
            break;
          }
        }
        if (current == null) {
          return const Left(CacheFailure('Заявка не найдена'));
        }
        final file = File(localFilePath);
        if (!await file.exists()) {
          return const Left(CacheFailure('Файл не найден'));
        }
        final updated = _demoAttachFile(
          item: current,
          docType: normalized,
          localPath: localFilePath,
          fileName: p.basename(localFilePath),
        );
        await _carInventory.upsertItem(updated);
        return Right(updated);
      }
      final updated = await _remoteDataSource.attachRequestFiles(
        requestId: requestId,
        items: [(docType: normalized, localPath: localFilePath)],
      );
      await _carInventory.upsertItem(updated);
      return Right(updated);
    } on ServerException catch (e) {
      AppLog.error('attachRequestFile', error: e, tag: 'CarsRepo');
      return Left(ServerFailure(e.message));
    } catch (e, st) {
      AppLog.error('attachRequestFile', error: e, stackTrace: st, tag: 'CarsRepo');
      return Left(CacheFailure(e.toString()));
    }
  }

  CarListItem _demoAttachFile({
    required CarListItem item,
    required String docType,
    required String localPath,
    required String fileName,
  }) {
    final newFile = CustomsRequestFile(
      docType: docType,
      fileName: fileName,
      mimeType: _mimeFromFileName(fileName),
      fileUrl: localPath,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final nextFiles = <CustomsRequestFile>[
      ...item.files.where((f) => normalizeDocType(f.docType) != docType),
      newFile,
    ];
    var finance = item.financeItems;
    if (docType == 'payment_recycling_fee_receipt') {
      finance = finance
          .map(
            (line) => line.lineType == 'recycling_fee'
                ? VehicleFinanceItem(
                    lineType: line.lineType,
                    amountText: line.amountText,
                    title: line.title,
                    paymentQrUrl: line.paymentQrUrl,
                    receiptUrl: localPath,
                  )
                : line,
          )
          .toList();
    } else if (docType == 'payment_customs_duty_receipt') {
      finance = finance
          .map(
            (line) => line.lineType == 'customs_duty'
                ? VehicleFinanceItem(
                    lineType: line.lineType,
                    amountText: line.amountText,
                    title: line.title,
                    paymentQrUrl: line.paymentQrUrl,
                    receiptUrl: localPath,
                  )
                : line,
          )
          .toList();
    }
    return CarListItem(
      id: item.id,
      ownerFullName: item.ownerFullName,
      carMake: item.carMake,
      carModel: item.carModel,
      vin: item.vin,
      status: item.status,
      legalEntityName: item.legalEntityName,
      legalEmail: item.legalEmail,
      legalPhone: item.legalPhone,
      individualFullName: item.individualFullName,
      individualPhone: item.individualPhone,
      individualSnils: item.individualSnils,
      hasSunroof: item.hasSunroof,
      hasAllWheelDrive: item.hasAllWheelDrive,
      importedLast12Months: item.importedLast12Months,
      ownsOtherCars: item.ownsOtherCars,
      commentText: item.commentText,
      engineSpec: item.engineSpec,
      engineVolume: item.engineVolume,
      statusSinceDateLabel: item.statusSinceDateLabel,
      statusSubType: item.statusSubType,
      external1cId: item.external1cId,
      managerExternal1cId: item.managerExternal1cId,
      managerFullName: item.managerFullName,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      financeItems: finance,
      vehiclePhotoUrls: item.vehiclePhotoUrls,
      deliveredDocuments: item.deliveredDocuments,
      files: nextFiles,
    );
  }

  static String _mimeFromFileName(String name) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
