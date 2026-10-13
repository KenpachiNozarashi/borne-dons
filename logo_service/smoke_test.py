import io
import json
import urllib.request
from PIL import Image, ImageDraw
base='http://127.0.0.1:3002'
assert json.load(urllib.request.urlopen(base+'/health'))['status'] == 'ready'
source=Image.new('RGB',(256,256),'white')
draw=ImageDraw.Draw(source)
draw.ellipse((64,48,192,176),fill='#C9A55C')
draw.rectangle((100,140,156,215),fill='#757479')
data=io.BytesIO()
source.save(data,format='PNG')
request=urllib.request.Request(base+'/remove-background',data=data.getvalue(),headers={'Content-Type':'application/octet-stream','Origin':'http://127.0.0.1:8080'})
with urllib.request.urlopen(request,timeout=90) as response:
 assert response.headers['Content-Type']=='image/png'
 assert response.headers['Access-Control-Allow-Origin']=='http://127.0.0.1:8080'
 result=Image.open(io.BytesIO(response.read()))
 alpha=result.getchannel('A')
 assert alpha.getextrema()[0] < 255
 assert alpha.getbbox() is not None
 print('HTTP + inference: PNG transparent, foreground present, correct local CORS.')
