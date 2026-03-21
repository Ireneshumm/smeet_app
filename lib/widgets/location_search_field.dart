import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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

/// Location search via Supabase Edge Function `google-places`.
/// Suggestions render in an [Overlay] + [CompositedTransformFollower] so Web taps are not swallowed.
class LocationSearchField extends StatefulWidget {
  final SupabaseClient supabase;
  final String labelText;
  final String hintText;
  final bool enabled;
  final ValueChanged<LocationResult?> onChanged;
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
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();

  Timer? _debounce;
  Timer? _blurHideTimer;

  OverlayEntry? _overlayEntry;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _predictions = const [];
  String _sessionToken = '';
  LocationResult? _selected;

  bool _ignoreNextControllerChange = false;

  @override
  void initState() {
    super.initState();
    _sessionToken = _newSessionToken();
    _selected = widget.initialValue;
    if (_selected != null) {
      _controller.text = _selected!.address;
    }
    _controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    _blurHideTimer?.cancel();
    _blurHideTimer = null;

    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOrUpdateOverlay();
      });
      return;
    }

    _blurHideTimer = Timer(const Duration(milliseconds: 220), () {
      _blurHideTimer = null;
      if (!mounted || _focusNode.hasFocus) return;
      setState(() => _predictions = const []);
      _hideOverlay();
    });
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOrUpdateOverlay() {
    if (!mounted) return;
    if (_predictions.isEmpty || !_focusNode.hasFocus) {
      _hideOverlay();
      return;
    }

    final ctx = _targetKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOrUpdateOverlay();
      });
      return;
    }

    final width = box.size.width;
    final predictions = List<Map<String, dynamic>>.from(_predictions);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    _hideOverlay();

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          followerAnchor: Alignment.topLeft,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(0, 6),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            color: theme.colorScheme.surface,
            child: SizedBox(
              width: width,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: predictions.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: cs.outlineVariant.withOpacity(0.35),
                  ),
                  itemBuilder: (_, i) {
                    final prediction = predictions[i];
                    final main =
                        (prediction['structured_formatting']?['main_text'] ??
                                '')
                            .toString();
                    final secondary =
                        (prediction['structured_formatting']?['secondary_text'] ??
                                '')
                            .toString();
                    final description =
                        (prediction['description'] ?? '').toString();

                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (PointerDownEvent event) {
                        if (!mounted) return;
                        // Raw pointer: bypass gesture arena / blur race on Web.
                        _focusNode.unfocus();
                        _ignoreNextControllerChange = true;
                        _controller.text =
                            (prediction['description'] ?? '').toString();
                        _selectPrediction(prediction);
                      },
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.place_outlined,
                          color: cs.primary,
                        ),
                        title: Text(main.isEmpty ? description : main),
                        subtitle: secondary.isEmpty
                            ? null
                            : Text(secondary),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _blurHideTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    _hideOverlay();
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

  LocationResult? _parseDetailsRoot(Map<String, dynamic> root) {
    final addrNorm = root['address']?.toString().trim();
    final latNorm = root['latitude'];
    final lngNorm = root['longitude'];
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

    final resultRaw = root['result'];
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

  /// Drives search from [TextEditingController] so programmatic updates can be ignored.
  void _onControllerChanged() {
    // Skips search when we inject description (pointer down) or full address (after details).
    if (_ignoreNextControllerChange) {
      _ignoreNextControllerChange = false;
      return;
    }

    if (!mounted) return;

    _debounce?.cancel();
    _selected = null;
    widget.onChanged(null);

    final value = _controller.text;
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _predictions = const [];
        _error = null;
        _loading = false;
      });
      _hideOverlay();
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
      final res = await widget.supabase.functions.invoke(
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
        if (!mounted) return;
        setState(() {
          _predictions =
              raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showOrUpdateOverlay();
        });
        return;
      }

      if (status == 'ZERO_RESULTS') {
        if (!mounted) return;
        setState(() {
          _predictions = const [];
          _loading = false;
        });
        _hideOverlay();
        return;
      }

      throw Exception(
        'Autocomplete status=$status ${body['error_message'] ?? ''}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _predictions = const [];
        _loading = false;
      });
      _hideOverlay();
    }
  }

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    _blurHideTimer?.cancel();
    _blurHideTimer = null;
    _hideOverlay();

    final placeId = (prediction['place_id'] ?? '').toString().trim();
    if (placeId.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _predictions = const [];
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.supabase.functions.invoke(
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

      final selected = _parseDetailsRoot(root);
      if (selected == null) {
        throw Exception('Invalid place details payload');
      }

      final address = selected.address;
      final lat = selected.lat;
      final lng = selected.lng;

      _selected = selected;
      _sessionToken = _newSessionToken();

      if (!mounted) return;

      // Must be true before assigning text so [_onControllerChanged] skips search / clearing selection.
      _ignoreNextControllerChange = true;
      setState(() {
        _controller.text = address;
        _loading = false;
      });

      widget.onLocationSelected(address, lat, lng);
      widget.onChanged(selected);

      _hideOverlay();

      _focusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      _hideOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFocus = _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: SizedBox(
            key: _targetKey,
            width: double.infinity,
            child: TextField(
              enabled: widget.enabled,
              focusNode: _focusNode,
              controller: _controller,
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
                              _hideOverlay();
                            },
                            icon: const Icon(Icons.close),
                          )),
              ),
            ),
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
            hasFocus) ...[
          const SizedBox(height: 8),
          Text(
            'No results found.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
