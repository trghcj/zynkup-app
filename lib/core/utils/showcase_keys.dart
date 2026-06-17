import 'package:flutter/material.dart';

class ShowcaseKeys {
  // Navigation
  static final GlobalKey homeTab = GlobalKey();
  static final GlobalKey discoverTab = GlobalKey();
  static final GlobalKey ticketsTab = GlobalKey();
  static final GlobalKey profileTab = GlobalKey();
  
  // Home / Feed / Create
  static final GlobalKey createFab = GlobalKey();
  
  // Profile
  static final GlobalKey profileBio = GlobalKey();
  static final GlobalKey profileBadges = GlobalKey();
  static final GlobalKey profileEvents = GlobalKey();
  static final GlobalKey profileTimeline = GlobalKey();
  static final GlobalKey profileAvatar = GlobalKey();

  static List<GlobalKey> get allKeys => [
        homeTab,
        discoverTab,
        ticketsTab,
        profileTab,
        createFab,
        profileAvatar,
        profileBio,
        profileBadges,
        profileEvents,
        profileTimeline,
      ];
}
