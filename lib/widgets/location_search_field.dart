import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Matches `SmeetTheme.smeetMint` in `main.dart` (avoid importing `main.dart`).
const Color kSmeetMint = Color(0xFF56CDBE);

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

/// Google Places autocomplete row; [==] / [hashCode] use [placeId] for [RawAutocomplete].
@immutable
class PlacePrediction {
  const PlacePrediction(this.raw);

  final Map<String, dynamic> raw;

  String get placeId => (raw['place_id'] ?? '').toString().trim();

  String get description => (raw['description'] ?? '').toString();

  Map<String, dynamic>? get structuredFormatting =>
      raw['structured_formatting'] as Map<String, dynamic>?;

  @override
  bool operator ==(Object other) =>
      other is PlacePrediction && other.placeId == placeId;

  @override
  int get hashCode => placeId.hashCode;
}

/// Location search via Supabase Edge Function `google-places`.
/// Uses [RawAutocomplete] so the framework owns overlay / hit-testing (reliable on Web).
class LocationSearchField extends StatefulWidget {
  final SupabaseClient supabase;
  final String labelText;
  final String hintText;
  final bool enabled;
  final ValueChanged<LocationResult?> onChanged;
  final void Function(String address, double lat, double lng)? onLocationSelected;
  final LocationResult? initialValue;

  const LocationSearchField({
    super.key,
    required this.supabase,
    required this.onChanged,
    this.labelText = 'Location',
    this.hintText = 'Search address',
    this.enabled = true,
    this.initialValue,
    this.onLocationSelected,
  });

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int _fetchGeneration = 0;

  bool _loading = false;
  String? _error;
  String _sessionToken = '';
  LocationResult? _selected;

  /// True while resolving place details after user picks an option (skips duplicate searches).
  bool _resolvingPick = false;

  /// Confirmed address string last applied to [_controller] for a successful pick (or parent sync).
  /// Used to ignore spurious controller notifications that would otherwise clear [_selected].
  String? _lastConfirmedAddress;

  /// When we call [onChanged](null) because the user edited text after a pick, the parent
  /// sets [initialValue] to null; we must not treat that as "reset form" and clear the field.
  bool _suppressNextInitialNullSync = false;

  /// Web / platform may emit multiple [TextEditingController] notifications per assignment.
  bool _ignoreNextControllerChange = false;
  int _extraControllerChangeSkips = 0;

  static bool _sameLocation(LocationResult? a, LocationResult? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.address == b.address && a.lat == b.lat && a.lng == b.lng;
  }

  void _armControllerChangeIgnore({int extraSkips = 2}) {
    _ignoreNextControllerChange = true;
    _extraControllerChangeSkips = extraSkips;
  }

  bool _consumeControllerChangeIgnore() {
    if (_ignoreNextControllerChange) {
      _ignoreNextControllerChange = false;
      return true;
    }
    if (_extraControllerChangeSkips > 0) {
      _extraControllerChangeSkips--;
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _sessionToken = _newSessionToken();
    _selected = widget.initialValue;
    final initialAddr = widget.initialValue?.address.trim();
    _lastConfirmedAddress =
        (initialAddr != null && initialAddr.isNotEmpty) ? initialAddr : null;
    _controller.text = widget.initialValue?.address ?? '';
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(LocationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameLocation(oldWidget.initialValue, widget.initialValue)) {
      _selected = widget.initialValue;
      if (widget.initialValue != null) {
        final addr = widget.initialValue!.address.trim();
        _lastConfirmedAddress = addr.isEmpty ? null : addr;
        _armControllerChangeIgnore(extraSkips: 6);
        _controller.text = widget.initialValue!.address;
      } else if (_suppressNextInitialNullSync) {
        _suppressNextInitialNullSync = false;
      } else {
        _lastConfirmedAddress = null;
        _armControllerChangeIgnore(extraSkips: 6);
        _controller.clear();
      }
    } else if (widget.initialValue != null && !_focusNode.hasFocus) {
      // Parent still holds a confirmed location but the field drifted (e.g. transient query text).
      final want = widget.initialValue!.address.trim();
      if (want.isNotEmpty && _controller.text.trim() != want) {
        _selected = widget.initialValue;
        _lastConfirmedAddress = want;
        _armControllerChangeIgnore(extraSkips: 6);
        _controller.text = widget.initialValue!.address;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
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

  void _applyResolvedPlace(LocationResult item) {
    _fetchGeneration++;
    _selected = item;
    final trimmed = item.address.trim();
    _lastConfirmedAddress = trimmed.isEmpty ? null : trimmed;
    _sessionToken = _newSessionToken();

    // Apply resolved address before clearing [_resolvingPick] so [optionsBuilder] does not run
    // with stale query text while we still consider this pick in progress.
    _armControllerChangeIgnore(extraSkips: 8);
    _controller.text = item.address;

    _resolvingPick = false;

    if (mounted) {
      setState(() {
        _loading = false;
        _error = null;
      });
    }

    debugPrint(
      'LocationSearchField: selection resolved → ${item.address} (${item.lat},${item.lng})',
    );
    widget.onLocationSelected?.call(item.address, item.lat, item.lng);
    widget.onChanged(item);

    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onControllerChanged() {
    if (_consumeControllerChangeIgnore()) {
      return;
    }
    if (_resolvingPick) {
      return;
    }
    if (!mounted) return;

    if (_selected != null) {
      final current = _controller.text.trim();
      final confirmed = _lastConfirmedAddress ?? _selected!.address.trim();
      // Spurious notifications often fire after we set the resolved address; do not drop selection.
      if (current == confirmed) {
        return;
      }
      _selected = null;
      _lastConfirmedAddress = null;
      _suppressNextInitialNullSync = true;
      widget.onChanged(null);
    }
  }

  Future<Iterable<PlacePrediction>> _optionsBuilder(TextEditingValue value) async {
    if (!widget.enabled || _resolvingPick) {
      return const [];
    }

    final q = value.text.trim();
    if (q.isEmpty) {
      if (mounted) setState(() => _error = null);
      return const [];
    }

    final gen = ++_fetchGeneration;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || gen != _fetchGeneration) {
      return const [];
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await widget.supabase.functions.invoke(
        'google-places',
        body: {
          'action': 'autocomplete',
          'input': q,
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

      if (!mounted || gen != _fetchGeneration) {
        return const [];
      }

      if (status == 'OK') {
        final raw = (body['predictions'] as List?) ?? const [];
        final list = raw
            .map((e) => PlacePrediction(Map<String, dynamic>.from(e as Map)))
            .toList();
        debugPrint('LocationSearchField: autocomplete OK, ${list.length} options for "$q"');
        if (mounted) setState(() => _loading = false);
        return list;
      }

      if (status == 'ZERO_RESULTS') {
        debugPrint('LocationSearchField: autocomplete ZERO_RESULTS for "$q"');
        if (mounted) setState(() => _loading = false);
        return const [];
      }

      throw Exception(
        'Autocomplete status=$status ${body['error_message'] ?? ''}',
      );
    } catch (e, st) {
      debugPrint('LocationSearchField: autocomplete error: $e\n$st');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
      return const [];
    }
  }

  Future<void> _onPredictionSelected(PlacePrediction prediction) async {
    debugPrint(
      'LocationSearchField: option tapped placeId=${prediction.placeId} desc=${prediction.description}',
    );

    if (prediction.placeId.isEmpty) {
      debugPrint('LocationSearchField: abort — empty placeId');
      return;
    }

    _resolvingPick = true;
    _armControllerChangeIgnore(extraSkips: 5);

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await widget.supabase.functions.invoke(
        'google-places',
        body: {
          'action': 'details',
          'placeId': prediction.placeId,
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

      if (!mounted) return;
      debugPrint('LocationSearchField: details OK → notifying parent');
      _applyResolvedPlace(selected);
    } catch (e, st) {
      debugPrint('LocationSearchField: details error: $e\n$st');
      _resolvingPick = false;
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFocus = _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RawAutocomplete<PlacePrediction>(
          focusNode: _focusNode,
          textEditingController: _controller,
          displayStringForOption: (PlacePrediction p) => p.description,
          optionsBuilder: _optionsBuilder,
          onSelected: _onPredictionSelected,
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              enabled: widget.enabled,
              focusNode: focusNode,
              controller: controller,
              onSubmitted: (_) => onFieldSubmitted(),
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: kSmeetMint, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: kSmeetMint,
                ),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kSmeetMint,
                          ),
                        ),
                      )
                    : (controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _fetchGeneration++;
                              _lastConfirmedAddress = null;
                              _controller.clear();
                              _selected = null;
                              widget.onChanged(null);
                              setState(() => _error = null);
                            },
                            icon: const Icon(Icons.close),
                          )),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final opts = options.toList();
            if (opts.isEmpty) {
              return const SizedBox.shrink();
            }

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                clipBehavior: Clip.antiAlias,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: kSmeetMint, width: 1),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < opts.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: kSmeetMint.withValues(alpha: 0.25),
                            ),
                          _SuggestionRow(
                            prediction: opts[i],
                            onPick: (PlacePrediction p) {
                              debugPrint(
                                'LocationSearchField: row pointer/tap → onSelected(${p.placeId})',
                              );
                              _resolvingPick = true;
                              _armControllerChangeIgnore(extraSkips: 5);
                              // RawAutocomplete sets field text to [displayStringForOption] then calls
                              // [onSelected] → [_onPredictionSelected] (details + parent notify).
                              onSelected(p);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
            _error == null &&
            hasFocus) ...[
          const SizedBox(height: 8),
          Text(
            'Type to search, then pick an address from the list.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Row hit target: [Listener.onPointerDown] fires on Web before blur; no [InkWell.onTap]
/// (would double-fire with the same pointer gesture).
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.prediction,
    required this.onPick,
  });

  final PlacePrediction prediction;
  final void Function(PlacePrediction) onPick;

  @override
  Widget build(BuildContext context) {
    final sf = prediction.structuredFormatting;
    final main = (sf?['main_text'] ?? '').toString();
    final secondary = (sf?['secondary_text'] ?? '').toString();
    final description = prediction.description;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPick(prediction),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: kSmeetMint.withValues(alpha: 0.06),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined, color: kSmeetMint),
            title: Text(main.isEmpty ? description : main),
            subtitle: secondary.isEmpty ? null : Text(secondary),
          ),
        ),
      ),
    );
  }
}
