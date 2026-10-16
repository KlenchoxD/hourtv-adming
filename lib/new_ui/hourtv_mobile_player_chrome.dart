import 'package:flutter/material.dart';

const _ink = Color(0xFFF6F4EF);
const _muted = Color(0xFFB8BFBD);
const _accent = Color(0xFF00C781);
const _label = TextStyle(
  fontFamily: 'Roboto',
  color: _ink,
  fontSize: 13,
  fontWeight: FontWeight.w500,
);

/// Presentation only. Owns no controller, resolver, timer or playback state.
class HourTvMobilePlayerHeader extends StatelessWidget {
  const HourTvMobilePlayerHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.serverLabel,
    required this.onBack,
    required this.onCast,
    this.onServer,
    this.castConnected = false,
    this.sourceReady = false,
  });
  final String title;
  final String? subtitle;
  final String serverLabel;
  final VoidCallback onBack, onCast;
  final VoidCallback? onServer;
  final bool castConnected, sourceReady;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 10, 16, 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final server = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: _ServerPill(
            label: serverLabel,
            onTap: onServer,
            ready: sourceReady,
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                PlayerChromeIconButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Volver',
                  onPressed: onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _label.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _label.copyWith(fontSize: 12, color: _muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PlayerChromeIconButton(
                  icon: castConnected
                      ? Icons.cast_connected_rounded
                      : Icons.cast_rounded,
                  label: 'Transmitir',
                  onPressed: onCast,
                  selected: castConnected,
                ),
                if (!compact) ...[const SizedBox(width: 10), server],
              ],
            ),
            if (compact)
              Padding(padding: const EdgeInsets.only(top: 6), child: server),
          ],
        );
      },
    ),
  );
}

class _ServerPill extends StatelessWidget {
  const _ServerPill({required this.label, this.onTap, required this.ready});
  final String label;
  final VoidCallback? onTap;
  final bool ready;
  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: const Color(0x77101412),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x33FFFFFF)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ready ? _accent : _muted,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 7),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _label,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _ink,
                  size: 19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return onTap == null
        ? Semantics(label: 'Servidor actual: $label', child: content)
        : Tooltip(message: 'Cambiar servidor', child: content);
  }
}

class HourTvMobilePlayerToolbar extends StatelessWidget {
  const HourTvMobilePlayerToolbar({
    super.key,
    required this.qualityLabel,
    required this.speedLabel,
    required this.landscape,
    required this.onAudio,
    required this.onQuality,
    required this.onSpeed,
    required this.onPip,
    required this.onSettings,
    required this.onFullscreen,
  });
  final String qualityLabel, speedLabel;
  final bool landscape;
  final VoidCallback onAudio,
      onQuality,
      onSpeed,
      onPip,
      onSettings,
      onFullscreen;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actions = <Widget>[
        _TextAction(
          label: 'Audio y subtítulos',
          icon: Icons.subtitles_outlined,
          tooltip: 'Audio y subtítulos',
          onTap: onAudio,
        ),
        _TextAction(
          label: qualityLabel,
          tooltip: 'Calidad',
          onTap: onQuality,
          chevron: true,
        ),
        _TextAction(
          label: speedLabel,
          tooltip: 'Velocidad',
          onTap: onSpeed,
          chevron: true,
        ),
      ];
      final tools = <Widget>[
        PlayerChromeIconButton(
          icon: Icons.picture_in_picture_alt_rounded,
          label: 'Picture-in-Picture',
          onPressed: onPip,
        ),
        PlayerChromeIconButton(
          icon: Icons.settings_outlined,
          label: 'Ajustes',
          onPressed: onSettings,
        ),
        PlayerChromeIconButton(
          icon: landscape
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          label: landscape ? 'Vertical' : 'Horizontal',
          onPressed: onFullscreen,
        ),
      ];
      if (constraints.maxWidth >= 620 &&
          MediaQuery.textScalerOf(context).scale(13) <= 20) {
        return Row(children: [...actions, const Spacer(), ...tools]);
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 2,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: tools),
        ],
      );
    },
  );
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.icon,
    this.chevron = false,
  });
  final String label, tooltip;
  final VoidCallback onTap;
  final IconData? icon;
  final bool chevron;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: _ink,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: _label,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _label,
            ),
          ),
          if (chevron) ...[
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          ],
        ],
      ),
    ),
  );
}

class PlayerChromeIconButton extends StatelessWidget {
  const PlayerChromeIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.all(10),
      foregroundColor: selected ? _accent : _ink,
    ),
    icon: Icon(icon, size: 23),
  );
}

/// Shared timing keeps the scrim, header and transport visually in sync.
const playerChromeFadeIn = Duration(milliseconds: 240);
const playerChromeFadeOut = Duration(milliseconds: 320);

/// Only animates the control layer; never the native video surface. Retaining
/// one opacity controller makes quick repeated taps reverse the current fade
/// instead of creating overlapping incoming/outgoing copies of the controls.
class PlayerChromeVisibility extends StatefulWidget {
  const PlayerChromeVisibility({
    super.key,
    required this.visible,
    required this.child,
  });
  final bool visible;
  final Widget child;
  @override
  State<PlayerChromeVisibility> createState() => _PlayerChromeVisibilityState();
}

class _PlayerChromeVisibilityState extends State<PlayerChromeVisibility> {
  late bool _retained = widget.visible;

  @override
  void didUpdateWidget(covariant PlayerChromeVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) _retained = true;
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.visible,
    child: ExcludeSemantics(
      excluding: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : widget.visible
            ? playerChromeFadeIn
            : playerChromeFadeOut,
        curve: Curves.easeInOutCubic,
        onEnd: () {
          if (!widget.visible && _retained) setState(() => _retained = false);
        },
        child: _retained
            ? RepaintBoundary(child: widget.child)
            : const SizedBox.shrink(),
      ),
    ),
  );
}

/// Full viewport, deliberately outside SafeArea: cutouts constrain buttons,
/// not the lighting of the video. It uses exactly the controls' fade lifecycle.
class HourTvPlayerScrim extends StatelessWidget {
  const HourTvPlayerScrim({super.key, required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: PlayerChromeVisibility(
      visible: visible,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xB3000000),
              Color(0x18000000),
              Color(0x18000000),
              Color(0xCC000000),
            ],
            stops: [0, .25, .65, 1],
          ),
        ),
        child: SizedBox.expand(),
      ),
    ),
  );
}
