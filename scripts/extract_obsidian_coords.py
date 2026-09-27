import json
import math
import random

with open('graph_preview.html', 'r', encoding='utf-8') as f:
    text = f.read()

idx_nodes = text.find('"nodes": [')
idx_edges = text.find('"edges": [')
idx_spec = text.find('"specialization":')

nodes_str = text[idx_nodes + 8:idx_edges].strip()
while nodes_str.endswith(','): nodes_str = nodes_str[:-1].strip()
nodes_raw = json.loads(nodes_str)

# Reference positions matching Obsidian Image 2
# Spread nicely in a 360-degree circle around the 3 central hubs
pos = {
    # 3 Central Hubs
    'Curriculum_Overview': (-0.02, -0.06),
    'Program_Learning_Outcomes': (0.10, 0.12),
    'BIT_SE_K19B': (-0.12, 0.08),

    # Sector 1: Top (SWE & JPD)
    'SWE202c': (-0.42, -0.76),
    'SWE102': (-0.20, -0.74),
    'JPD133': (0.16, -0.75),
    'SWD392': (-0.10, -0.56),
    'CSD201': (-0.08, -0.32),
    'JPD113': (-0.16, -0.42),
    'JPD123': (0.02, -0.40),

    # Sector 2: Upper Left (SWP & Requirements & Testing)
    'SWE201c': (-0.52, -0.58),
    'SWR302': (-0.36, -0.46),
    'SWT301': (-0.48, -0.38),
    'SWP391': (-0.66, -0.32),
    '#HK3': (-0.78, -0.38),
    '#HK4': (-0.40, -0.30),
    '#HK5': (-0.88, -0.22),

    # Sector 3: Far Left & Mid Left (Java / Core programming / .NET)
    'DBI202': (-0.56, -0.16),
    'LAB211': (-0.70, -0.08),
    'PRJ301': (-0.78, 0.08),
    'WED201c': (-0.38, -0.16),
    'PRO192': (-0.28, -0.04),
    'PRN222': (-0.42, 0.02),
    'PRN212': (-0.68, 0.22),
    'WDU203c': (-0.54, 0.14),
    'IOT102': (-0.38, 0.18),

    # Sector 4: Bottom Left (Philosophy & Politics & Advanced .NET)
    'VOV134': (-0.50, 0.35),
    'PRN232': (-0.38, 0.46),
    'VNR202': (-0.60, 0.52),
    'HCM202': (-0.44, 0.60),
    'MLN122': (-0.36, 0.72),
    'MLN111': (-0.20, 0.78),

    # Sector 5: Bottom Center (Mobile & Foundations)
    '#HK9': (-0.24, 0.24),
    'PRF192': (-0.20, 0.36),
    'PRM393': (-0.08, 0.30),
    'VOV124': (-0.14, 0.56),
    'MLN131': (-0.02, 0.62),
    '#HK8': (0.00, 0.86),

    # Sector 6: Bottom Right (Systems & Networks)
    'OSG202': (0.06, 0.34),
    'NWC204': (0.14, 0.44),
    'CSI106': (0.16, 0.58),
    'VOV114': (0.28, 0.65),
    '#HK2': (0.34, 0.76),
    '#HK1': (0.68, 0.74),

    # Sector 7: Right (Math & Soft skills & General)
    'MAD101': (0.36, 0.18),
    'SSG104': (0.22, 0.22),
    'TMI101': (0.30, 0.32),
    'ITE302c': (0.22, 0.40),
    'SSL101c': (0.32, 0.48),
    'EXE201': (0.44, 0.44),
    'MAE101': (0.58, 0.36),
    'CEA201': (0.48, 0.26),

    # Sector 8: Far Right (Preparatory & Business)
    'TRS601': (0.32, 0.02),
    'OTP101': (0.28, -0.16),
    'EXE101': (0.42, -0.12),
    'MAS291': (0.48, 0.08),
    'MAC101': (0.76, 0.10),
    '#HK0': (0.65, -0.18),

    # Sector 9: Upper Right (Capstone & Specialization)
    'PRU213': (0.12, -0.26),
    'ENW493c': (0.26, -0.26),
    'PMG201c': (0.44, -0.24),
    'SEP490': (0.12, -0.46),
    'OJT202': (0.38, -0.36),
    '#HK7': (0.22, -0.58),
    '#HK6': (0.64, -0.54),
}

# Collision relaxation loop (50 iterations)
nodes = list(pos.keys())
for step in range(60):
    for i in range(len(nodes)):
        n1 = nodes[i]
        p1 = list(pos[n1])
        for j in range(i + 1, len(nodes)):
            n2 = nodes[j]
            p2 = list(pos[n2])
            dx = p1[0] - p2[0]
            dy = p1[1] - p2[1]
            dist = math.sqrt(dx*dx + dy*dy) + 0.0001
            min_dist = 0.14
            if dist < min_dist:
                overlap = (min_dist - dist) / 2.0
                p1[0] += (dx / dist) * overlap
                p1[1] += (dy / dist) * overlap
                p2[0] -= (dx / dist) * overlap
                p2[1] -= (dy / dist) * overlap
                pos[n1] = (p1[0], p1[1])
                pos[n2] = (p2[0], p2[1])

# Scale to fit nicely within [-0.9, 0.9]
max_c = max(max(abs(x), abs(y)) for x, y in pos.values())
scale_factor = 0.88 / max_c

out = "final Map<String, Offset> obsidianNodeCoords = {\n"
for nid in sorted(pos.keys()):
    x = round(pos[nid][0] * scale_factor, 4)
    y = round(pos[nid][1] * scale_factor, 4)
    out += f'  "{nid}": const Offset({x}, {y}),\n'
out += "};\n"

with open('scripts/obsidian_coords.dart', 'w', encoding='utf-8') as f:
    f.write(out)

print("Generated clean, non-overlapping coordinates in scripts/obsidian_coords.dart!")
