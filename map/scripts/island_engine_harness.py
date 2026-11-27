# Offline island-engine harness: synthetic noisy-ellipse pangaea (44x52), runs GeneratePangaeaIslands
# for many seeds and reports per island type the water gap to the mainland (min hex dist - 1).
# Needs: pip install lupa. Usage: python scripts/island_engine_harness.py [seeds] [islandTypeToDraw]
# Synthetic map has 8% mountains / 20% hills; prints a gap table and ASCII samples of the given type.
import sys, os
import lupa.lua51 as l

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root (this file lives in scripts/)
N = int(sys.argv[1]) if len(sys.argv) > 1 else 60
SHOW = sys.argv[2] if len(sys.argv) > 2 else ''

L = l.LuaRuntime()
loaded = set()
def include(name):
    name = str(name)
    if name in loaded:
        return
    loaded.add(name)
    path = os.path.join(ROOT, name + ".lua")
    L.execute(open(path, encoding="utf-8").read())
L.globals().include = include

L.execute(r'''
PlotTypes={PLOT_OCEAN=0,PLOT_LAND=1,PLOT_HILLS=2,PLOT_MOUNTAIN=3}
local iW,iH=44,52
local function tocube(x,y) local q=x-(y-(y%2))/2 return q,y,-q-y end
Map={
  Rand=function(n) if n<=0 then return 0 end return math.random(n)-1 end,
  GetGridSize=function() return iW,iH end,
  IsWrapX=function() return true end,
  PlotDistance=function(x1,y1,x2,y2)
    local best=999
    for _,off in ipairs({-iW,0,iW}) do
      local a1,b1,c1=tocube(x1,y1) local a2,b2,c2=tocube(x2+off,y2)
      local d=math.max(math.abs(a1-a2),math.abs(b1-b2),math.abs(c1-c2))
      if d<best then best=d end
    end
    return best
  end,
}
function LekMapgenChannelEnabled(c) return c=="islandmap" end
''')
include("3_PangaeaIslands")
L.execute("_G=nil")

res = L.execute(r'''
local N,SHOW=...
local shown=0
local samples={}
local iW,iH=44,52
local stats={}   -- type -> {n=, gaps={[g]=count}}
local fails=0
for seed=1,N do
  math.randomseed(seed*7919)
  local pt={}
  local ph1,ph2,ph3=math.random()*6.28,math.random()*6.28,math.random()*6.28
  for y=0,iH-1 do for x=0,iW-1 do
    local dx=(x-22)/15; local dy=(y-26)/19
    local ang=math.atan2(dy,dx)
    local r=1+0.12*math.sin(3*ang+ph1)+0.08*math.sin(5*ang+ph2)+0.05*math.sin(9*ang+ph3)
    local v=(dx*dx+dy*dy < r*r) and 1 or 0
    if v==1 then local rr=math.random(100) if rr<=8 then v=3 elseif rr<=28 then v=2 end end
    pt[y*iW+x+1]=v
  end end
  local pre={} for i=1,#pt do pre[i]=pt[i] end
  local self={plotTypes=pt,iNumPlotsX=iW,iNumPlotsY=iH}
  local ok,err=pcall(GeneratePangaeaIslands,self,{})
  if not ok then fails=fails+1 print("ERR "..tostring(err)) else
    -- mainland distance map (BFS from pre land)
    local dist={} local q={} for i=1,#pre do if pre[i]~=0 then dist[i-1]=0 q[#q+1]=i-1 end end
    local h=1
    while h<=#q do local k=q[h] h=h+1
      for d=1,6 do local nx,ny=GetHexNeighbor(k%iW,math.floor(k/iW),d,iW,iH,true,false)
        if ny>=0 and ny<iH then local nk=ny*iW+nx if dist[nk]==nil then dist[nk]=dist[k]+1 q[#q+1]=nk end end end
    end
    local tr=_lek_island_track
    if tr then for _,pl in ipairs(tr.placements) do
      local md=99
      for _,k in ipairs(pl.tiles) do if pre[k+1]==0 and dist[k] and dist[k]<md then md=dist[k] end end
      if #pl.tiles>0 then
        local s=stats[pl.type] or {n=0,g={}} stats[pl.type]=s
        s.n=s.n+1 local g=md-1 s.g[g]=(s.g[g] or 0)+1
        if pl.type==SHOW and shown<4 then shown=shown+1
          local own={} local minx,maxx,miny,maxy=99,-1,99,-1
          for _,k in ipairs(pl.tiles) do own[k]=true local x,y=k%iW,math.floor(k/iW)
            if x<minx then minx=x end if x>maxx then maxx=x end if y<miny then miny=y end if y>maxy then maxy=y end end
          if maxx-minx<20 then
          local rows={"tiles="..#pl.tiles.." gap="..g}
          for y=maxy+3,miny-3,-1 do local row=(y%2==1) and " " or ""
            for x=minx-4,maxx+4 do local k=y*iW+x local c="~"
              if x>=0 and x<iW and y>=0 and y<iH then
                if own[k] then c=(pt[k+1]==3) and "A" or ((pt[k+1]==2) and "h" or "f")
                elseif pre[k+1]~=0 then c=(pre[k+1]==3) and "M" or "L" end end
              row=row..c.." " end
            rows[#rows+1]=row end
          samples[#samples+1]=table.concat(rows,string.char(10)) end
        end
      end
    end end
  end
end
local names={} for k in pairs(stats) do names[#names+1]=k end table.sort(names)
local out={"errors="..fails.." seeds="..N, "type                   n   gap0 gap1 gap2 gap3 gap4+"}
for _,k in ipairs(names) do local s=stats[k]
  local g4=0 for g,c in pairs(s.g) do if g>=4 then g4=g4+c end end
  out[#out+1]=string.format("%-22s %3d  %4d %4d %4d %4d %4d",k,s.n,s.g[0] or 0,s.g[1] or 0,s.g[2] or 0,s.g[3] or 0,g4)
end
return table.concat(out,string.char(10))..string.char(10)..table.concat(samples,string.char(10)..string.char(10))
''', N, SHOW)
print(res)
