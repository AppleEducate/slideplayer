import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_slides/models/slide.dart';
import 'package:flutter_slides/classes/presentation.dart' as presUtils;
import 'package:flutter_slides/models/slide_factors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watcher/watcher.dart';
import 'package:flutter_slides/utils/color_utils.dart' as ColorUtils;
import 'package:file_chooser/file_chooser.dart' as file_chooser;

FlutterSlidesModel loadedSlides = FlutterSlidesModel();

const _RECENTLY_OPENED_FILE_PREFS_KEY = 'last_opened_file_path';

void loadSlideDataFromFileChooser() {
  file_chooser.showOpenPanel((result, paths) {
    if (paths != null) {
      _loadSlidesData(paths.first);
    }
  }, allowsMultipleSelection: false);
}

void loadRecentlyOpenedSlideData() {
  SharedPreferences.getInstance().then(
    (prefs) {
      String filePath = prefs.getString(_RECENTLY_OPENED_FILE_PREFS_KEY);
      if (filePath != null) {
        _loadSlidesData(filePath);
      }
    },
  );
}

void _loadSlidesData(String filePath) {
  loadedSlides.loadSlidesData(filePath);
}

class FlutterSlidesModel extends ChangeNotifier {
  List<Slide> slides;
  String externalFilesRoot;
  double slideWidth = 1920.0;
  double slideHeight = 1080.0;
  double fontScaleFactor = 1920.0;
  Color projectBGColor = Color(0xFFF0F0F0);
  Color slidesListBGColor = Color(0xFFDDDDDD);
  Color slidesListHighlightColor = Color(0xFF40C4FF);
  bool animateSlideTransitions = false;
  bool showDebugContainers = false;
  bool autoAdvance = false;
  int autoAdvanceDurationMillis = 30000;

  bool _isPresenting = false;
  bool get isPresenting => _isPresenting;

  void start() {
    _isPresenting = true;
    notifyListeners();
  }

  void stop() {
    _isPresenting = false;
    notifyListeners();
  }

  void updatePresentation(presUtils.Presentation value) {
    _presentation = value;
    // List<Slide> slideList = [];
    // SlideFactors slideFactors = SlideFactors(
    //   normalizationWidth: value.slideWidth,
    //   normalizationHeight: value.slideHeight,
    //   fontScaleFactor: value.fontScaleFactor,
    // );
    // for (var slide in value.slides) {
    //   List contentList = slide.content == null
    //       ? null
    //       : slide.content.map((e) => e.toJson()).toList();
    //   int advancementCount = slide?.advancementCount ?? 0;
    //   bool animatedTransition = slide?.animatedTransition ?? false;
    //   Color slideBGColor =
    //       ColorUtils.colorFromString(slide?.bgColor ?? '0xFFFFFFFF');
    //   slideList.add(
    //     Slide(
    //         content: contentList,
    //         slideFactors: slideFactors,
    //         advancementCount: advancementCount,
    //         backgroundColor: slideBGColor,
    //         animatedTransition: animatedTransition),
    //   );
    // }
    // loadedSlides.slides = slideList;
    // this.slides = slideList;
    notifyListeners();
  }

  String filePath;
  StreamSubscription _slidesFileSubscription;
  StreamSubscription _replaceFileSubscription;
  presUtils.Presentation _presentation;
  presUtils.Presentation get presentation => _presentation;
  bool get isReady => _presentation != null;

  Future<void> loadSlidesData(String filePath,
      [bool replaceValues = true]) async {
    this.filePath = filePath;
    _slidesFileSubscription?.cancel();
    _replaceFileSubscription?.cancel();
    _slidesFileSubscription = Watcher(filePath).events.listen((event) {
      loadSlidesData(filePath);
      notifyListeners();
    });
    try {
      String fileString = File(filePath).readAsStringSync();
      if (replaceValues) {
        final replaceFilePath =
            File(File(filePath).parent.path + '/replace_values.json').path;
        final replaceFile = File(replaceFilePath);
        if (replaceFile.existsSync()) {
          String replaceFileString = replaceFile.readAsStringSync();
          Map replaceJSON = jsonDecode(replaceFileString);
          for (final entry in replaceJSON.entries) {
            fileString = fileString.replaceAll(
                "\"@replace/${entry.key}\"", entry.value.toString());
          }
          _replaceFileSubscription =
              Watcher(replaceFilePath).events.listen((event) {
            loadSlidesData(filePath);
            notifyListeners();
          });
        }
      }
      presUtils.Presentation p =
          await presUtils.backgroundPresentationFromJson(fileString);
      Map json = jsonDecode(fileString);
      loadedSlides.slideWidth = (p?.slideWidth ?? 1920.0).toDouble();
      loadedSlides.slideHeight = (p?.slideHeight ?? 1080.0).toDouble();
      loadedSlides.fontScaleFactor =
          (p?.fontScaleFactor ?? loadedSlides.slideWidth).toDouble();
      loadedSlides.projectBGColor =
          ColorUtils.colorFromString(json['project_bg_color']) ??
              loadedSlides.projectBGColor;
      loadedSlides.slidesListBGColor =
          ColorUtils.colorFromString(json['project_slide_list_bg_color']) ??
              loadedSlides.slidesListBGColor;
      loadedSlides.slidesListHighlightColor = ColorUtils.colorFromString(
              json['project_slide_list_highlight_color']) ??
          loadedSlides.slidesListHighlightColor;
      loadedSlides.animateSlideTransitions =
          json['animate_slide_transitions'] ?? false;
      loadedSlides.showDebugContainers = json['show_debug_containers'] ?? false;
      loadedSlides.externalFilesRoot = json['external_files_root'] ??
          File(filePath).parent.path + '/external_files';
      loadedSlides.autoAdvance = json['auto_advance'] ?? false;
      loadedSlides.autoAdvanceDurationMillis =
          json['auto_advance_duration_millis'] ?? 30000;

      imageCache.maximumSize;
      SlideFactors slideFactors = SlideFactors(
        normalizationWidth: loadedSlides.slideWidth,
        normalizationHeight: loadedSlides.slideHeight,
        fontScaleFactor: loadedSlides.fontScaleFactor,
      );
      List slides = json['slides'];
      List<Slide> slideList = [];
      for (Map slide in slides) {
        List contentList = slide['content'];
        int advancementCount = slide['advancement_count'] ?? 0;
        bool animatedTransition = slide['animated_transition'] ?? false;
        Color slideBGColor =
            ColorUtils.colorFromString(slide['bg_color'] ?? '0xFFFFFFFF');
        slideList.add(
          Slide(
              content: contentList,
              slideFactors: slideFactors,
              advancementCount: advancementCount,
              backgroundColor: slideBGColor,
              animatedTransition: animatedTransition),
        );
      }
      loadedSlides.slides = slideList;
      updatePresentation(p);
      loadedSlides.notifyListeners();
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_RECENTLY_OPENED_FILE_PREFS_KEY, filePath);
      });
    } catch (e) {
      print("Error loading slides file: $e");
    }
  }
}
