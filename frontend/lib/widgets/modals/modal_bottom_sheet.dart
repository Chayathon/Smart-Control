import 'package:flutter/material.dart';

/// Reusable Modal Bottom Sheet with consistent styling
class ModalBottomSheet {
  /// แสดง Modal Bottom Sheet แบบพื้นฐาน
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? height,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? Colors.transparent,
      builder: (context) {
        if (height != null) {
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: child,
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: child,
        );
      },
    );
  }

  /// แสดง Modal Bottom Sheet พร้อม title และปุ่มปิด
  static Future<T?> showWithTitle<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool showCloseButton = true,
    double? height,
    Widget? actions,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: height ?? MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (showCloseButton)
                      SizedBox(width: 40)
                    else
                      SizedBox.shrink(),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (showCloseButton)
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      SizedBox(width: 40),
                  ],
                ),
              ),
              // Content
              Expanded(child: child),
              // Actions (optional)
              if (actions != null)
                Container(
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: actions,
                ),
            ],
          ),
        );
      },
    );
  }

  /// แสดง Modal Bottom Sheet แบบปรับความสูงได้ (Draggable)
  static Future<T?> showDraggable<T>({
    required BuildContext context,
    required Widget Function(BuildContext, ScrollController, String) builder,
    double initialChildSize = 0.5,
    double minChildSize = 0.25,
    double maxChildSize = 0.95,
    bool expand = false,
    bool showSearch = false,
    String? searchHint,
    String? title,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DraggableModalContent<T>(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          expand: expand,
          showSearch: showSearch,
          searchHint: searchHint,
          title: title,
          builder: builder,
        );
      },
    );
  }

  /// แสดง Modal Bottom Sheet พร้อม keyboard padding
  static Future<T?> showFormModal<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    Widget? actions,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Container(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: child,
                  ),
                ),
                if (actions != null)
                  Container(padding: EdgeInsets.all(16.0), child: actions),
              ],
            ),
          ),
        );
      },
    );
  }

  /// แสดง Modal Bottom Sheet แบบเลือกรายการ (List Selection)
  static Future<T?> showListSelection<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T) itemLabel,
    Widget Function(T)? itemSubtitle,
    IconData Function(T)? itemIcon,
    Function(T)? onItemSelected,
    bool dismissOnSelect = true,
    bool showSearch = false,
    String? searchHint,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _ListSelectionModalContent<T>(
          title: title,
          items: items,
          itemLabel: itemLabel,
          itemSubtitle: itemSubtitle,
          itemIcon: itemIcon,
          onItemSelected: onItemSelected,
          dismissOnSelect: dismissOnSelect,
          showSearch: showSearch,
          searchHint: searchHint,
        );
      },
    );
  }
}

/// StatefulWidget สำหรับ Draggable Modal พร้อม Search
class _DraggableModalContent<T> extends StatefulWidget {
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool expand;
  final bool showSearch;
  final String? searchHint;
  final String? title;
  final Widget Function(BuildContext, ScrollController, String) builder;

  const _DraggableModalContent({
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.expand,
    required this.showSearch,
    required this.searchHint,
    required this.title,
    required this.builder,
  });

  @override
  State<_DraggableModalContent<T>> createState() =>
      _DraggableModalContentState<T>();
}

class _DraggableModalContentState<T> extends State<_DraggableModalContent<T>> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: widget.initialChildSize,
          minChildSize: widget.minChildSize,
          maxChildSize: widget.maxChildSize,
          expand: widget.expand,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title (if provided)
                if (widget.title != null) ...[
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      widget.title!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Divider(height: 1),
                ],
                // Search box
                if (widget.showSearch)
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: widget.searchHint ?? 'ค้นหา...',
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                // Content
                Expanded(
                  child: widget.builder(
                    context,
                    scrollController,
                    _searchQuery,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// StatefulWidget สำหรับ List Selection Modal พร้อม Search
class _ListSelectionModalContent<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final Widget Function(T)? itemSubtitle;
  final IconData Function(T)? itemIcon;
  final Function(T)? onItemSelected;
  final bool dismissOnSelect;
  final bool showSearch;
  final String? searchHint;

  const _ListSelectionModalContent({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.itemSubtitle,
    required this.itemIcon,
    required this.onItemSelected,
    required this.dismissOnSelect,
    required this.showSearch,
    required this.searchHint,
  });

  @override
  State<_ListSelectionModalContent<T>> createState() =>
      _ListSelectionModalContentState<T>();
}

class _ListSelectionModalContentState<T>
    extends State<_ListSelectionModalContent<T>> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<T> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    return widget.items.where((item) {
      final label = widget.itemLabel(item).toLowerCase();
      return label.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                widget.title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Divider(height: 1),
            // Search box
            if (widget.showSearch)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.searchHint ?? 'ค้นหา...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            // List
            Flexible(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'ไม่พบรายการที่ค้นหา',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ListTile(
                          leading: widget.itemIcon != null
                              ? Icon(widget.itemIcon!(item))
                              : null,
                          title: Text(widget.itemLabel(item)),
                          subtitle: widget.itemSubtitle != null
                              ? widget.itemSubtitle!(item)
                              : null,
                          onTap: () {
                            if (widget.onItemSelected != null) {
                              widget.onItemSelected!(item);
                            }
                            if (widget.dismissOnSelect) {
                              Navigator.pop(context, item);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
