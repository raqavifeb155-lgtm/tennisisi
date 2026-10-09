import json, re, sys, glob
import numpy as np
cal = sys.argv[1]  # dir
cases = {}
for f in sys.argv[2].split(","):
    for c in json.load(open(f)):
        cases[c["id"]] = c
rows = []
for f in sys.argv[3].split(","):
    for line in open(f):
        m = dict(re.findall(r"(\w+)=(\S+)", line))
        if "id" in m and m["id"] in cases:
            rows.append((cases[m["id"]], {k: int(v) for k, v in m.items() if k != "id"}))
def pack(s):
    fh, bh, sp = s["forehand"], s["backhand"], s["speed"]
    return dict(serve=s["serve"], rally=(fh+bh)/2, speed=sp, net=s["net"], stamina=s["stamina"], ret=(fh+bh+sp)/3)
def feats(s, r):
    return [1.0, s["serve"]-r["ret"], s["rally"]-r["rally"], s["speed"]-r["speed"], s["net"]-r["net"], s["stamina"]-r["stamina"]]
X=[];Y=[];W=[];lab=[]
for c, r in rows:
    # stats of b are taken as the dictionary (style bias ignored)
    a = pack(c["a"]["stats"]); b = pack(c["b"]["stats"])
    n1, k1 = r["srv_a"], r["srv_a_won"]
    n2, k2 = r["srv_b"], r["srv_b_won"]
    if n1: X.append(feats(a, b)); Y.append(k1/n1); W.append(n1); lab.append(c["id"]+":a")
    if n2: X.append(feats(b, a)); Y.append(k2/n2); W.append(n2); lab.append(c["id"]+":b")
X=np.array(X);Y=np.array(Y);W=np.array(W,float)
prior=np.array([0.60,0.030,0.020,0.012,0.008,0.004])
lam=float(sys.argv[4]) if len(sys.argv)>4 else 20.0  # ridge strength in "points"
Wd=np.diag(W)
A=X.T@Wd@X+lam*np.diag([0,1,1,1,1,1])*np.array([0,1/0.03**2*0.01,1/0.02**2*0.01,1/0.012**2*0.01,1/0.008**2*0.01,1/0.004**2*0.01])
bvec=X.T@Wd@Y+lam*np.diag([0,1,1,1,1,1])*np.array([0,1/0.03**2*0.01,1/0.02**2*0.01,1/0.012**2*0.01,1/0.008**2*0.01,1/0.004**2*0.01])@prior
beta=np.linalg.solve(A,bvec)
print("P0,C_SERVE,C_RALLY,C_SPEED,C_NET,C_STAMINA =", np.round(beta,4))
pred=X@beta
for l,y,p,w in zip(lab,Y,pred,W):
    print("%-22s live %.3f  fit %.3f  n=%d"%(l,y,p,w))
