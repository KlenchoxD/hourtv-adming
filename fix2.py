import os

base = r"C:\Users\Kleiner\proyectos\mi_app\lib"

p2 = """  Widget _tb() {
    final ch = widget.allChannels[_idx];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent])),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(ch.displayName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          if (ch.group != null) Text(ch.group!, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ])),
        IconButton(icon: Icon(_showList ? Icons.close : Icons.list, color: Colors.white), onPressed: () => setState(() => _showList = !_showList)),
        IconButton(icon: const Icon(Icons.favorite, color: AppColors.error), onPressed: () async {
          await StorageService.toggleFavorite(ch);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ch.isFavorite ? 'Aniadido a favoritos' : 'Eliminado de favoritos'), duration: const Duration(seconds: 1)));
        }),
      ]),
    );
  }
"""

with open(os.path.join(base, 'screens', 'player_screen.dart'), 'a', encoding='utf-8') as f:
    f.write('\n' + p2)
print("part2 _tb written")
