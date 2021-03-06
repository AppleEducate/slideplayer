import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_slides/models/slides.dart';
import 'package:flutter_slides/slides/slide_page.dart';
import 'package:menubar/menubar.dart';
import 'package:provider/provider.dart';

import '../utils/menus.dart';
import 'slide_editor.dart';
import 'slide_list.dart';

class SlidePresentation extends StatefulWidget {
  @override
  _SlidePresentationState createState() => _SlidePresentationState();
}

class _SlidePresentationState extends State<SlidePresentation>
    with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  int _currentSlideIndex = 0;
  int _transitionStartIndex = 0;
  int _transitionEndIndex = 0;
  final int _lisTapKeycode = 6;
  bool listTapAllowed = false;
  AnimationController _transitionController;
  AnimationController _slideListController;

  SlidePageController _slidePageController = SlidePageController();
  Timer _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();

    _transitionController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _slideListController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 250),
    );

    loadRecentlyOpenedSlideData();
  }

  @override
  void dispose() {
    _slideListController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    FocusScope.of(context).requestFocus(_focusNode);
  }

  @override
  Widget build(BuildContext context) {
    FlutterSlidesModel model =
        Provider.of<FlutterSlidesModel>(context, listen: true);
    setApplicationMenu([
      fileMenu,
      Submenu(label: 'Presentation', children: [
        MenuItem(
          label: 'Start',
          shortcut: LogicalKeySet(LogicalKeyboardKey.meta,
              LogicalKeyboardKey.shift, LogicalKeyboardKey.keyP),
          onClicked: () {
            _slidePageController?.start();
            model.start();
            _slideListController.value = 0;
          },
        ),
        MenuItem(
          label: 'Stop',
          shortcut: LogicalKeySet(LogicalKeyboardKey.meta,
              LogicalKeyboardKey.shift, LogicalKeyboardKey.keyE),
          onClicked: () {
            _slidePageController?.exit();
            model.stop();
            _slideListController.value = 0;
          },
        ),
        MenuItem(
          label: 'Go to Start',
          shortcut: LogicalKeySet(LogicalKeyboardKey.meta,
              LogicalKeyboardKey.shift, LogicalKeyboardKey.keyS),
          onClicked: () => _moveToSlideAtIndex(model, 0),
        ),
        MenuItem(
          label: 'Show Help',
          shortcut: LogicalKeySet(LogicalKeyboardKey.meta,
              LogicalKeyboardKey.shift, LogicalKeyboardKey.keyH),
          onClicked: () {
            final _markdown = """
## Hints

**To advance:**
- right arrow
- or, spacebar

**To go back:**
- left arrow

**To toggle slide selector sidebar:**
- `]` to show
- `[` to hide

**To change to a new slide in sidebar:**
- `z + click` on the slide

**To present fullscreen**
- `cmd + ctl + F`
- or, select the green "full screen" button in the upper left of the window

**To leave fullscreen**
- `cmd + ctl + F`
- or, move your cursor to the top of the screen and tap the green button in upper left

""";
            showDialog(
              context: context,
              builder: (_) => Center(
                child: Container(
                  width: 400,
                  height: 520,
                  child: Card(
                    child: Markdown(data: _markdown),
                  ),
                ),
              ),
            );
          },
        ),
      ]),
    ]);
    _autoAdvanceTimer?.cancel();
    if (model.autoAdvance) {
      _autoAdvanceTimer = Timer.periodic(
          Duration(milliseconds: model.autoAdvanceDurationMillis), (_) {
        _advancePresentation(model);
      });
    }

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        onKeyEvent(event, model);
      },
      child: AnimatedBuilder(
        animation: _slideListController,
        builder: (context, child) {
          if (model.slides == null) {
            return _emptyState(
              Theme.of(context).scaffoldBackgroundColor,
              model.slidesListHighlightColor,
            );
          }
          bool animatedTransition =
              model.slides[_currentSlideIndex].animatedTransition ||
                  model.animateSlideTransitions;
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            constraints: BoxConstraints.expand(),
            child: !model.isPresenting
                ? SlideEditor()
                : Stack(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(width: _slideListController.value * 200.0),
                          Container(width: _slideListController.value * 50.0),
                          Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: animatedTransition
                                  ? _animatedSlideTransition(model)
                                  : _currentSlide(model),
                            ),
                          ),
                          Container(width: _slideListController.value * 50.0),
                        ],
                      ),
                      _slideListController.value <= 0.01
                          ? Container()
                          : SlideList(
                              currentSlideIndex: _currentSlideIndex,
                              onSlideTapped: (index) {
                                if (listTapAllowed && mounted) {
                                  setState(() {
                                    _currentSlideIndex = index;
                                    _moveToSlideAtIndex(model, index);
                                  });
                                }
                              },
                            ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  _animatedSlideTransition(FlutterSlidesModel model) {
    final startingSlide = SlidePage(
      slide: model.slides[_transitionStartIndex],
    );
    final endingSlide = SlidePage(
      key: GlobalObjectKey(model.slides[_transitionEndIndex]),
      slide: model.slides[_transitionEndIndex],
      controller: _slidePageController,
    );
    return FlutterSlidesTransition(
      animation: _transitionController,
      startingSlide: startingSlide,
      endingSlide: endingSlide,
      transitionBuilder: (context, start, end) {
        final firstScreen = Opacity(
          opacity: 1.0 - _transitionController.value,
          child: start,
        );
        final secondScreen = Opacity(
          opacity: _transitionController.value,
          child: end,
        );
        final stackLayout = Stack(
          children: <Widget>[
            firstScreen,
            secondScreen,
          ],
        );
        return stackLayout;
      },
    );
  }

  Widget _currentSlide(FlutterSlidesModel model) {
    return SlidePage(
      slide: model.slides[_currentSlideIndex],
      controller: _slidePageController,
      index: _currentSlideIndex,
    );
  }

  Widget _emptyState(Color bgColor, Color buttonColor) {
    return Material(
      color: bgColor,
      child: Container(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              FlutterLogo(
                size: 80.0,
              ),
              Container(
                height: 12.0,
              ),
              Text(
                "Flutter Slides",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32.0),
              ),
              Container(
                height: 12.0,
              ),
              MaterialButton(
                minWidth: 200.0,
                height: 60.0,
                color: buttonColor,
                onPressed: () {
                  loadSlideDataFromFileChooser();
                },
                child: Text(
                  'Open',
                  style: TextStyle(color: Colors.white, fontSize: 24.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  onKeyEvent(RawKeyEvent event, FlutterSlidesModel model) {
    switch (event.runtimeType) {
      case RawKeyDownEvent:
        break;
      case RawKeyUpEvent:
        int upKeyCode;
        switch (event.data.runtimeType) {
          case RawKeyEventDataMacOs:
            final RawKeyEventDataMacOs data = event.data;
            upKeyCode = data.keyCode;
            if (upKeyCode == _lisTapKeycode) {
              listTapAllowed = false;
            }
            break;
          default:
            throw new Exception('Unsupported platform');
        }
        return;
      default:
        throw new Exception('Unexpected runtimeType of RawKeyEvent');
    }

    int keyCode;
    switch (event.data.runtimeType) {
      case RawKeyEventDataMacOs:
        final RawKeyEventDataMacOs data = event.data;
        keyCode = data.keyCode;
        if (keyCode == 53) {
          _moveToSlideAtIndex(model, 0);
          _slidePageController?.exit();
        } else if (keyCode == 33) {
          _slideListController?.reverse();
        } else if (keyCode == 49) {
          _advancePresentation(model);
        } else if (keyCode == 30) {
          _slideListController?.forward();
        } else if (keyCode == 123) {
          // tapped left
          _reversePresentation(model);
        } else if (keyCode == 124) {
          _advancePresentation(model);
        } else if (keyCode == _lisTapKeycode) {
          listTapAllowed = true;
        }
        break;
      default:
        throw new Exception('Unsupported platform');
    }
  }

  void _advancePresentation(FlutterSlidesModel model) {
    bool didAdvanceSlideContent = _slidePageController.advanceSlideContent();
    if (!didAdvanceSlideContent) {
      if (model.autoAdvance && _currentSlideIndex == model.slides.length - 1) {
        _moveToSlideAtIndex(model, 0);
      } else {
        _moveToSlideAtIndex(model, _currentSlideIndex + 1);
      }
    }
  }

  void _reversePresentation(FlutterSlidesModel model) {
    bool didReverseSlideContent = _slidePageController.reverseSlideContent();
    if (!didReverseSlideContent) {
      _moveToSlideAtIndex(model, _currentSlideIndex - 1);
    }
  }

  void _moveToSlideAtIndex(FlutterSlidesModel model, int index) {
    int nextIndex = index.clamp(0, model.slides.length - 1);
    int prepIndex = (index + 1).clamp(0, model.slides.length - 1);
    if (_currentSlideIndex == nextIndex) {
      return;
    }

    // precaching next slide images.
    if (prepIndex != nextIndex) {
      for (Map content in model.slides[prepIndex].content) {
        if (content['type'] == 'image') {
          if (content['evict'] ?? false) continue;
          ImageProvider provider;
          if (content.containsKey('asset')) {
            provider = Image.asset(content['asset']).image;
          }
          if (content.containsKey('file')) {
            final root = model.externalFilesRoot;
            provider = FileImage(File('$root/${content['file']}'));
          }
          final config = createLocalImageConfiguration(context);
          provider?.resolve(config);
        }
      }
    }
    setState(() {
      _transitionController.forward(from: 0.0);
      _transitionStartIndex = _currentSlideIndex;
      _transitionEndIndex = nextIndex;
      _currentSlideIndex = nextIndex;
    });
  }
}

typedef FlutterSlidesTransitionBuilder = Widget Function(
    BuildContext context, SlidePage startingSlide, SlidePage endingSlide);

class FlutterSlidesTransition extends AnimatedWidget {
  final SlidePage startingSlide;
  final SlidePage endingSlide;
  final FlutterSlidesTransitionBuilder transitionBuilder;

  FlutterSlidesTransition({
    this.startingSlide,
    this.endingSlide,
    this.transitionBuilder,
    Listenable animation,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return transitionBuilder(context, startingSlide, endingSlide);
  }
}
