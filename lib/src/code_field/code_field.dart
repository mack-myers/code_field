import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../code_theme/code_theme.dart';
import '../line_numbers/line_number_controller.dart';
import '../line_numbers/line_number_style.dart';
import 'code_auto_complete.dart';
import 'code_controller.dart';

class CodeField extends StatefulWidget {
  /// {@macro flutter.widgets.textField.smartQuotesType}
  final SmartQuotesType? smartQuotesType;

  /// {@macro flutter.widgets.textField.smartDashesType}
  final SmartDashesType? smartDashesType;

  /// {@macro flutter.widgets.textField.keyboardType}
  final TextInputType? keyboardType;

  /// {@macro flutter.widgets.textField.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.textField.maxLInes}
  final int? maxLines;

  /// {@macro flutter.widgets.textField.expands}
  final bool expands;

  /// Whether overflowing lines should wrap around or make the field scrollable horizontally
  final bool wrap;

  /// A CodeController instance to apply language highlight, themeing and modifiers
  final CodeController controller;

  /// A LineNumberStyle instance to tweak the line number column styling
  final LineNumberStyle lineNumberStyle;

  /// {@macro flutter.widgets.textField.cursorColor}
  final Color? cursorColor;

  /// {@macro flutter.widgets.textField.textStyle}
  final TextStyle? textStyle;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// Enables developer to register an onScrollChanged callback that will emit
  /// the most up-to-date ScrollController
  final void Function(ScrollController? controller)? onScrollChanged;

  /// {@macro flutter.widgets.editableText.readOnly}
  final bool readOnly;

  /// {@macro flutter.widgets.textField.isDense}
  final bool isDense;

  /// {@macro flutter.widgets.textField.selectionControls}
  final TextSelectionControls? selectionControls;

  /// {@macro flutter.widgets.textField.textInputAction}
  final TextInputAction? textInputAction;

  /// {@macro flutter.services.TextInputConfiguration.enableSuggestions}
  final bool enableSuggestions;

  /// {@macro flutter.widgets.textField.hintText}
  final String? hintText;
  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;
  final void Function()? onTap;
  final bool lineNumbers;
  final bool horizontalScroll;
  final TextStyle? hintStyle;
  final CodeAutoComplete? autoComplete;

  const CodeField({
    Key? key,
    required this.controller,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.padding = EdgeInsets.zero,
    this.lineNumberStyle = const LineNumberStyle(),
    this.enabled,
    this.onTap,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    this.onScrollChanged,
    this.isDense = false,
    this.smartQuotesType,
    this.smartDashesType,
    this.keyboardType,
    this.lineNumbers = true,
    this.horizontalScroll = true,
    this.selectionControls,
    this.hintText,
    this.hintStyle,
    this.autoComplete,
    this.textInputAction,
    this.enableSuggestions = false,
  }) : super(key: key);

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  // Add a controller
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  LineNumberController? _numberController;

  StreamSubscription<bool>? _keyboardVisibilitySubscription;
  FocusNode? _focusNode;
  String? lines;
  String longestLine = '';
  List<String> lineNumbers = [];

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();
    _numberController = LineNumberController(widget.lineNumberBuilder);
    widget.controller.addListener(_onTextChanged);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.onKey = _onKey;
    _focusNode!.attach(context, onKey: _onKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      createAutoComplate();
      _codeScroll?.addListener(() {
        if (widget.onScrollChanged != null) {
          widget.onScrollChanged!(_codeScroll);
        }
      });
    });

    _onTextChanged();
  }

  void createAutoComplate() {
    widget.autoComplete?.show(context, widget, _focusNode!);
    widget.controller.autoComplete = widget.autoComplete;
    _codeScroll?.addListener(hideAutoComplete);
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    if (widget.readOnly) {
      return KeyEventResult.ignored;
    }

    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _numberController?.dispose();
    _keyboardVisibilitySubscription?.cancel();
    widget.autoComplete?.remove();
    super.dispose();
  }

  void rebuild() {
    setState(() {});
  }

  void _onTextChanged() {
    // Rebuild line number
    final str = widget.controller.text.split('\n');
    final buf = <String>[];
    List<String> temp = [];

    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
      temp.add((k + 1).toString());
    }

    _numberController?.text = buf.join('\n');

    // Find longest line
    longestLine = '';
    widget.controller.text.split('\n').forEach((line) {
      if (line.length > longestLine.length) longestLine = line;
    });

    setState(() {
      lineNumbers = temp;
    });
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
  ) {
    final leftPad = widget.lineNumberStyle.margin / 2;
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: max(minWidth - leftPad, 0),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(longestLine, style: textStyle),
            ), // Add extra padding
          ),
          widget.expands ? Expanded(child: codeField) : codeField,
        ],
      ),
    );

    return MediaQuery(
      // TODO: Temporary fix: https://github.com/flutter/flutter/issues/127017
      data: !kIsWeb && Platform.isIOS
          ? const MediaQueryData(
              gestureSettings: DeviceGestureSettings(touchSlop: 8),
            )
          : MediaQuery.of(context),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: leftPad,
          right: widget.padding.right,
        ),
        scrollDirection: Axis.horizontal,

        /// Prevents the horizontal scroll if horizontalScroll is false
        physics: widget.horizontalScroll ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
        child: intrinsic,
      ),
    );
  }

  void removeAutoComplete() {
    widget.autoComplete?.remove();
  }

  void hideAutoComplete() {
    widget.autoComplete?.hide();
  }

  @override
  Widget build(BuildContext context) {
    // Default color scheme
    const rootKey = 'root';
    final defaultBg = Colors.grey.shade900;
    final defaultText = Colors.grey.shade200;

    final styles = CodeTheme.of(context)?.styles;
    Color? backgroundCol = widget.background ?? styles?[rootKey]?.backgroundColor ?? defaultBg;

    if (widget.decoration != null) {
      backgroundCol = null;
    }

    TextStyle textStyle = widget.textStyle ?? const TextStyle();
    textStyle = textStyle.copyWith(
      color: textStyle.color ?? styles?[rootKey]?.color ?? defaultText,
      fontSize: textStyle.fontSize ?? 16.0,
    );

    TextStyle numberTextStyle = widget.lineNumberStyle.textStyle ?? const TextStyle();
    final numberColor = (styles?[rootKey]?.color ?? defaultText).withOpacity(0.7);

    // Copy important attributes
    numberTextStyle = numberTextStyle.copyWith(
      color: numberTextStyle.color ?? numberColor,
      fontSize: numberTextStyle.fontSize,
      fontFamily: numberTextStyle.fontFamily,
    );

    final cursorColor = widget.cursorColor ?? styles?[rootKey]?.color ?? defaultText;

    Widget? lineNumberCol;
    SizedBox? numberCol;

    if (widget.lineNumbers) {
      lineNumberCol = Theme(
        data: ThemeData(
          scrollbarTheme: Theme.of(context).scrollbarTheme.copyWith(
                thumbVisibility: const WidgetStatePropertyAll(false),
                thumbColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
        ),
        child: TextField(
          smartQuotesType: widget.smartQuotesType,
          scrollPadding: widget.padding,
          scrollPhysics: const ClampingScrollPhysics(),
          style: numberTextStyle,
          controller: _numberController,
          enabled: false,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          selectionControls: widget.selectionControls,
          expands: widget.expands,
          scrollController: _numberScroll,
          decoration: InputDecoration(
            isCollapsed: true,
            isDense: widget.isDense,
            contentPadding: const EdgeInsets.only(top: 4, bottom: 4),
            border: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
          ),
          textAlign: widget.lineNumberStyle.textAlign,
          readOnly: true,
        ),
      );

      numberCol = SizedBox(
        width: widget.lineNumberStyle.width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.lineNumberStyle.background,
          ),
          child: lineNumberCol,
        ),
      );
    }

    final codeField = TextField(
      keyboardType: widget.keyboardType,
      smartQuotesType: widget.smartQuotesType,
      smartDashesType: widget.smartDashesType,
      focusNode: _focusNode,
      onTap: () {
        widget.autoComplete?.hide();
        widget.onTap?.call();
      },
      scrollPadding: widget.padding,
      scrollPhysics: const ClampingScrollPhysics(),
      style: textStyle,
      controller: widget.controller,
      minLines: widget.minLines,
      selectionControls: widget.selectionControls,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,
      decoration: InputDecoration(
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        isCollapsed: true,
        isDense: widget.isDense,
        hintStyle: widget.hintStyle,
        hintText: widget.hintText,
      ),
      onTapOutside: (e) {
        Future.delayed(const Duration(milliseconds: 300), hideAutoComplete);
      },
      cursorColor: cursorColor,
      autocorrect: false,
      enableSuggestions: widget.enableSuggestions,
      enabled: widget.enabled,
      onChanged: (text) {
        widget.onChanged?.call(text);
        widget.autoComplete?.streamController.add(text);
      },
      readOnly: widget.readOnly,
      textInputAction: widget.textInputAction,
    );

    final codeCol = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: widget.textSelectionTheme,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Control horizontal scrolling
          return widget.wrap ? codeField : _wrapInScrollView(codeField, textStyle, constraints.maxWidth);
        },
      ),
    );

    return Container(
      decoration: widget.decoration,
      color: backgroundCol,
      padding: !widget.lineNumbers ? const EdgeInsets.only(left: 8) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.lineNumbers && numberCol != null) numberCol,
          Expanded(child: codeCol),
        ],
      ),
    );
  }
}
