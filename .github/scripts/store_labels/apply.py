import base64,hashlib,json,pathlib,zlib
from PIL import Image
root=pathlib.Path.cwd();support=root/'.github/scripts/store_labels'
encoded=''.join(p.read_text().strip() for p in sorted(support.glob('part*.b64')))
patches=json.loads(zlib.decompress(base64.b64decode(encoded)))
records=json.loads((support/'records.json').read_text());by_path={r['path']:r for r in records}
manifest=json.loads((root/'source_assets/SHA256.json').read_text())
for item in patches:
 path=root/item['path'];before=path.read_bytes()
 assert hashlib.sha256(before).hexdigest()==item['before_sha256'],item['path']
 im=Image.open(path).convert('RGB');assert list(im.size)==item['size']
 for region in item['regions']:
  x0,y0,x1,y1=region['box'];data=zlib.decompress(base64.b64decode(region['rgb']))
  patch=Image.frombytes('RGB',(x1-x0,y1-y0),data);im.paste(patch,(x0,y0))
 assert hashlib.sha256(im.tobytes()).hexdigest()==item['after_rgb_sha256'],item['path']
 im.save(path,format='WEBP',lossless=True,quality=100,method=6)
 assert hashlib.sha256(Image.open(path).convert('RGB').tobytes()).hexdigest()==item['after_rgb_sha256']
 sha=hashlib.sha256(path.read_bytes()).hexdigest();manifest[item['path']]=sha;by_path[item['path']]['after_sha256']=sha
 print('Restored product labels:',item['path'])
report={'reference':'Intact product labels from the corresponding original store.webp background','scope':'Product label regions only; no scenario, character or composition changes','format':'WebP lossless','images':records}
report_path=root/'source_assets/manifests/store_labels_fixed.json';report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
manifest[report_path.relative_to(root).as_posix()]=hashlib.sha256(report_path.read_bytes()).hexdigest()
(root/'source_assets/SHA256.json').write_text(json.dumps(dict(sorted(manifest.items())),ensure_ascii=False,indent=2)+'\n')
print('Verified exact RGB restoration of',len(patches),'images')
