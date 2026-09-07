"""Run after: swift build --package-path Example -c release --product RemoteDemoDaemon.
Exercises a real daemon without a GUI: credit pacing, unchanged replies, and
resource reuse after a viewport change. Run from the repository root.
"""
import socket,struct,time,subprocess,tempfile
probe = socket.socket()
probe.bind(('127.0.0.1', 0))
port = probe.getsockname()[1]
probe.close()
log = tempfile.TemporaryFile()
p=subprocess.Popen(['Example/.build/release/RemoteDemoDaemon','127.0.0.1',str(port)],stdout=log,stderr=subprocess.STDOUT)
def msg(t,p=b''): return struct.pack('<IHHI',0x4348524d,3,t,len(p))+p
def exact(s,n):
 b=b''
 while len(b)<n:
  c=s.recv(n-len(b))
  if not c: raise RuntimeError('closed')
  b+=c
 return b
try:
 for i in range(100):
  try: s=socket.create_connection(('127.0.0.1',port),timeout=3);break
  except OSError: time.sleep(.05)
 s.sendall(msg(7,struct.pack('<f',30))+msg(1,struct.pack('<ff',800,520)))
 times=[];sizes=[]
 for i in range(31):
  s.sendall(msg(4))
  magic,v,t,n=struct.unpack('<IHHI',exact(s,12)); exact(s,n)
  assert v==3 and t in (3,8),(v,t)
  times.append(time.monotonic());sizes.append(n+12)
 fps=30/(times[-1]-times[0]);assert fps<=30.5,fps
 s.settimeout(.15)
 try: s.recv(1);raise AssertionError('unsolicited response')
 except socket.timeout: pass
 s.settimeout(3)
 s.sendall(msg(1,struct.pack('<ff',820,520))+msg(4))
 _,_,kind,length=struct.unpack('<IHHI',exact(s,12));exact(s,length)
 assert kind==3 and length < sizes[0]-900000, (kind,length)
 s.close()
 print('31 sequential presentation credits: %.2f fps; first %d bytes; subsequent mean %.0f bytes; no unsolicited frames'%(fps,sizes[0],sum(sizes[1:])/30))
finally:
 p.terminate();p.wait(timeout=5)
