import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/realtime_service.dart';

class RealtimeProvider extends ChangeNotifier {
  late final StreamSubscription<ClaimEvent> _subscription;
  final RealtimeService _realtimeService = RealtimeService();

  ClaimEvent? _lastEvent;
  ClaimEvent? get lastEvent => _lastEvent;

  RealtimeProvider() {
    _subscription = _realtimeService.eventStream.listen(_onEvent);
  }

  void _onEvent(ClaimEvent event) {
    _lastEvent = event;
    notifyListeners();
  }

  void notifyEvent(ClaimEventType type, {String? claimId, dynamic payload}) {
    _realtimeService.emit(type, claimId: claimId, payload: payload);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
