import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationResult {
  final String address;
  final double lat;
  final double lng;

  const LocationResult({
    required this.address,
    required this.lat,
    required this.lng,
  });
}

/// Location search via Supabase Edge Function `google-places` (Google key stays server-side).
class LocationSearchField extends StatefulWidget {
  final SupabaseClient supabase;
  final String labelText;
  final String hintText;
  final bool enabled;
  /// Called whenever the value changes (including cleared).
  final ValueChanged<LocationResult?> onChanged;
  /// Fired when user picks a suggestion (address + coordinates from Place Details).
  final void Function(String address, double lat, double lng) onLocationSelected;
  final LocationResult? initialValue;

  const LocationSearchField({
    super.key,
    required this.supabase,
    required this.onChanged,
    required this.onLocationSelected,
    this.labelText = 'Location',
    this.hintText = 'Search address',
    this.enabled = true,
    this.initialValue,
  });

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  /// Delayed hide so tapping a suggestion isn't cancelled by immediate blur-clear.
  Timer? _blurHideSuggestionsTimer;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _predictions = const [];
  String _sessionToken = '';
  LocationResult? _selected;

  /// When true, the next [TextField.onChanged] is from us setting text after a pick — do not clear selection.
  bool _ignoreNextControllerChange = false;

  @override
  void initState() {
    super.initState();
    _sessionToken = _newSessionToken();
    _selected = widget.initialValue;
    if (_selected != null) {
      _controller.text = _selected!.address;
    }
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    _blurHideSuggestionsTimer?.cancel();
    _blurHideSuggestionsTimer = null;

    if (_focusNode.hasFocus) {
      return;
    }

    // Wait before clearing: on Web, focus leaves the field before ListTile onTap runs.
    _blurHideSuggestionsTimer = Timer(const Duration(milliseconds: 200), () {
      _blurHideSuggestionsTimer = null;
      if (!mounted) return;
      if (!_focusNode.hasFocus) {
        setState(() => _predictions = const []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _blurHideSuggestionsTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _newSessionToken() {
    return '${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}';
  }

  String _errorMessage(dynamic data, int status, [String fallback = 'Request failed']) {
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return '$fallback ($status)';
  }

  /// Parses Edge Function payload `{ address, latitude, longitude }` or raw Google
  /// `result.formatted_address` + `result.geometry.location.{lat,lng}`.
  LocationResult? _parsePlaceDetailsBody(Map<String, dynamic> body) {
    final addrNorm = body['address']?.toString().trim();
    final latNorm = body['latitude'];
    final lngNorm = body['longitude'];
    if (addrNorm != null &&
        addrNorm.isNotEmpty &&
        latNorm != null &&
        lngNorm != null) {
      return LocationResult(
        address: addrNorm,
        lat: (latNorm as num).toDouble(),
        lng: (lngNorm as num).toDouble(),
      );
    }

    final resultRaw = body['result'];
    if (resultRaw is Map) {
      final result = Map<String, dynamic>.from(resultRaw);
      final geometryRaw = result['geometry'];
      if (geometryRaw is Map) {
        final geometry = Map<String, dynamic>.from(geometryRaw);
        final locationRaw = geometry['location'];
        if (locationRaw is Map) {
          final loc = Map<String, dynamic>.from(locationRaw);
          final lat = loc['lat'];
          final lng = loc['lng'];
          final formatted =
              (result['formatted_address'] ?? '').toString().trim();
          if (lat != null && lng != null && formatted.isNotEmpty) {
            return LocationResult(
              address: formatted,
              lat: (lat as num).toDouble(),
              lng: (lng as num).toDouble(),
            );
          }
        }
      }
    }
    return null;
  }

  void _onTextChanged(String value) {
    if (_ignoreNextControllerChange) {
      _ignoreNextControllerChange = false;
      return;
    }

    _debounce?.cancel();
    _selected = null;
    widget.onChanged(null);

    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _predictions = const [];
        _error = null;
        _loading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchPredictions(q);
    });
  }

  Future<void> _fetchPredictions(String query) async {
    if (!widget.enabled) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supabase = widget.supabase;
      final res = await supabase.functions.invoke(
        'google-places',
        body: {
          'action': 'autocomplete',
          'input': query,
          'sessionToken': _sessionToken,
        },
      );

      final data = res.data;
      if (res.status != 200) {
        throw Exception(_errorMessage(data, res.status, 'Autocomplete failed'));
      }

      final body = data is Map<String, dynamic>
          ? data
          : jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

      final status = (body['status'] ?? '').toString();

      if (status == 'OK') {
        final raw = (body['predictions'] as List?) ?? const [];
        setState(() {
          _predictions = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
        return;
      }

      if (status == 'ZERO_RESULTS') {
        setState(() {
          _predictions = const [];
          _loading = false;
        });
        return;
      }

      final apiError = (body['error_message'] ?? '').toString();
      throw Exception('Autocomplete status=$status $apiError');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _predictions = const [];
        _loading = false;
      });
    }
  }

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    _blurHideSuggestionsTimer?.cancel();
    _blurHideSuggestionsTimer = null;

    // ignore: avoid_print
    print('Selecting place: ${prediction['description']}');

    final placeId = (prediction['place_id'] ?? '').toString().trim();
    if (placeId.isEmpty) return;

    // 点击后立刻关闭建议列表并收起键盘，再请求详情
    if (!mounted) return;
    setState(() {
      _predictions = const [];
      _loading = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    _focusNode.unfocus();

    try {
      final supabase = widget.supabase;
      final res = await supabase.functions.invoke(
        'google-places',
        body: {
          'action': 'details',
          'placeId': placeId,
        },
      );

      final data = res.data;
      if (res.status != 200) {
        throw Exception(_errorMessage(data, res.status, 'Place details failed'));
      }

      final root = data is Map<String, dynamic>
          ? data
          : jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

      final detailsRaw = root['result'];
      if (detailsRaw is! Map) {
        final fallback = _parsePlaceDetailsBody(root);
        if (fallback == null) {
          throw Exception('Invalid place details: missing result');
        }
        _applySelectedPlace(fallback);
        return;
      }

      final details = Map<String, dynamic>.from(detailsRaw);
      final String address =
          (details['formatted_address'] ?? '').toString().trim();

      final geometryRaw = details['geometry'];
      if (geometryRaw is! Map) {
        throw Exception('Invalid place details: missing geometry');
      }
      final geometry = Map<String, dynamic>.from(geometryRaw);

      final locationRaw = geometry['location'];
      if (locationRaw is! Map) {
        throw Exception('Invalid place details: missing location');
      }
      final location = Map<String, dynamic>.from(locationRaw);

      final latRaw = location['lat'];
      final lngRaw = location['lng'];
      if (latRaw == null || lngRaw == null || address.isEmpty) {
        throw Exception('Invalid place details: missing lat/lng or address');
      }
      final double lat = (latRaw as num).toDouble();
      final double lng = (lngRaw as num).toDouble();

      _applySelectedPlace(LocationResult(address: address, lat: lat, lng: lng));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applySelectedPlace(LocationResult selected) {
    final address = selected.address;
    final lat = selected.lat;
    final lng = selected.lng;

    _selected = selected;
    _sessionToken = _newSessionToken();

    if (!mounted) return;
    _ignoreNextControllerChange = true;
    setState(() {
      _predictions = const [];
      _loading = false;
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ignoreNextControllerChange = true;
      setState(() {
        _controller.text = address;
      });
      widget.onLocationSelected(address, lat, lng);
      widget.onChanged(selected);

      FocusScope.of(context).unfocus();
      _focusNode.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSuggestions = _predictions.isNotEmpty && _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          enabled: widget.enabled,
          focusNode: _focusNode,
          controller: _controller,
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          _selected = null;
                          widget.onChanged(null);
                          setState(() {
                            _predictions = const [];
                            _error = null;
                          });
                        },
                        icon: const Icon(Icons.close),
                      )),
          ),
        ),
        if (_error != null && _error!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: cs.error, fontSize: 12),
          ),
        ],
        if (!_loading &&
            _controller.text.trim().isNotEmpty &&
            _predictions.isEmpty &&
            _error == null &&
            _focusNode.hasFocus) ...[
          const SizedBox(height: 8),
          Text(
            'No results found.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (hasSuggestions) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _predictions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: cs.outlineVariant.withOpacity(0.4),
              ),
              itemBuilder: (context, i) {
                final item = _predictions[i];
                final main = (item['structured_formatting']?['main_text'] ?? '')
                    .toString();
                final secondary =
                    (item['structured_formatting']?['secondary_text'] ?? '')
                        .toString();
                final description = (item['description'] ?? '').toString();

                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    // Runs before focus leaves the TextField — critical on Flutter Web.
                    _selectPrediction(item);
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(main.isEmpty ? description : main),
                      subtitle: secondary.isEmpty ? null : Text(secondary),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
