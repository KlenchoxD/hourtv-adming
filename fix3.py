import os

base = r"C:\Users\Kleiner\proyectos\mi_app\lib"

ov = """  Widget _ov() => Positioned.fill(child: GestureDetector(
    onTap: () => setState(() => _showList = false),
    child: Container(color: Colors.black87, child: Center(child: Container(
      width: double.infinity, height: MediaQuery.of(context).size.height * 0.7, margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          const Text('Todos los canales', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(widget.allChannels.length.toString(), style: const TextStyle(color: AppColors.textMuted)),
        ])),
        Expanded(child: ListView.builder(itemCount: widget.allChannels.length, itemBuilder: (ctx, i) {
          final ch = widget.allChannels[i];
          final cur = i == _idx;
          return ListTile(
            onTap: () { setState(() { _idx = i; _showList = false; }); _init(ch); StorageService.saveRecent(ch); },
            leading: ch.logo != null ? CachedNetworkImage(imageUrl: ch.logo!, width: 40, height: 40, fit: BoxFit.contain, errorWidget: (a, b, c) => _in(ch)) : _in(ch),
            title: Text(ch.displayName, style: TextStyle(color: cur ? AppColors.accent : AppColors.textPrimary, fontSize: 14, fontWeight: cur ? FontWeight.w600 : FontWeight.w400)),
            subtitle: ch.group != null ? Text(ch.group!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)) : null,
            trailing: cur ? const Icon(Icons.play_arrow, color: AppColors.accent, size: 20) : null,
          );
        })),
      ]),
    ))),
  ));

  @override void dispose() { _cc?.dispose(); _vc?.dispose(); super.dispose(); }
}
"""

with open(os.path.join(base, 'screens', 'player_screen.dart'), 'a', encoding='utf-8') as f:
    f.write('\n' + ov)
print("part3 _ov + dispose written")
