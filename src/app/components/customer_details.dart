import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../utils/apiClient.dart';

/// The order's customer name, or null when it is empty or a placeholder
/// ("Guest" / "NA"). Used for table chips and Pay Later prefill.
String? realCustomerName(dynamic order) {
  if (order is! Map) return null;
  final name = (order['customerName'] ?? '').toString().trim();
  if (name.isEmpty || name == 'Guest' || name == 'NA') return null;
  return name;
}

/// Website: an order without a table number is a pickup order.
bool isPickupOrder(dynamic order) =>
    order is Map && (order['tableNumber'] ?? '').toString().trim().isEmpty;

/// `value || fallback` from the website: null and empty both fall back.
String orTextFallback(dynamic value, String fallback) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

/// One row of GET /api/orders/customers/suggest.
class CustomerSuggestion {
  final String name;
  final String? phone; // null when no real phone is known
  final int orderCount;

  const CustomerSuggestion({required this.name, this.phone, required this.orderCount});

  factory CustomerSuggestion.fromJson(Map<String, dynamic> j) {
    final phone = j['phone']?.toString().trim();
    return CustomerSuggestion(
      name: (j['name'] ?? '').toString(),
      phone: (phone == null || phone.isEmpty) ? null : phone,
      orderCount: (j['orderCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Past customers of this branch whose name or phone starts with [query].
Future<List<CustomerSuggestion>> fetchCustomerSuggestions(String query, {CancelToken? cancelToken}) async {
  final res = await dioClient.get(
    '/api/orders/customers/suggest',
    queryParameters: {'q': query},
    cancelToken: cancelToken,
  );
  final data = res.data;
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((e) => CustomerSuggestion.fromJson(Map<String, dynamic>.from(e)))
      .where((c) => c.name.trim().isNotEmpty)
      .toList();
}

/// Website MenuModal suggestion logic: 2-character minimum, 250 ms debounce,
/// a new keystroke cancels the request in flight. Unlike the website, a failed
/// request (offline, 401 for accounts without a branch) clears the list
/// silently instead of leaving a stale dropdown.
class CustomerSuggestController extends ChangeNotifier {
  List<CustomerSuggestion> items = const [];
  Timer? _debounce;
  CancelToken? _inFlight;
  bool _disposed = false;

  /// Call on user edits only (TextField.onChanged), so filling the field
  /// after a pick does not fire another request.
  void onQueryChanged(String raw) {
    _debounce?.cancel();
    final query = raw.trim();
    if (query.length < 2) {
      _inFlight?.cancel();
      _set(const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      _inFlight?.cancel();
      final token = _inFlight = CancelToken();
      try {
        final list = await fetchCustomerSuggestions(query, cancelToken: token);
        if (!token.isCancelled) _set(list);
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) return;
        if (!token.isCancelled) _set(const []);
      }
    });
  }

  void clear() {
    _debounce?.cancel();
    _inFlight?.cancel();
    _set(const []);
  }

  void _set(List<CustomerSuggestion> value) {
    if (_disposed) return;
    items = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _inFlight?.cancel();
    super.dispose();
  }
}

/// A text field that suggests past customers in a dropdown anchored under it.
/// Picking a row calls [onSelected]; the parent decides which fields to fill.
class CustomerSuggestField extends StatefulWidget {
  const CustomerSuggestField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.onChanged,
    this.decoration = const InputDecoration(),
    this.style,
    this.keyboardType,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<CustomerSuggestion> onSelected;
  final ValueChanged<String>? onChanged;
  final InputDecoration decoration;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  State<CustomerSuggestField> createState() => _CustomerSuggestFieldState();
}

class _CustomerSuggestFieldState extends State<CustomerSuggestField> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _focus = FocusNode();
  final _fieldKey = GlobalKey();
  final _suggest = CustomerSuggestController();
  bool _wantOpen = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _suggest.addListener(_sync);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _suggest.removeListener(_sync);
    _suggest.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() => _setOpen(_focus.hasFocus);

  void _setOpen(bool open) {
    _wantOpen = open;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final show = _wantOpen && _suggest.items.isNotEmpty;
    if (show != _portal.isShowing) {
      show ? _portal.show() : _portal.hide();
    }
    setState(() {});
  }

  void _pick(CustomerSuggestion c) {
    _suggest.clear();
    _setOpen(false);
    widget.onSelected(c);
  }

  double _fieldWidth() {
    final box = _fieldKey.currentContext?.findRenderObject();
    return (box is RenderBox && box.hasSize) ? box.size.width : 280.0;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (_) => Positioned(
          width: _fieldWidth(),
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            offset: const Offset(0, 4),
            // Taps on a row count as "inside" the field, so it keeps focus
            // and the pick lands before the list closes.
            child: TextFieldTapRegion(child: _buildDropdown()),
          ),
        ),
        child: TextField(
          key: _fieldKey,
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          style: widget.style,
          decoration: widget.decoration,
          onTap: () => _setOpen(true),
          onTapOutside: (_) => _setOpen(false),
          onChanged: (value) {
            _setOpen(true);
            _suggest.onQueryChanged(value);
            widget.onChanged?.call(value);
          },
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12.r),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 256),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            for (final c in _suggest.items)
              InkWell(
                key: ValueKey(c.name + (c.phone ?? '')),
                onTap: () => _pick(c),
                hoverColor: const Color(0xFFFFF7ED), // orange-50
                highlightColor: const Color(0xFFFFF7ED),
                splashColor: const Color(0xFFFFEDD5),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (c.phone != null)
                              Text(
                                c.phone!,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDD5), // orange-100
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          '${c.orderCount} orders',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFEA580C), // orange-600
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
