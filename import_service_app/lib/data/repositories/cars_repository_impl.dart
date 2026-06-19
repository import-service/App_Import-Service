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
import 'package:import_service_app/domain/entities/create_vehicle_result.dart';
import 'package:import_service_app/domain/entities/customs_request_file.dart';
import 'package:import_service_app/domain/entities/request_file_upload_entry.dart';
import 'package:import_service_app/domain/entities/request_files_batch_upload_result.dart';
import 'package:import_service_app/domain/entities/request_status.dart';
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
        final patched = remoteItems.map(_patchMissingLegalInn).toList(growable: false);
        await _carInventory.replaceAll(patched);
        return Right(patched);
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
        final item = _patchMissingLegalInn(await _remoteDataSource.getRequestById(id));
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
  Future<Either<Failure, CreateVehicleResult>> createVehicle(
    RequestFormModel form, {
    void Function(int done, int total)? onUploadProgress,
  }) async {
    try {
      if (!_session.isDemo) {
        final created = await _remoteDataSource.createRequestWithFiles(
          form,
          onUploadProgress: onUploadProgress,
        );
        final patchedItem = created.item.legalInn?.trim().isNotEmpty == true
            ? created.item
            : created.item.copyWith(legalInn: form.companyInn.trim());
        final remoteItems = await _remoteDataSource.listRequests();
        await _carInventory.replaceAll(
          remoteItems.map(_patchMissingLegalInn).toList(growable: false),
        );
        await _carInventory.upsertItem(patchedItem);
        return Right(
          CreateVehicleResult(
            item: patchedItem,
            failedDocTypes: created.failedDocTypes,
          ),
        );
      }
      return Right(await _demoCreateVehicle(form, onUploadProgress: onUploadProgress));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  List<RequestFileUploadEntry> fileUploadEntriesFromForm(
    RequestFormModel form, {
    Set<String>? onlyDocTypes,
  }) {
    final all = CustomsRequestsRemoteDataSource.fileEntriesFromForm(form);
    if (onlyDocTypes == null || onlyDocTypes.isEmpty) {
      return all;
    }
    final allowed = onlyDocTypes.map((e) => e.trim().toLowerCase()).toSet();
    return all
        .where((e) => allowed.contains(e.docType.trim().toLowerCase()))
        .toList(growable: false);
  }

  @override
  Future<Either<Failure, RequestFilesBatchUploadResult>> retryPendingUploads({
    required String requestId,
    required List<RequestFileUploadEntry> items,
    void Function(int done, int total)? onUploadProgress,
  }) async {
    if (requestId.isEmpty) {
      return const Left(CacheFailure('Пустой идентификатор заявки'));
    }
    if (items.isEmpty) {
      return const Left(CacheFailure('Нет файлов для загрузки'));
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
        var updated = current;
        final failed = <String>[];
        for (final entry in items) {
          final file = File(entry.localPath);
          if (!await file.exists()) {
            failed.add(entry.docType);
            continue;
          }
          updated = _demoAttachFile(
            item: updated,
            docType: entry.docType,
            localPath: entry.localPath,
            fileName: p.basename(entry.localPath),
          );
        }
        await _carInventory.upsertItem(updated);
        return Right(
          RequestFilesBatchUploadResult(item: updated, failedDocTypes: failed),
        );
      }
      final batch = await _remoteDataSource.uploadRequestFilesBatch(
        requestId: requestId,
        items: items,
        onProgress: onUploadProgress,
      );
      await _carInventory.upsertItem(batch.item);
      return Right(
        RequestFilesBatchUploadResult(
          item: batch.item,
          failedDocTypes: batch.failedDocTypes,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, st) {
      AppLog.error('retryPendingUploads', error: e, stackTrace: st, tag: 'CarsRepo');
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<CreateVehicleResult> _demoCreateVehicle(
    RequestFormModel form, {
    void Function(int done, int total)? onUploadProgress,
  }) async {
    await Future<void>.delayed(_networkLatency);
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    var item = CarListItem(
      id: id,
      ownerFullName: form.personFullName.trim(),
      carMake: form.carBrand.trim(),
      carModel: form.carModel.trim(),
      vin: form.vin.trim(),
      status: RequestStatus.newRequest,
      legalInn: form.companyInn.trim(),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _carInventory.add(item);

    final entries = CustomsRequestsRemoteDataSource.fileEntriesFromForm(form);
    final total = entries.length;
    var done = 0;
    if (total > 0) {
      onUploadProgress?.call(0, total);
    }
    final failed = <String>[];
    for (final entry in entries) {
      final file = File(entry.localPath);
      if (!await file.exists()) {
        failed.add(entry.docType);
      } else {
        item = _demoAttachFile(
          item: item,
          docType: entry.docType,
          localPath: entry.localPath,
          fileName: p.basename(entry.localPath),
        );
      }
      done += 1;
      onUploadProgress?.call(done, total);
    }
    if (failed.isEmpty && entries.isNotEmpty) {
      item = item.copyWith(
        status: RequestStatus.onReview,
        external1cId: 'GUID-DEMO-$id',
      );
    }
    await _carInventory.upsertItem(item);
    return CreateVehicleResult(item: item, failedDocTypes: failed);
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
      final refreshed = await getVehicle(requestId);
      return refreshed.fold(
        (_) => Right(updated),
        (item) => Right(item),
      );
    } on ServerException catch (e) {
      AppLog.error('attachRequestFile', error: e, tag: 'CarsRepo');
      final recovered = await getVehicle(requestId);
      return recovered.fold(
        (_) => Left(ServerFailure(e.message)),
        (item) {
          if (_itemHasDocType(item, normalized)) {
            return Right(item);
          }
          return Left(ServerFailure(e.message));
        },
      );
    } catch (e, st) {
      AppLog.error('attachRequestFile', error: e, stackTrace: st, tag: 'CarsRepo');
      return Left(CacheFailure(e.toString()));
    }
  }

  CarListItem _patchMissingLegalInn(CarListItem item) {
    if (item.legalInn?.trim().isNotEmpty == true) return item;
    final sessionInn = _session.inn?.trim() ?? '';
    if (sessionInn.isEmpty) return item;
    return item.copyWith(legalInn: sessionInn);
  }

  CarListItem _demoAttachFile({
    required CarListItem item,
    required String docType,
    required String localPath,
    required String fileName,
  }) {
    final normalized = normalizeDocType(docType);
    final newFile = CustomsRequestFile(
      docType: normalized,
      fileName: fileName,
      mimeType: _mimeFromFileName(fileName),
      fileUrl: localPath,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final nextFiles = <CustomsRequestFile>[
      ...item.files.where((f) => normalizeDocType(f.docType) != normalized),
      newFile,
    ];
    return item.copyWith(files: nextFiles);
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

  static bool _itemHasDocType(CarListItem item, String docType) {
    final code = normalizeDocType(docType);
    if (code.isEmpty) return false;
    return item.files.any((f) => normalizeDocType(f.docType) == code);
  }
}
