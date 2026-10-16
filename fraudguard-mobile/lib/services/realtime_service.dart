import 'dart:async';

enum ClaimEventType {
  claimCreated,
  documentUploaded,
  investigatorAssigned,
  investigatorReviewSubmitted,
  claimApproved,
  claimRejected,
}

class ClaimEvent {
  final ClaimEventType type;
  final String? claimId;
  final dynamic payload;

  ClaimEvent({
    required this.type,
    this.claimId,
    this.payload,
  });
}

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final StreamController<ClaimEvent> _eventController = StreamController<ClaimEvent>.broadcast();

  Stream<ClaimEvent> get eventStream => _eventController.stream;

  void emit(ClaimEventType type, {String? claimId, dynamic payload}) {
    _eventController.add(ClaimEvent(type: type, claimId: claimId, payload: payload));
  }

  void dispose() {
    _eventController.close();
  }
}
