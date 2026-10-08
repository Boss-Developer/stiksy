"""Prepare imagegen artwork, package native-rendered stickers, and verify uploads.
Requires Pillow. Run --prepare-art, Flutter render tool, then --package.
"""
import argparse, csv, hashlib, html, json, zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'content/sticker-catalog-source'
DEST = ROOT/'content/sticker-catalog/v1'
PREVIEWS = ROOT/'output/sticker-catalog-preview'
LIMIT = 100*1024

def read(path): return json.loads(path.read_text())
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def prepare():
    records = read(SOURCE/'generated-art.json')
    prepared=SOURCE/'prepared';prepared.mkdir(exist_ok=True)
    for item in records:
        image_path=Path(item['path'])
        if not image_path.is_absolute(): image_path=ROOT/image_path
        image=Image.open(image_path).convert('RGBA')
        alpha=image.getchannel('A')
        if alpha.getextrema()[0] == 255:
            raise ValueError(f"Artwork {item['number']} has no transparent alpha")
        bounds=alpha.getbbox()
        if not bounds: raise ValueError('Empty artwork')
        image=image.crop(bounds)
        image.thumbnail((468,468),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,512),(0,0,0,0))
        canvas.alpha_composite(image,((512-image.width)//2,(512-image.height)//2))
        target=prepared/f"{item['number']:02}.png"
        canvas.save(target,optimize=True)
        item['preparedPath']=str(target.relative_to(ROOT))
    write(SOURCE/'generated-art.json',records)
    print(f'Prepared {len(records)} transparent source illustrations')

def webp(image,path,quality=68):
    for q in [quality,60,52,44,36]:
        image.save(path,'WEBP',quality=q,method=6,alpha_quality=100,exact=True)
        if path.stat().st_size < LIMIT: return q
    raise ValueError(f'Cannot compress {path} below 100 KiB')

def font(size):
    return ImageFont.truetype(str(ROOT/'assets/fonts/Poppins-Bold.ttf'),size)

def previews(plan):
    PREVIEWS.mkdir(parents=True,exist_ok=True)
    for pack in plan:
        folder=DEST/pack['folder']
        if not folder.exists(): continue
        sheet=Image.new('RGB',(1080,500),'#f6f5f0');d=ImageDraw.Draw(sheet)
        d.text((20,12),f"{pack['number']:02}. {pack['title']}",font=font(22),fill='#123f31')
        for i in range(10):
            im=Image.open(folder/f'{i+1:02}.webp').convert('RGBA');im.thumbnail((192,192))
            x=12+(i%5)*214;y=50+(i//5)*218
            sheet.paste(im,(x,y),im)
            d.text((x+4,y+192),f'{i+1:02}',font=font(12),fill='#738078')
        sheet.save(PREVIEWS/f"{pack['folder']}.jpg",quality=86,optimize=True)
    overview=Image.new('RGB',(1200,1120),'#f6f5f0');d=ImageDraw.Draw(overview)
    d.text((22,14),'STIKSY / PAKISTANI CULTURE / 40 PACKS · 400 STICKERS',font=font(23),fill='#123f31')
    for i,pack in enumerate(plan):
        path=DEST/pack['folder']/'cover.webp'
        if not path.exists(): continue
        im=Image.open(path).convert('RGBA');im.thumbnail((134,134))
        x=8+(i%8)*149;y=62+(i//8)*206
        overview.paste(im,(x+6,y),im)
        d.text((x+8,y+138),f"{pack['number']:02}",font=font(12),fill='#087653')
        title=pack['title']
        words=title.split();lines=['']
        for word in words:
            line=(lines[-1]+' '+word).strip()
            if d.textlength(line,font=font(11))>135 and lines[-1]: lines.append(word)
            else: lines[-1]=line
        d.multiline_text((x+8,y+157),'\n'.join(lines),font=font(11),fill='#243d33',spacing=3)
    overview.save(PREVIEWS/'overview.jpg',quality=90,optimize=True)
    cards=[]
    for pack in plan:
        entries=[]
        for i,caption in enumerate(pack['captions']):
            path=f"../../content/sticker-catalog/v1/{pack['folder']}/{i+1:02}.webp"
            entries.append(f'<figure><img loading="lazy" src="{path}" alt="{html.escape(caption)}"><figcaption>{i+1:02}. {html.escape(caption)}</figcaption></figure>')
        cards.append(f'<section id="p{pack["number"]}"><h2>{pack["number"]:02}. {html.escape(pack["title"])}</h2><p>{html.escape(pack["category"])} · 10 stickers</p><div class="stickers">{"".join(entries)}</div></section>')
    document='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Stiksy · Pakistani culture sticker catalog</title><style>*{box-sizing:border-box}body{margin:0;background:#f6f5f0;color:#173b2e;font:15px system-ui,sans-serif}header{background:#123f31;color:white;padding:36px max(24px,calc((100vw - 1200px)/2))}h1{font-size:38px;letter-spacing:-1px;margin:8px 0}main{max-width:1248px;margin:auto;padding:24px}section{background:white;border-radius:24px;padding:24px;margin-bottom:24px}h2{margin:0;font-size:23px}p{color:#7b897f}.stickers{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:16px}figure{margin:0;background:#f7f7f3;border-radius:18px;padding:10px}img{width:100%;aspect-ratio:1;object-fit:contain}figcaption{font-size:12px;line-height:1.4;color:#42574b;padding:8px}a{color:inherit}@media(max-width:700px){.stickers{grid-template-columns:repeat(2,minmax(0,1fr))}h1{font-size:29px}main,section{padding:16px}}</style><header><small>STIKSY / PREDEFINED STICKERS</small><h1>Pakistani culture, in 400 expressions.</h1><div>40 packs · 10 stickers each · Transparent WebP · 512 × 512</div></header><main>'''+''.join(cards)+'</main></html>'
    (PREVIEWS/'index.html').write_text(document)
    print(f'Saved overview, {len(plan)} pack contact sheets, and browser review catalog')

def encode_rendered(plan):
    cache_path=SOURCE/'render-cache.json'
    cache=read(cache_path) if cache_path.exists() else {}
    jobs=[]
    for pack in plan:
        source=ROOT/'build/sticker-catalog-renders'/pack['folder']
        if not source.exists(): continue
        target=DEST/pack['folder'];target.mkdir(parents=True,exist_ok=True)
        for i in range(10): jobs.append((source/f'{i+1:02}.png',target/f'{i+1:02}.webp'))
    def job(paths):
        source,target=paths;key=str(target.relative_to(ROOT));source_hash=digest(source)
        prior=cache.get(key)
        if prior and prior['source']==source_hash and target.exists() and digest(target)==prior['target']:
            return key,prior
        image=Image.open(source).convert('RGBA');quality=webp(image,target)
        return key,{'source':source_hash,'target':digest(target),'quality':quality}
    updated={}
    with ThreadPoolExecutor(max_workers=6) as pool:
        tasks=[pool.submit(job,paths) for paths in jobs]
        for n,task in enumerate(as_completed(tasks),1):
            key,value=task.result();updated[key]=value
            if n%50==0: print(f'Compressed / reused {n}/{len(jobs)} sticker files',flush=True)
    write(cache_path,updated)
    return updated

def package(partial=False):
    plan=read(SOURCE/'plan.json');inventory=[];packs=[]
    cache=encode_rendered(plan)
    for pack in plan:
        render=ROOT/'build/sticker-catalog-renders'/pack['folder']
        if not render.exists():
            if partial: continue
            raise ValueError(f'Missing rendered pack {pack["folder"]}')
        folder=DEST/pack['folder'];folder.mkdir(parents=True,exist_ok=True)
        stickers=[]
        for i,caption in enumerate(pack['captions']):
            path=folder/f'{i+1:02}.webp'
            quality=cache[str(path.relative_to(ROOT))]['quality']
            item={'id':f"{pack['id']}-{i+1:02}",'file':path.name,'caption':caption,
                  'accessibilityText':f"{pack['title']}: {caption}",'emojis':[pack['emoji']],
                  'width':512,'height':512,'bytes':path.stat().st_size,'sha256':digest(path),'quality':quality,
                  'renderSha256':cache[str(path.relative_to(ROOT))]['source']}
            stickers.append(item)
            inventory.append(dict(item,packId=pack['id'],packTitle=pack['title'],path=str(path.relative_to(DEST))))
        cover=Image.open(folder/'01.webp').convert('RGBA');cover.thumbnail((256,256),Image.Resampling.LANCZOS)
        webp(cover,folder/'cover.webp',quality=60)
        tray=Image.open(folder/'01.webp').convert('RGBA');tray.thumbnail((96,96),Image.Resampling.LANCZOS)
        tray.save(folder/'tray.png',optimize=True)
        metadata={'schemaVersion':1,'id':pack['id'],'identifier':pack['id'],'title':pack['title'],
            'name':pack['title'],'publisher':'Stiksy','category':pack['category'],'locale':'ur-Latn-PK',
            'tags':['pakistani','desi',pack['category'].lower().replace(' & ','-').replace(' ','-')],
            'version':'1','animated':False,'premium':False,'tray':'tray.png','cover':'cover.webp','stickerCount':10,
            'stickers':stickers}
        write(folder/'pack.json',metadata)
        packs.append({'id':pack['id'],'title':pack['title'],'category':pack['category'],'locale':'ur-Latn-PK',
            'version':'1','stickerCount':10,'manifest':f"{pack['folder']}/pack.json",'manifestSha256':digest(folder/'pack.json'),
            'cover':f"{pack['folder']}/cover.webp",'tray':f"{pack['folder']}/tray.png",
            'downloadBytes':sum(p.stat().st_size for p in folder.iterdir() if p.is_file())})
    catalog={'schemaVersion':1,'id':'stiksy-pakistani-culture','version':'1','publisher':'Stiksy',
        'locale':'ur-Latn-PK','assetBasePath':'./','packCount':len(packs),'stickerCount':len(inventory),
        'categories':list(dict.fromkeys(p['category'] for p in packs)),
        'format':{'mime':'image/webp','width':512,'height':512,'transparent':True,'animated':False},'packs':packs}
    write(DEST/'catalog.json',catalog);write(DEST/'inventory.json',inventory)
    with (DEST/'inventory.csv').open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=['id','packId','packTitle','caption','path','bytes','sha256']);writer.writeheader()
        writer.writerows({k:item[k] for k in writer.fieldnames} for item in inventory)
    previews([p for p in plan if any(q['id']==p['id'] for q in packs)])
    if not partial: verify()
    print(f'Packaged {len(packs)} packs / {len(inventory)} stickers')

def verify():
    catalog=read(DEST/'catalog.json');assert catalog['packCount']==40;assert catalog['stickerCount']==400
    hashes=set();ids=set();total=0;largest=0
    for pack in catalog['packs']:
        meta=read(DEST/pack['manifest']);assert len(meta['stickers'])==10
        assert digest(DEST/pack['manifest'])==pack['manifestSha256']
        tray=Image.open(DEST/pack['tray']);assert tray.size==(96,96)
        assert (DEST/pack['tray']).stat().st_size<50*1024
        assert len({item['caption'] for item in meta['stickers']})==10
        for item in meta['stickers']:
            path=(DEST/pack['manifest']).parent/item['file'];assert path.is_relative_to(DEST)
            image=Image.open(path);assert image.format=='WEBP';assert image.size==(512,512)
            assert image.mode=='RGBA';alpha=image.getchannel('A');assert alpha.getextrema()==(0,255)
            assert alpha.getpixel((0,0))==0 and alpha.getpixel((511,511))==0
            size=path.stat().st_size;assert 0<size<LIMIT;assert size==item['bytes']
            assert digest(path)==item['sha256'];assert item['sha256'] not in hashes;hashes.add(item['sha256'])
            assert item['id'] not in ids;ids.add(item['id']);total+=size;largest=max(largest,size)
    files=list(DEST.rglob('*.webp'));assert len(files)==440
    report={'packs':40,'stickers':400,'uniqueStickerFiles':len(hashes),'stickerBytes':total,'largestStickerBytes':largest,
        'serverFolderBytes':sum(p.stat().st_size for p in DEST.rglob('*') if p.is_file()),
        'checks':['512x512 WebP','transparent alpha','all stickers below 100 KiB','96x96 tray PNG below 50 KiB',
            '40 packs x 10 stickers','unique IDs and file hashes','relative paths and manifest checksums','10 distinct captions per pack']}
    write(SOURCE/'validation.json',report)
    print(json.dumps(report,indent=2))

def archive():
    target=ROOT/'output/stiksy-pakistani-culture-v1.zip'
    if not (SOURCE/'validation.json').exists(): verify()
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for path in sorted(DEST.rglob('*')):
            if path.is_file():z.write(path,Path('v1')/path.relative_to(DEST))
    with zipfile.ZipFile(target) as check:
        assert check.testzip() is None, 'ZIP integrity check failed'
    print(f'Upload ZIP: {target} ({target.stat().st_size:,} bytes)')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--prepare-art',action='store_true');parser.add_argument('--package',action='store_true');parser.add_argument('--partial',action='store_true');parser.add_argument('--verify',action='store_true');parser.add_argument('--zip',action='store_true');args=parser.parse_args()
    if args.prepare_art:prepare()
    if args.package:package(args.partial)
    if args.verify:verify()
    if args.zip:archive()
