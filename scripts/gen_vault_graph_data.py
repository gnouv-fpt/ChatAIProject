import os, re

vault_dir = r'c:\AK\HOCKI8\PRM393\LAB1\ChatAIProject_Khoi\flm_knowledge_vault'

files = {}
for root, dirs, fnames in os.walk(vault_dir):
    if '.obsidian' in root: continue
    for f in fnames:
        if f.endswith('.md'):
            name = os.path.splitext(f)[0]
            files[name] = os.path.join(root, f)

def norm_name(n):
    n = n.strip()
    if n.startswith('_'): return n[1:]
    return n

all_nodes = set([norm_name(k) for k in files.keys()])
for i in range(10):
    all_nodes.add(f'#HK{i}')

edges = []
seen = set()

for orig_name, path in sorted(files.items()):
    src = norm_name(orig_name)
    with open(path, 'r', encoding='utf-8') as fp:
        content = fp.read()
        
    # Wikilinks
    wikis = re.findall(r'\[\[([^\]\|]+)(?:\|[^\]]+)?\]\]', content)
    for w in wikis:
        target = norm_name(os.path.splitext(os.path.basename(w.strip()))[0])
        if target in all_nodes and target != src:
            pair = (src, target)
            if pair not in seen:
                seen.add(pair)
                edges.append((src, target, target in ['Curriculum_Overview', 'Program_Learning_Outcomes', 'BIT_SE_K19B'] or src in ['Curriculum_Overview', 'Program_Learning_Outcomes', 'BIT_SE_K19B']))

    # Tags
    fm_match = re.search(r'tags:\s*\n((?:\s*-\s*[^\n]+\n)+)', content)
    if fm_match:
        for line in fm_match.group(1).splitlines():
            t = line.strip().lstrip('- ').strip()
            if t:
                tag_id = f'#{t}' if not t.startswith('#') else t
                if tag_id in all_nodes:
                    pair = (src, tag_id)
                    if pair not in seen:
                        seen.add(pair)
                        edges.append((src, tag_id, True))
    for tag in re.findall(r'#(HK[0-9])\b', content):
        tag_id = f'#{tag}'
        if tag_id in all_nodes:
            pair = (src, tag_id)
            if pair not in seen:
                seen.add(pair)
                edges.append((src, tag_id, True))

lines = [
    '// Dữ liệu đồ thị tri thức trích xuất 100% tự động và chuẩn xác từ flm_knowledge_vault',
    '// Bao gồm toàn bộ liên kết Wikilinks [[...]], Tags #HK và 3 Hubs trung tâm',
    '',
    'class VaultEdge {',
    '  const VaultEdge(this.from, this.to, {this.isHub = false});',
    '  final String from;',
    '  final String to;',
    '  final bool isHub;',
    '}',
    '',
    'const List<VaultEdge> kVaultEdges = ['
]

for src, dst, is_hub in sorted(edges):
    hub_val = 'true' if is_hub else 'false'
    lines.append(f"  VaultEdge('{src}', '{dst}', isHub: {hub_val}),")

lines.append('];')
lines.append('')

out_path = r'c:\AK\HOCKI8\PRM393\LAB1\ChatAIProject_Khoi\flutter_app\lib\features\graph\data\vault_graph_data.dart'
os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f'Successfully generated {out_path} with {len(edges)} edges!')
