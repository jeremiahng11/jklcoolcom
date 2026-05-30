import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A terminal-style log viewer with search/filter, autoscroll and copy.
class LogConsole extends StatefulWidget {
  const LogConsole({
    super.key,
    required this.text,
    this.live = false,
    this.onToggleLive,
  });

  final String text;
  final bool live;
  final VoidCallback? onToggleLive;

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  bool _autoscroll = true;
  String _filter = '';

  @override
  void didUpdateWidget(covariant LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoscroll && widget.text != oldWidget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    }
  }

  void _toBottom() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = widget.text.split('\n');
    final shown = _filter.isEmpty
        ? lines
        : lines
              .where((l) => l.toLowerCase().contains(_filter.toLowerCase()))
              .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Filter logs',
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              if (widget.onToggleLive != null)
                IconButton(
                  tooltip: widget.live ? 'Pause' : 'Resume',
                  onPressed: widget.onToggleLive,
                  icon: Icon(
                    widget.live
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                ),
              IconButton(
                tooltip: _autoscroll ? 'Autoscroll on' : 'Autoscroll off',
                onPressed: () => setState(() => _autoscroll = !_autoscroll),
                icon: Icon(
                  _autoscroll
                      ? Icons.vertical_align_bottom
                      : Icons.vertical_align_center,
                ),
                color: _autoscroll ? scheme.primary : null,
              ),
              IconButton(
                tooltip: 'Copy all',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.text));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Logs copied')));
                },
                icon: const Icon(Icons.copy_all_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: widget.text.trim().isEmpty
                ? const Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : Scrollbar(
                    controller: _scroll,
                    child: ListView.builder(
                      controller: _scroll,
                      itemCount: shown.length,
                      itemBuilder: (_, i) => SelectableText(
                        shown[i],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFFD1D5DB),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
