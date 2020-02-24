import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/slides.dart';
import 'slide_page.dart';
import 'slide_list.dart';

class SlideEditor extends StatefulWidget {
  @override
  _SlideEditorState createState() => _SlideEditorState();
}

class _SlideEditorState extends State<SlideEditor> {
  int _currentSlideIndex = 0;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    FlutterSlidesModel model =
        Provider.of<FlutterSlidesModel>(context, listen: true);
    return Container(
      child: Column(
        children: <Widget>[
          _buildHeader(model),
          Container(height: 2.0),
          _buildBody(model),
        ],
      ),
    );
  }

  Widget _buildBody(FlutterSlidesModel model) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 300,
            child:  SlideList(
                currentSlideIndex: _currentSlideIndex,
                onSlideTapped: (index) {
                  if (mounted) {
                    setState(() {
                      _currentSlideIndex = index;
                    });
                  }
                },
              
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Container(
                  child: SlidePage(
                    isPreview: true,
                    slide: model.slides[_currentSlideIndex],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  final _debouncer = Debouncer();

  Widget _buildHeader(FlutterSlidesModel model) {
    const kSizeFieldWidth = 55.0;
    return Material(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
          children: [
            FlatButton.icon(
              onPressed: () => loadSlideDataFromFileChooser(),
              icon: Icon(Icons.folder),
              label: Text(model.filePath.split('/').last),
            ),
            Container(
              width: kSizeFieldWidth,
              child: TextFormField(
                initialValue: model.presentation.slideWidth.toString(),
                decoration: InputDecoration(labelText: 'Width'),
                onChanged: (val) {
                  _debouncer.run(() {
                    try {
                      final _value = num.tryParse(val);
                      model.updatePresentation(
                        model.presentation.copyWith(
                            slideWidth: _value,
                            slides: model.presentation.slides
                                .map((slide) => slide.copyWith(
                                      content: slide.content
                                          .map((content) =>
                                              content.copyWith(width: _value))
                                          .toList(),
                                    ))
                                .toList()),
                      );
                    } catch (e) {
                      print('Error: $e');
                    }
                  });
                },
              ),
            ),
            Container(width: 10.0),
            Container(
              width: kSizeFieldWidth,
              child: TextFormField(
                initialValue: model.presentation.slideHeight.toString(),
                decoration: InputDecoration(labelText: 'Height'),
                onChanged: (val) {
                  _debouncer.run(() {
                    try {
                      final _value = num.tryParse(val);
                      model.updatePresentation(model.presentation.copyWith(
                        slideHeight: _value,
                        slides: model.presentation.slides
                            .map((slide) => slide.copyWith(
                                  content: slide.content
                                      .map((content) =>
                                          content.copyWith(height: _value))
                                      .toList(),
                                ))
                            .toList(),
                      ));
                    } catch (e) {
                      print('Error: $e');
                    }
                  });
                },
              ),
            ),
            Spacer(),
            RaisedButton(
              child: Icon(Icons.play_arrow),
              onPressed: () => model.start(),
            ),
          ],
        ),
      ),
    );
  }
}

class Debouncer {
  final int milliseconds;
  VoidCallback action;
  Timer _timer;

  Debouncer({this.milliseconds = 2000});

  run(VoidCallback action) {
    if (_timer != null) {
      _timer.cancel();
    }

    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
