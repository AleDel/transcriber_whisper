import 'package:flutter/material.dart';

class FloatingWindow extends StatefulWidget {
  final Widget child;
  final double initialX;
  final double initialY;
  final String? title;
  final double initialWidth;
  final double initialHeight;

  const FloatingWindow({
    Key? key,
    required this.child,
    this.initialX = 10,
    this.initialY = 10,
    this.title,
    this.initialWidth = 300,
    this.initialHeight = 200,
  }) : super(key: key);

  @override
  State<FloatingWindow> createState() => _FloatingWindowState();
}

class _FloatingWindowState extends State<FloatingWindow> {
  late double _x;
  late double _y;
  late double _width;
  late double _height;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _x = widget.initialX;
    _y = widget.initialY;
    _width = widget.initialWidth;
    _height = widget.initialHeight;
  }

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  void _resize(DragUpdateDetails details) {
    setState(() {
      _width += details.delta.dx;
      _height += details.delta.dy;
      if (_width < 150) {
        _width = 150;
      }
      if (_height < 50) {
        _height = 50;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: Stack(
        children: [
          Draggable(
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: _width,
                height: _isCollapsed ? 50 : _height,
                child: _buildWindowContent(),
              ),
            ),
            childWhenDragging: Container(),
            onDragEnd: (details) {
              setState(() {
                _x = details.offset.dx;
                _y = details.offset.dy;
              });
            },
            child: SizedBox(
              width: _width,
              height: _isCollapsed ? 50 : _height,
              child: _buildWindowContent(),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onPanUpdate: _resize,
              child: Container(
                width: 20,
                height: 20,

                //color: Colors.blueGrey,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          //borderRadius: BorderRadius.circular(20),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),

                //child: const Icon(Icons.pivot_table_chart_rounded, size: 20, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null)
            GestureDetector(
              onTap: _toggleCollapse,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Icon(
                      _isCollapsed ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),

          if (!_isCollapsed)
            Expanded(child: Padding(padding: const EdgeInsets.all(8.0), child: widget.child)),
        ],
      ),
    );
  }
}
