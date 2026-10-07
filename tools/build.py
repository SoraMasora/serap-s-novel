"""Собирает единый HTML: инлайнит CSS и все <script src>. → /data/serap-s.html и game.html"""
import re, sys
s=open('index.html',encoding='utf-8').read()
def css(m):
    return '<style>\n'+open(m.group(1),encoding='utf-8').read()+'\n</style>'
s=re.sub(r'<link[^>]*rel="stylesheet"[^>]*href="(css/[^"]+)"[^>]*>',css,s)
s=re.sub(r'<link[^>]*href="(css/[^"]+)"[^>]*rel="stylesheet"[^>]*>',css,s)
def js(m):
    return '<script>\n'+open(m.group(1),encoding='utf-8').read().replace('</script','<\\/script')+'\n</script>'
s=re.sub(r'<script src="((?:js|assets)/[^"]+)"></script>',js,s)
assert 'src="assets/' not in s and 'src="js/' not in s
for out in ['/data/serap-s.html','game.html']:
    open(out,'w',encoding='utf-8').write(s)
print(len(s.encode()))
