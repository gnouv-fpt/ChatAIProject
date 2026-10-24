"""Rebuild editable review diagrams and SVG previews using only Python stdlib."""
from pathlib import Path
import base64
import html
import re
import struct
import urllib.parse
import xml.etree.ElementTree as ET
import zlib

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
SOURCE = ROOT.parent / 'Diagram PRN232-C0 -_ C1.drawio.png'
COLORS = {'current': ('#eff6ff', '#2563eb'), 'proposed': ('#fff7ed', '#ea580c'),
          'store': ('#f0fdf4', '#16a34a'), 'external': ('#f1f5f9', '#64748b')}


def recover():
    b = SOURCE.read_bytes()
    i = 8
    while i < len(b):
        n = struct.unpack('>I', b[i:i+4])[0]
        kind, data = b[i+4:i+8], b[i+8:i+8+n]
        i += n + 12
        if kind == b'tEXt' and data.startswith(b'mxfile\0'):
            xml = urllib.parse.unquote(data.split(b'\0', 1)[1].decode())
            tree = ET.fromstring(xml)
            (OUT / 'Original-recovered.drawio').write_text(xml, encoding='utf-8')
            return [p.get('name') for p in tree.findall('diagram')]
    raise ValueError('No embedded mxfile found')


class Page:
    def __init__(self, name, title, subtitle, width=1800, height=1300):
        self.name, self.width, self.height = name, width, height
        self.nodes, self.edges, self.routes = {}, [], {}
        self.title, self.subtitle = title, subtitle

    def box(self, id, title, lines, x, y, w=330, h=145, kind='current'):
        self.nodes[id] = (title, lines, x, y, w, h, kind)
        return id

    def edge(self, a, b, label, dashed=False, route=None, label_at=None):
        assert a in self.nodes and b in self.nodes
        self.edges.append((a, b, label, dashed))
        if route:
            self.routes[a,b] = (route, label_at)

    def write(self, mxfile, index):
        dia = ET.SubElement(mxfile, 'diagram', id=f'review-{index}', name=self.name)
        model = ET.SubElement(dia, 'mxGraphModel', grid='1', gridSize='10', page='1',
                              pageWidth=str(self.width), pageHeight=str(self.height))
        root = ET.SubElement(model, 'root')
        ET.SubElement(root, 'mxCell', id='0')
        ET.SubElement(root, 'mxCell', id='1', parent='0')

        def cell(id, value, style, x, y, w, h):
            c = ET.SubElement(root, 'mxCell', id=id, value=value, style=style, vertex='1', parent='1')
            ET.SubElement(c, 'mxGeometry', x=str(x), y=str(y), width=str(w), height=str(h), attrib={'as': 'geometry'})

        cell('title', self.title, 'text;html=1;align=left;fontSize=28;fontStyle=1;', 40, 20, self.width-80, 45)
        cell('subtitle', self.subtitle, 'text;html=1;align=left;fontSize=14;', 40, 70, self.width-80, 55)
        svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}">',
               '<defs><marker id="arrow" markerWidth="9" markerHeight="7" refX="8" refY="3.5" orient="auto"><path d="M0,0 L9,3.5 L0,7" fill="#64748b"/></marker></defs>',
               '<rect width="100%" height="100%" fill="white"/>',
               f'<text x="40" y="51" font-family="Arial" font-size="28" font-weight="bold">{html.escape(self.title)}</text>',
               f'<text x="40" y="94" font-family="Arial" font-size="14" fill="#475569">{html.escape(self.subtitle)}</text>']
        paths, labels = [], []
        for i, (a, b, label, dashed) in enumerate(self.edges):
            aa, bb = self.nodes[a], self.nodes[b]
            ax, ay, aw, ah = aa[2:6]
            bx, by, bw, bh = bb[2:6]
            if abs((ax+aw/2)-(bx+bw/2)) > abs((ay+ah/2)-(by+bh/2)):
                sx, sy = (ax+aw if bx>ax else ax), ay+ah/2
                tx, ty = (bx if bx>ax else bx+bw), by+bh/2
                mid = (sx+tx)/2
                points = f'{sx},{sy} {mid},{sy} {mid},{ty} {tx},{ty}'
                lx, ly = mid, (sy+ty)/2-8
            else:
                sx, sy = ax+aw/2, (ay+ah if by>ay else ay)
                tx, ty = bx+bw/2, (by if by>ay else by+bh)
                mid = (sy+ty)/2
                points = f'{sx},{sy} {sx},{mid} {tx},{mid} {tx},{ty}'
                lx, ly = (sx+tx)/2, mid-8
            route = None
            if (a,b) in self.routes:
                route, label_at = self.routes[a,b]
                sx,sy=route[0];tx,ty=route[-1]
                points=' '.join(f'{x},{y}' for x,y in route)
                lx,ly=label_at
            style='edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=block;fontSize=12;labelBackgroundColor=#ffffff;'
            style+=f'exitX={(sx-ax)/aw};exitY={(sy-ay)/ah};entryX={(tx-bx)/bw};entryY={(ty-by)/bh};'
            c = ET.SubElement(root, 'mxCell', id=f'e{i}', value=label, source=a, target=b, edge='1', parent='1',
                              style=style + ('dashed=1;' if dashed else ''))
            geo=ET.SubElement(c, 'mxGeometry', relative='1', attrib={'as':'geometry'})
            if route:
                arr=ET.SubElement(geo,'Array',attrib={'as':'points'})
                for x,y in route[1:-1]:ET.SubElement(arr,'mxPoint',x=str(x),y=str(y))
            paths.append(f'<polyline points="{points}" fill="none" stroke="#64748b" stroke-width="1.5" marker-end="url(#arrow)"'+(' stroke-dasharray="6 4"' if dashed else '')+'/>')
            labels.append(f'<text x="{lx}" y="{ly}" text-anchor="middle" font-family="Arial" font-size="12" fill="#334155" stroke="white" stroke-width="4" paint-order="stroke">{html.escape(label)}</text>')
        svg += paths
        for id, (title, lines, x, y, w, h, kind) in self.nodes.items():
            fill, stroke = COLORS[kind]
            text = f'<b>{html.escape(title)}</b><br><br>' + '<br>'.join(html.escape(s) for s in lines)
            cell(id, text, f'rounded=1;whiteSpace=wrap;html=1;align=left;verticalAlign=top;spacing=14;fillColor={fill};strokeColor={stroke};fontSize=14;', x, y, w, h)
            svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
            for j, line in enumerate([title, '']+lines):
                svg.append(f'<text x="{x+14}" y="{y+25+j*21}" font-family="Arial" font-size="14"'+(' font-weight="bold"' if j==0 else '')+f'>{html.escape(line)}</text>')
        svg += labels + ['</svg>']
        (OUT/f'{index:02d}-{self.name.split(" - ")[0]}.svg').write_text('\n'.join(svg), encoding='utf-8')


def architecture():
    p = Page('C2 - Containers', 'C2 | Vietnam Traffic Law Advanced RAG', 'TARGET DESIGN for teacher review | Blue: existing code; orange: proposed; green: stores; gray: external | C4 C2 = Container', 1850, 1310)
    p.box('client', 'Citizen / Admin client', ['Browser / mobile / Postman', 'Login, chat, documents, reports'], 50, 150, kind='external')
    p.box('api', 'REST API | ASP.NET Core 8', ['Controllers -> BusinessLogic -> DataAccess', 'JWT, CRUD, chat orchestration', 'SQL message + outbox transaction [NEW]'], 520, 150, 390, 160)
    p.box('grpc', 'Inference | Python gRPC', ['Moderation -> retrieval -> RAG', 'VerifyLegalDocument RPC', 'Return answer + citations / no-match'], 1090, 150, 350, 160)
    p.box('ai', 'LLM / Embedding provider', ['External HTTPS calls', 'API keys from environment'], 1500, 150, 300, 140, 'external')
    p.box('sql', 'SQL Server | ChatAIWebDb', ['7 business tables', 'EF Core migrations; UTC timestamps', 'Authoritative business / audit records'], 520, 440, 390, 160, 'store')
    p.box('qdrant', 'Qdrant | Vector database', ['Vectors + document/chunk metadata', 'Verified + active + date/version filter', 'VectorId is a logical link; not a SQL FK'], 1090, 440, 350, 160, 'store')
    p.box('relay', 'Outbox relay | .NET Worker [NEW]', ['Reads committed OutboxMessages', 'Kafka delivery ack -> PublishedAt', 'Retry without losing original EventId'], 50, 440, 330, 160, 'proposed')
    p.box('kafka', 'Apache Kafka [NEW]', ['chat-completed-events', 'document-updated-events', 'Failed events -> per-topic DLQ'], 50, 760, 330, 160, 'proposed')
    p.box('worker', 'Worker Service | .NET 8 [NEW]', ['Consumer: quota + violation + email', 'Crawler + verification + indexing', 'Document updates -> SQL outbox -> relay', '00:00 Asia/Ho_Chi_Minh scheduled jobs'], 520, 760, 390, 165, 'proposed')
    p.box('source', 'thuvienphapluat.vn / SMTP', ['HTTPS: crawl legal documents', 'SMTP: violation / report email'], 1090, 760, 350, 160, 'external')
    p.box('obs', 'Observability stack [NEW]', ['Prometheus: service / Kafka metrics', 'Loki: JSON file logs; Tempo: traces', 'Grafana: dashboards + alerts'], 520, 1080, 650, 155, 'proposed')
    for a,b,l in [('client','api','HTTPS / JWT'),('api','grpc','gRPC / HTTP2'),('grpc','ai','HTTPS'),('api','sql','EF Core / TDS'),('grpc','qdrant','Vector search'),('relay','sql','Read / mark sent'),('relay','kafka','Produce + ack'),('kafka','worker','Consume'),('worker','sql','Dedupe + update'),('worker','source','HTTPS / SMTP'),('worker','obs','Logs / metrics / traces')]: p.edge(a,b,l)
    p.edge('worker','grpc','gRPC verify / index [NEW]',route=[(910,810),(1000,810),(1000,365),(1220,365),(1220,310)],label_at=(1000,700))
    return p


def schema_pages():
    migration = (ROOT/'DataAccess/Migrations/20260924070016_InitialCreate.cs').read_text(encoding='utf-8-sig')
    tables = {}
    for name, body in re.findall(r'name: "(\w+)",\s+columns: table => new\s*\{(.*?)\n\s*\},', migration, re.S):
        tables[name] = [(n,t,nullable=='true') for n,t,nullable in re.findall(r'(\w+) = table.Column<[^>]+>\(type: "([^"]+)"[^\n]*?nullable: (true|false)',body)]
    scope = {'Users','RefreshTokens','LegalDocuments','DocumentChunks','ChatSessions','ChatMessages','Citations'}
    tables = {name: cols for name, cols in tables.items() if name in scope}
    assert len(tables)==7, tables.keys()
    positions = {'Users':(50,150), 'ChatSessions':(640,150), 'ChatMessages':(1230,150),
                 'RefreshTokens':(50,620), 'LegalDocuments':(640,620), 'Citations':(1230,620),
                 'DocumentChunks':(640,1120)}
    fks = {'RefreshTokens':['UserId'], 'ChatSessions':['UserId'], 'ChatMessages':['SessionId'],
           'DocumentChunks':['DocumentId'], 'Citations':['ChatMessageId','DocumentChunkId']}
    relationships = [('Users','ChatSessions','UserId: 1 -> 0..*'),('Users','RefreshTokens','UserId: 1 -> 0..*'),('ChatSessions','ChatMessages','SessionId: 1 -> 0..*'),('ChatMessages','Citations','ChatMessageId: 1 -> 0..*'),('LegalDocuments','DocumentChunks','DocumentId: 1 -> 0..*'),('DocumentChunks','Citations','Chunk: 0..1 <- 0..*'),]
    pages = []
    for physical in [False,True]:
        p = Page('Database - Physical current' if physical else 'ERD - Logical current',
                 'SQL Server | Physical database diagram' if physical else 'ERD | Current business entities',
                 'CURRENT SCOPE: 7 business tables | Historical reporting tables removed by a new migration | ? = nullable', 1800, 1600)
        for name, columns in tables.items():
            lines=[]
            for col,typ,nullable in columns:
                if not physical and col not in ['Id']+fks.get(name,[]) and col not in ['Username','Email','Title','Content','VectorId','VerificationStatus','ReportDate','TotalTokensUsed']:
                    continue
                unique = {'Users':['Username','Email'],'RefreshTokens':['TokenHash'],'LegalDocuments':['DocumentNumber']}
                flag = 'PK' if col=='Id' else ('FK' if col in fks.get(name,[]) else ('UK' if col in unique.get(name,[]) else '  '))
                lines.append(f'{flag}  {col}'+ (' : '+typ if physical else '')+(' ?' if nullable else ''))
            p.box(name,name,lines,*positions[name],510, max(145,65+21*len(lines)), 'store')
        for a,b,l in relationships:
            if (a,b)==('DocumentChunks','Citations'):
                p.edge(a,b,'0..1 chunk / 0..* citations',route=[(1150,1240),(1190,1240),(1190,740),(1230,740)],label_at=(1190,1040))
            else:p.edge(a,b,'1 -> 0..*')
        pages.append(p)
    return pages


def observability():
    p=Page('Monitoring - Target', 'Kafka + Grafana | Logs, metrics and request tracing', 'TARGET DESIGN ONLY | Each service must emit telemetry; Grafana displays data queried from configured data sources.',1800,1300)
    p.box('apps','Service telemetry [NEW]',['REST / gRPC / Worker / Relay instrumentation','HTTP / gRPC metadata, duration, status','Kafka EventId / topic / partition / offset'],50,160,450,165,'proposed')
    p.box('files','Persistent log files [NEW]',['logs/{service}/app-YYYYMMDD.jsonl','UTC timestamp + service + TraceId + EventId','Rotate daily; bounded retention'],680,160,450,165,'proposed')
    p.box('alloy','Grafana Alloy [NEW]',['Tail mounted JSON files -> Loki','Receive OpenTelemetry traces -> Tempo','File offsets persisted across restart'],1310,160,440,165,'proposed')
    p.box('metrics','Service / Kafka exporters [NEW]',['/metrics: HTTP + gRPC + event counters','Broker JMX: requests / errors / bytes','Kafka exporter: offsets + consumer lag'],50,510,450,165,'proposed')
    p.box('prom','Prometheus [NEW]',['Scrape configured targets / exporters','Counters, rates, p95 latency, errors, up','Labels: service / route / topic / group'],680,510,450,165,'proposed')
    p.box('loki','Loki + Tempo [NEW]',['Loki: search individual log records','Tempo: request -> gRPC -> Kafka -> Worker','Trace context carried in Kafka headers'],1310,510,440,165,'proposed')
    p.box('grafana','Grafana dashboard + alerts [NEW]',['Produced / processed / retry / DLQ counts','Lag, service up, consumer heartbeat','HTTP/gRPC request rate, p95 and error rate','Request/response metadata + log drilldown','TraceId links REST, gRPC and worker spans'],680,900,670,210,'proposed')
    p.box('ops','Admin / teacher demo',['Send N requests -> find N distinct EventIds','Stop worker -> lag rises; restart -> drains','Retry one EventId -> quota deducted once','Find one request across logs + trace'],50,900,450,210,'external')
    for a,b,l in [('apps','files','Write real files'),('files','alloy','Read mounted volume'),('apps','metrics','Instrumented counters'),('metrics','prom','Scrape'),('alloy','loki','Logs + OTLP traces'),('prom','grafana','PromQL'),('loki','grafana','LogQL / TraceQL'),('ops','grafana','View / demo')]:p.edge(a,b,l)
    return p


def main():
    names=recover()
    pages=[architecture(),*schema_pages(),observability()]
    mx=ET.Element('mxfile',host='app.diagrams.net',pages=str(len(pages)))
    for i,p in enumerate(pages,1):p.write(mx,i)
    ET.indent(mx)
    target=OUT/'PRN232-C2-ERD-Database-Monitoring.drawio'
    ET.ElementTree(mx).write(target,encoding='utf-8',xml_declaration=True)
    for d in mx.findall('diagram'):
        cells=d.findall('.//mxCell');ids={c.get('id') for c in cells}
        assert len(ids)==len(cells)
        for c in cells:
            for attr in ('source','target'):
                if c.get(attr):assert c.get(attr) in ids
    print('Recovered original pages:', ', '.join(names))
    print('Created:',target)
    print('Validated: 4 pages; 7 business tables from migration; unique cell IDs; all edge endpoints exist.')


if __name__=='__main__':main()
