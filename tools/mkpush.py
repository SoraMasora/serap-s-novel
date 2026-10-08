"""mkpush.py name "message" file1 file2 ... → push/name.json для GitHub push_files"""
import json,sys
name,msg,*files=sys.argv[1:]
d={'owner':'SoraMasora','repo':'serap-s-novel','branch':'main','message':msg,'files':[{'path':f,'content':open(f,encoding='utf-8').read()} for f in files]}
s=json.dumps(d,ensure_ascii=False); open(f'push/{name}.json','w').write(s); print(name,len(s.encode())//1024,'KB')
