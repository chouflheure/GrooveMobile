import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/push_notification_repository.dart';

final pushNotificationRepositoryProvider =
    Provider<PushNotificationRepository>(
      (ref) => PushNotificationRepository(),
    );
