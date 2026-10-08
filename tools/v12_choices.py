"""v12: визуальная реакция на выборы — вставки команд в ветки (идемпотентно: метка // v12c)."""
import re
def scene_span(s, name):
    m = re.search(r'^\s*' + re.escape(name) + r': \[\n', s, re.M)
    assert m, name
    end = s.index('\n],', m.end()) if s.find('\n],', m.end()) != -1 else None
    # конец сцены — первая строка, начинающаяся с '],' или '  ],'
    e = re.compile(r'^\s*\],', re.M).search(s, m.end())
    return m.end(), e.start()
def items(s, a, b):
    """строки-элементы сцены (верхнего уровня), каждая строка = 1 элемент или несколько через ', '"""
    return s[a:b]
def edit(s, name, start=None, before_go=None, at=None):
    a, b = scene_span(s, name)
    body = s[a:b]
    if '// v12c' in body: return s
    ind = re.match(r'(\s*)', body).group(1) or '  '
    lines = body.split('\n')
    if at:  # {index_of_line_containing_text: commands}
        for key, cmd in at.items():
            for i, l in enumerate(lines):
                if key in l:
                    lines.insert(i, ind + cmd + ' // v12c'); break
            else: raise Exception(name + ' no ' + key)
    if before_go:
        for i in range(len(lines) - 1, -1, -1):
            if re.search(r"\{go:'[^']+'\}", lines[i]) and 'when' not in lines[i]:
                lines.insert(i, ind + before_go + ' // v12c'); break
        else: raise Exception(name + ' no go')
    if start: lines.insert(0, ind + start + ' // v12c')
    body = '\n'.join(lines)
    return s[:a] + body + s[b:]
E1 = [
 ('c1_store_sorry', dict(start="{cam:{x:50,y:40,s:1.22,ms:1400}},")),
 ('c1_store_quiet', dict(start="{hide:'all'}, {bg:'cg_store_help'},", before_go="{bg:'store'}, {show:'neutral'},")),
 ('c1_store_rude',  dict(start="{fx:'shake'}, {show:'angry', pos:'center'}, {cam:{x:50,y:34,s:1.4,ms:500}},", before_go="{cam:null},")),
 ('c1_room_mid',    dict(start="{show:'smirk', pos:'right'},")),
 ('c1_room_bad',    dict(at={'Я вышел.': "{hide:'all'}, {sfx:'door'}, {bg:'stairs'}, {fx:'shake'},"})),
 ('c1_shift_honest',dict(at={'Она отвернулась': "{show:'soft', pos:'right'},"}, before_go="{show:'neutral', pos:'center'},")),
 ('c1_shift_joke',  dict(start="{react:'giggle'},")),
 ('c1_shift_dodge', dict(start="{show:'neutral', pos:'left'}, {cam:{x:35,y:50,s:1.12,ms:1200}},", before_go="{cam:null}, {show:'neutral', pos:'center'},")),
 ('c1_shift_sorry', dict(start="{cam:{x:50,y:40,s:1.3,ms:900}},", before_go="{cam:null},")),
 ('c1_roof1_good',  dict(start="{hide:'all'}, {bg:'cg_roof_quiet'},")),
 ('c1_study_bad',   dict(start="{show:'cold', pos:'right'}, {sfx:'paper'},", before_go="{hide:'all'},")),
 ('c1_guests_stand',dict(start="{hide:'all'}, {bg:'cg_guests'},", at={"'…', 'surprised'": "{bg:'stairs'}, {show:'surprised'},"} )),
 ('eve1_e1',        dict(start="{react:'huff'},")),
 ('eve1_e2',        dict(start="{hide:'all'}, {bg:'cg_tea'},", before_go="{bg:'kitchen'},")),
 ('eve2_study_a',   dict(at={'Я завтра пойду': "{react:'cover'},"})),
 ('eve2_study_b',   dict(start="{fx:'shake'}, {show:'angry', pos:'right'},")),
 ('eve2_song_ask',  dict(at={'Она смотрела на огни': "{hide:'all'}, {bg:'cg_sing'},"}, before_go="{bg:'roof'},")),
 ('eve3_expo_a',    dict(at={'Я хочу, чтобы кто-то': "{cam:{x:50,y:38,s:1.25,ms:1600}},", 'Можно я подпишу': "{react:'shy'},"}, before_go="{cam:null},")),
 ('eve3_expo_b',    dict(at={'Она отвернула холст': "{hide:'all'}, {bg:'cg_canvas'},"}, before_go="{bg:'room'},")),
 ('ch3_therapy',    dict(at={'Психологи…': "{show:'cold', pos:'right'},"})),
 ('ch3_tea',        dict(start="{hide:'all'}, {bg:'cg_tea'},")),
]
E3 = [
 ('c3_m_stand',     dict(start="{show:'stern', who:'matvey', pos:'center'}, {cam:{x:50,y:32,s:1.3,ms:900}},", before_go="{cam:null},")),
 ('c3_m_take',      dict(start="{hide:'all'}, {bg:'cg_take'}, {sfx:'paper'},", before_go="{bg:'court'},")),
 ('c3_m_promise',   dict(start="{show:'neutral', who:'matvey', pos:'left'},", at={'Хороший человек.': "{hide:'matvey'}, {sfx:'steps'},"})),
 ('c3_eve_play',    dict(start="{hide:'all'}, {bg:'cg_dumplings'},", before_go="{bg:'heroroom'},")),
 ('c3_eve_soft',    dict(start="{cam:{x:50,y:42,s:1.2,ms:1400}},", at={'Очень громкую': "{react:'giggle'},"}, before_go="{cam:null},")),
 ('c3_eve_quiet',   dict(start="{show:'suspicious', pos:'center'}, {cam:{x:50,y:36,s:1.38,ms:700}},", before_go="{cam:null},")),
 ('c3_eve_lie',     dict(at={'Через десять минут': "{hide:'all'}, {sfx:'door'},"})),
]
for f, E in (('js/story.js', E1), ('js/story3.js', E3)):
    s = open(f).read()
    for n, kw in E: s = edit(s, n, **kw)
    open(f, 'w').write(s); print(f, s.count('// v12c'))
