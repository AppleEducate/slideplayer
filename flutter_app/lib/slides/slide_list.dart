import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/slides.dart';
import 'slide_page.dart';

class SlideList extends StatefulWidget {
  final int currentSlideIndex;
  final Function(int) onSlideTapped;

  const SlideList({
    Key key,
    @required this.currentSlideIndex,
    @required this.onSlideTapped,
  }) : super(key: key);
  @override
  _SlideListState createState() => _SlideListState();
}

class _SlideListState extends State<SlideList> with TickerProviderStateMixin {
  AnimationController _slideListController;

  double _lastSlideListScrollOffset = 0.0;

  int _currentSlideIndex = 0;

  @override
  void initState() {
    _slideListController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 250),
    );
    super.initState();
  }

  @override
  void didUpdateWidget(SlideList oldWidget) {
    if (oldWidget.currentSlideIndex != widget.currentSlideIndex) {
      if (mounted)
        setState(() {
          _currentSlideIndex = widget.currentSlideIndex;
        });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    FlutterSlidesModel model =
        Provider.of<FlutterSlidesModel>(context, listen: true);
    final _controller = ScrollController(
      initialScrollOffset: _lastSlideListScrollOffset,
    );
    return Container(
      width: 200.0,
      color: model.slidesListBGColor,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _lastSlideListScrollOffset = notification.metrics.pixels;
          return true;
        },
        child: Scrollbar(
          controller: _controller,
          child: ListView.builder(
            controller: _controller,
            itemCount: model.slides.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTapDown: (details) {
                  widget.onSlideTapped(index);
                },
                child: Stack(
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _currentSlideIndex != index
                              ? Colors.transparent
                              : model.slidesListHighlightColor,
                          width: 4.0,
                        ),
                      ),
                      child: SlidePage(
                        isPreview: true,
                        slide: model.slides[index],
                      ),
                    ),
                    Positioned(
                      bottom: 6.0,
                      left: 6.0,
                      child: Container(
                        height: 20.0,
                        child: Material(
                          color:
                              model.slidesListHighlightColor.withOpacity(0.75),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                '$index',
                                style: TextStyle(
                                    fontSize: 12.0,
                                    color: Colors.white,
                                    fontFamily: "RobotoMono"),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
