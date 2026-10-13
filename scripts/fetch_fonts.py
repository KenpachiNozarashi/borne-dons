import json, urllib.request, concurrent.futures
from pathlib import Path
families = {'Cairo':'cairo','Tajawal':'tajawal','Almarai':'almarai','NotoSansArabic':'notosansarabic','NotoNaskhArabic':'notonaskharabic','Lateef':'lateef','ScheherazadeNew':'scheherazadenew','ElMessiri':'elmessiri','Inter':'inter','Lato':'lato','Montserrat':'montserrat','OpenSans':'opensans','Nunito':'nunito','Poppins':'poppins','Raleway':'raleway','DMSans':'dmsans','Manrope':'manrope','Rubik':'rubik'}
def fetch(item):
 family, directory = item
 req=urllib.request.Request(f'https://api.github.com/repos/google/fonts/contents/ofl/{directory}',headers={'User-Agent':'donation-kiosk-fonts'})
 entries=json.load(urllib.request.urlopen(req))
 fonts=[x for x in entries if x['name'].endswith('.ttf') and 'Italic' not in x['name']]
 chosen=next((x for x in fonts if 'Regular' in x['name']), fonts[0])
 dest=Path('assets/fonts') / family
 dest.mkdir(exist_ok=True)
 (dest/'font.ttf').write_bytes(urllib.request.urlopen(chosen['download_url']).read())
 for x in entries:
  if x['name'] in ['OFL.txt','LICENSE.txt']:
   (dest/x['name']).write_bytes(urllib.request.urlopen(x['download_url']).read())
 return family
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for result in pool.map(fetch,families.items()): print(result)
p=Path('pubspec.yaml')
s=p.read_text()
for family in families:
 if f'    - family: {family}\n' not in s: s+=f'    - family: {family}\n      fonts:\n        - asset: assets/fonts/{family}/font.ttf\n'
p.write_text(s)
