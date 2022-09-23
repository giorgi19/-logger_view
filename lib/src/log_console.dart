import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'ansi_parser.dart';

const Color _defaultPrimary = Color(0xFF1F1F28);
const Color _defaultSecondary = Color(0xFF38383D);

class LogConsole extends StatefulWidget {
  const LogConsole({
    Key? key,
    required this.loggerOutput,
    this.colorPrimary = _defaultPrimary,
    this.colorSecondary = _defaultSecondary,
  }) : super(key: key);

  final MemoryOutput loggerOutput;
  final Color colorPrimary;
  final Color colorSecondary;

  @override
  _LogConsoleState createState() => _LogConsoleState();
}

class RenderedEvent {
  RenderedEvent(
    this.id,
    this.level,
    this.span,
    this.lowerCaseText,
  );

  final int id;
  final Level level;
  final TextSpan span;
  final String lowerCaseText;
}

class _LogConsoleState extends State<LogConsole> {
  List<RenderedEvent> _filteredBuffer = <RenderedEvent>[];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();

  Level _filterLevel = Level.verbose;
  double _logFontSize = 14;
  double _fontBaseScaleFactor = 14;

  int _currentId = 0;
  bool _showScrollDownIndicator = false;

  @override
  void initState() {
    super.initState();
    _filterController.addListener(() => _refreshFilter());
  }

  @override
  void didChangeDependencies() {
    _refreshFilter();
    super.didChangeDependencies();
  }

  Future<void> _refreshFilter() async {
    final List<RenderedEvent> newFilteredBuffer =
        widget.loggerOutput.buffer.map((OutputEvent e) => _renderEvent(e)).where((RenderedEvent it) {
      final bool logLevelMatches = it.level.index >= _filterLevel.index;
      if (!logLevelMatches) {
        return false;
      } else if (_filterController.text.isNotEmpty) {
        final String filterText = _filterController.text.toLowerCase();
        return it.lowerCaseText.contains(filterText);
      } else {
        return true;
      }
    }).toList();
    setState(() {
      _filteredBuffer = newFilteredBuffer;
    });

    Future<void>.delayed(Duration.zero, _scrollToBottom);
  }

  Future<void> _exportShareLogFile() async {
    final Directory tempDir = await getTemporaryDirectory();
    final String logFilePath = join(tempDir.path, '${DateTime.now()}.log');
    final File logFile = File(logFilePath);
    final String logOutput =
        widget.loggerOutput.buffer.map((OutputEvent element) => element.lines.join('\n')).join('\n\n');
    await logFile.writeAsString(logOutput);
    await Share.shareFiles(<String>[logFilePath], mimeTypes: <String>['text/plain']);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: widget.colorPrimary,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (notification.metrics.axis == Axis.vertical) {
                    final bool shouldShow = notification.metrics.pixels < notification.metrics.maxScrollExtent - 150;
                    if (shouldShow != _showScrollDownIndicator) {
                      setState(() => _showScrollDownIndicator = shouldShow);
                    }
                  }
                  return false;
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final FocusScopeNode currentFocus = FocusScope.of(context);

                          if (!currentFocus.hasPrimaryFocus && currentFocus.hasFocus) {
                            FocusManager.instance.primaryFocus?.unfocus();
                          }
                        },
                        onScaleStart: (ScaleStartDetails details) => _fontBaseScaleFactor = _logFontSize,
                        onScaleUpdate: (ScaleUpdateDetails details) {
                          final double fontSize = _fontBaseScaleFactor * details.scale;
                          if (fontSize >= 4) {
                            setState(() => _logFontSize = fontSize);
                          }
                        },
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 1600,
                            child: LayoutBuilder(
                              builder: (_, __) {
                                return ListView.builder(
                                  shrinkWrap: true,
                                  controller: _scrollController,
                                  itemBuilder: (BuildContext context, int index) {
                                    final RenderedEvent logEntry = _filteredBuffer[index];
                                    return Text.rich(
                                      logEntry.span,
                                      key: Key(logEntry.id.toString()),
                                      style: TextStyle(fontSize: _logFontSize),
                                    );
                                  },
                                  itemCount: _filteredBuffer.length,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    _BottomBar(
                      color: widget.colorSecondary,
                      filterController: _filterController,
                      filterLevel: _filterLevel,
                      onFilterChanged: (Level? value) {
                        if (value != null) {
                          _filterLevel = value;
                        }
                        _refreshFilter();
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 60,
                child: TweenAnimationBuilder<double>(
                  tween:
                      Tween<double>(begin: _showScrollDownIndicator ? 0 : -20, end: _showScrollDownIndicator ? -20 : 0),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeIn,
                  builder: (BuildContext context, double value, Widget? child) {
                    final double progress = value / -20;

                    return Transform.translate(
                      offset: Offset(0, value),
                      child: Opacity(
                        opacity: progress,
                        child: child,
                      ),
                    );
                  },
                  child: ClipOval(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: _showScrollDownIndicator ? _scrollToBottom : null,
                        splashColor: Theme.of(context).splashColor,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                          ),
                          child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: IconButton(
                  onPressed: _exportShareLogFile,
                  splashRadius: 24,
                  icon: const Icon(Icons.share, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scrollToBottom() async {
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  RenderedEvent _renderEvent(OutputEvent event) {
    final AnsiParser parser = AnsiParser();
    final String text = event.lines.join('\n');
    parser.parse(text);
    return RenderedEvent(
      _currentId++,
      event.level,
      TextSpan(children: parser.spans),
      text.toLowerCase(),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    Key? key,
    required this.filterController,
    required this.filterLevel,
    required this.onFilterChanged,
    required this.color,
  }) : super(key: key);

  final TextEditingController filterController;
  final Level filterLevel;
  final ValueChanged<Level?> onFilterChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _LogBar(
      color: color,
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white),
              controller: filterController,
              decoration: InputDecoration(
                hintStyle: const TextStyle(color: Colors.white60),
                hintText: 'Filter log output',
                border: InputBorder.none,
                suffixIcon: filterController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () => filterController.clear(),
                        icon: const Icon(Icons.close),
                        splashRadius: 24,
                        color: Colors.white70,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<Level>(
            dropdownColor: color,
            value: filterLevel,
            borderRadius: BorderRadius.circular(8),
            underline: const SizedBox.shrink(),
            items: const <DropdownMenuItem<Level>>[
              DropdownMenuItem<Level>(
                value: Level.verbose,
                child: Text(
                  'Verbose',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem<Level>(
                value: Level.debug,
                child: Text(
                  'Debug',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem<Level>(
                value: Level.info,
                child: Text(
                  'Info',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem<Level>(
                value: Level.warning,
                child: Text(
                  'Warning',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem<Level>(
                value: Level.error,
                child: Text(
                  'Error',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem<Level>(
                value: Level.wtf,
                child: Text(
                  'Wtf',
                  style: TextStyle(color: Colors.white),
                ),
              )
            ],
            onChanged: onFilterChanged,
          ),
        ],
      ),
    );
  }
}

class _LogBar extends StatelessWidget {
  const _LogBar({
    Key? key,
    required this.child,
    required this.color,
  }) : super(key: key);

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Material(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: child,
        ),
      ),
    );
  }
}
