import 'package:zynkup/features/events/models/event_model.dart';

bool canModify(Event event, String uid, bool isAdmin) {
  return isAdmin || event.organizerId == uid;
}
