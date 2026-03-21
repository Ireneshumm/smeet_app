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

/// Location search via Supabase Edge Function `google-places` (Google key stays server-side).
class LocationSearchField extends StatefulWidget {
  final SupabaseClient supabase;
  final String labelText;
  final String hintText;
  final bool enabled;
  final ValueChanged<LocationResult?> onChanged;
  final LocationResult? initialValue;

  const LocationSearchField({
    super.key,
    required this.supabase,
    required this.onChanged,
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

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _predictions = const [];
  String _sessionToken = '';
  LocationResult? _selected;

  @override
  void initState() {
    super.initState();
    _sessionToken = _newSessionToken();
    _selected = widget.initialValue;
    if (_selected != null) {
      _controller.text = _selected!.address;
    }
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _predictions = const []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
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

  void _onTextChanged(String value) {
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

  Future<void> _selectPrediction(Map<String, dynamic> item) async {
    final placeId = (item['place_id'] ?? '').toString();
    if (placeId.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supabase = widget.supabase;
      final res = await supabase.functions.invoke(
        'google-places',
        body: {
          'action': 'details',
          'placeId': placeId,
          'sessionToken': _sessionToken,
        },
      );

      final data = res.data;
      if (res.status != 200) {
        throw Exception(_errorMessage(data, res.status, 'Place details failed'));
      }

      final body = data is Map<String, dynamic>
          ? data
          : jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

      final address = (body['address'] ?? '').toString().trim();
      final lat = (body['latitude'] as num?)?.toDouble();
      final lng = (body['longitude'] as num?)?.toDouble();

      if (lat == null || lng == null || address.isEmpty) {
        throw Exception('Invalid place details payload');
      }

      final selected = LocationResult(address: address, lat: lat, lng: lng);
      _selected = selected;
      _controller.text = selected.address;
      _sessionToken = _newSessionToken();

      if (!mounted) return;
      setState(() {
        _predictions = const [];
        _loading = false;
      });
      widget.onChanged(selected);
      _focusNode.unfocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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

                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(main.isEmpty ? description : main),
                  subtitle: secondary.isEmpty ? null : Text(secondary),
                  onTap: () => _selectPrediction(item),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
