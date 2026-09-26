#!/usr/bin/env python3
import json,time,urllib.parse,urllib.request,subprocess
from pathlib import Path

def env(path):
 d={}
 if Path(path).exists():
  for line in Path(path).read_text().splitlines():
   if '=' in line and not line.lstrip().startswith('#'):
    k,v=line.split('=',1); d[k.strip()]=v.strip().strip("'\"")
 return d
c=env('/etc/streamforge/telegram.env'); token=c.get('TELEGRAM_BOT_TOKEN'); chat=str(c.get('TELEGRAM_CHAT_ID',''))
if not token or not chat: raise SystemExit('Telegram is not configured')
api='https://api.telegram.org/bot'+token; offset=0; pending={}
def call(method,data):
 req=urllib.request.Request(api+'/'+method,urllib.parse.urlencode(data).encode())
 with urllib.request.urlopen(req,timeout=30) as r:return json.loads(r.read())
def send(text,markup=None):
 d={'chat_id':chat,'text':text}
 if markup:d['reply_markup']=json.dumps({'inline_keyboard':markup})
 call('sendMessage',d)
def action(name):return subprocess.run(['/opt/streamforge/bin/server-control.sh',name],capture_output=True,text=True,timeout=30)
while True:
 try:
  for u in call('getUpdates',{'timeout':5,'offset':offset}).get('result',[]):
   offset=u['update_id']+1; m=u.get('message') or {}; q=u.get('callback_query')
   if m:
    ch=str((m.get('chat') or {}).get('id','')); cmd=m.get('text','').strip()
    if ch!=chat:continue
    if cmd in ('/server','/help'):send('StreamForge control: /status /disk /logs /start /stop /restart')
    elif cmd[1:] in ('status','disk','logs'):send(action(cmd[1:]).stdout[-3500:])
    elif cmd[1:] in ('start','stop','restart'):
     a=cmd[1:]; pending[ch]=(a,time.time()); send('Confirm '+a.upper()+' relay?',[[{'text':'Confirm','callback_data':'confirm:'+a},{'text':'Cancel','callback_data':'cancel'}]])
   if q:
    ch=str((q.get('message') or {}).get('chat',{}).get('id',''))
    if ch!=chat:continue
    d=q.get('data',''); call('answerCallbackQuery',{'callback_query_id':q['id']})
    if d=='cancel':pending.pop(ch,None);call('editMessageText',{'chat_id':ch,'message_id':q['message']['message_id'],'text':'Cancelled.'})
    elif d.startswith('confirm:'):
     a=d.split(':',1)[1]; p=pending.get(ch)
     if not p or p[0]!=a or time.time()-p[1]>60:text='Confirmation expired. No action taken.'
     else:text=action(a).stdout.strip() or 'Completed.';pending.pop(ch,None)
     call('editMessageText',{'chat_id':ch,'message_id':q['message']['message_id'],'text':text})
 except Exception:time.sleep(2)
