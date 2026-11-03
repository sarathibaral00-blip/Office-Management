import 'package:supabase_flutter/supabase_flutter.dart';
import 'result.dart';

Future<Result<T>> guard<T>(Future<T> Function() work) async {
  try {
    return Result.success(await work());
  } on FunctionException catch (e) {
    final d = e.details;
    return Result.failure(
      Failure(
        d is Map && d['error'] is String
            ? d['error'] as String
            : 'Unable to complete this action. Please try again.',
      ),
    );
  } on AuthException catch (e) {
    return Result.failure(Failure(e.message));
  } on StorageException catch (_) {
    return const Result.failure(
      Failure(
        'Photo upload was rejected. Check its type, size and your session.',
      ),
    );
  } on FormatException catch (e) {
    return Result.failure(Failure(e.message));
  } on PostgrestException catch (e) {
    if (e.code == '23505') {
      return const Result.failure(
        Failure('This record already exists. Use a different name or value.'),
      );
    }
    if (e.code == '42501') {
      return const Result.failure(
        Failure('You do not have permission to perform this action.'),
      );
    }
    if (e.code == '23503') {
      return const Result.failure(
        Failure(
          'A selected record is no longer available. Refresh and try again.',
        ),
      );
    }
    if (e.code == 'P0001') {
      return Result.failure(Failure(e.message));
    }
    return const Result.failure(
      Failure('Unable to load workspace data. Please retry.'),
    );
  } catch (_) {
    return const Result.failure(
      Failure('Connection unavailable. Please try again.'),
    );
  }
}
