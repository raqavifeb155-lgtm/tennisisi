import json, re, sys
import numpy as np
cases = {}
for f in sys.argv[1].split(","):
    for c in json.load(open(f)):
        cases[c["id"]] = c
rows = []
for f in sys.argv[2].split(","):
    for line in open(f):
        m = dict(re.findall(r"(\w+)=(\S+)", line))
        if "id" in m and m["id"] in cases:
            rows.append((cases[m["id"]], {k: int(v) for k, v in m.items() if k != "id"}))
def tf(v, g):
    return 1 + 9 * (((v - 1) / 9.0) ** g)
def pack(s, g):
    s = {k: tf(v, g) for k, v in s.items()}
    fh, bh, sp = s["forehand"], s["backhand"], s["speed"]
    return dict(serve=s["serve"], rally=(fh+bh)/2, speed=sp, net=s["net"], stamina=s["stamina"], ret=(fh+bh+sp)/3)
def feats(s, r):
    return [1.0, s["serve"]-r["ret"], s["rally"]-r["rally"], s["speed"]-r["speed"], s["net"]-r["net"], s["stamina"]-r["stamina"], 0.0]
def build(g):
    X=[];Y=[];W=[];lab=[];grp=[]
    for ci,(c, r) in enumerate(rows):
        a = pack(c["a"]["stats"], g); b = pack(c["b"]["stats"], g)
        fa=feats(a,b); fa[6]=1.0
        fb=feats(b,a); fb[6]=-1.0
        for (n,k,f) in ((r["srv_a"],r["srv_a_won"],fa),(r["srv_b"],r["srv_b_won"],fb)):
            X.append(f);Y.append(k/n);W.append(n);lab.append(c["id"]);grp.append(ci)
    return np.array(X),np.array(Y),np.array(W,float),lab,grp
def fit(g, lam=5.0, fixed_zero=(4,5)):
    nf=7
    X,Y,W,lab,grp = build(g)
    keep=[i for i in range(7) if i not in fixed_zero]
    Xk=X[:,keep]
    A=Xk.T@np.diag(W)@Xk+lam*np.diag([0]+[1]*(len(keep)-2)+[0])
    beta=np.linalg.solve(A,Xk.T@np.diag(W)@Y)
    full=np.zeros(7); full[keep]=beta
    pred=X@full
    # share error per case
    errs=[]
    for ci,(c,r) in enumerate(rows):
        idx=[i for i,gp in enumerate(grp) if gp==ci]
        na,nb=r["srv_a"],r["srv_b"]
        live=(r["a_pts"])/(r["a_pts"]+r["b_pts"])
        sh=(na*pred[idx[0]]+nb*(1-pred[idx[1]]))/(na+nb)
        errs.append((c["id"],live,sh))
    rms=np.sqrt(np.mean([(l-s)**2 for _,l,s in errs]))
    return full,rms,errs
for g in [1.0,0.9,0.8,0.7,0.6,0.5]:
    full,rms,errs=fit(g)
    print("gamma %.1f rms %.3f"%(g,rms), np.round(full,4))
g=float(sys.argv[3]) if len(sys.argv)>3 else 0.7
full,rms,errs=fit(g)
for i,l,s in errs: print("%-14s live %.3f sim %.3f d=%+.3f"%(i,l,s,s-l))
