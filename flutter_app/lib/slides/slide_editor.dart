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
            child: SlideList(
              currentSlideIndex: _currentSlideIndex,
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Card(
                  elevation: 4.0,
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

  Widget _buildHeader(FlutterSlidesModel model) {
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
            Spacer(),
            RaisedButton(
              child: Icon(Icons.play_arrow),
              onPressed: () => model.setPresentationMode(true),
            ),
          ],
        ),
      ),
    );
  }
}
