"""Découpe en cercle une icône Meshy ronde posée sur un fond uni (pas de vert) : le bord du disque est trouvé
sur la ligne du milieu (premier pixel nettement plus clair que le fond), le reste devient transparent.
Produit aussi lueur.png (halo doux) et etincelle.png (point lumineux) pour l'effet animé des boutons.
Usage : python disque.py sources/x.png sortie.png [taille]"""
import subprocess, pathlib, sys
ICI = pathlib.Path(__file__).resolve().parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

def rendre(js, sortie, taille):
    page = ICI / "_disque.html"
    page.write_text(f'<html><body style="margin:0;background:transparent"><canvas id="c" width="{taille}" height="{taille}"></canvas><script>{js}</script></body></html>', encoding="utf-8")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    "--default-background-color=00000000", "--virtual-time-budget=4000",
                    f"--screenshot={sortie}", f"--window-size={taille},{taille}", page.as_uri()], check=True, capture_output=True)
    page.unlink()

if len(sys.argv) > 2:
    source, sortie = (ICI / sys.argv[1]).resolve(), (ICI / sys.argv[2]).resolve()
    taille = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    rendre(f'''
const img = new Image();
img.onload = () => {{
  const w = img.width, h = img.height, t = document.createElement("canvas"); t.width = w; t.height = h;
  const x = t.getContext("2d"); x.drawImage(img, 0, 0);
  const d = x.getImageData(0, 0, w, h).data, cy = h >> 1, fond = d[(cy*w)*4];
  let bordG = 0;
  for (let i = 0; i < w/2; i++) {{ const p = (cy*w + i)*4; if (Math.max(d[p], d[p+1], d[p+2]) - fond > 110) {{ bordG = i; break; }} }}
  const r = w/2 - bordG + 2;
  const c = document.getElementById("c").getContext("2d");
  c.beginPath(); c.arc({taille}/2, {taille}/2, {taille}/2 - 1, 0, 7); c.clip();
  c.imageSmoothingQuality = "high";
  c.drawImage(t, w/2 - r, h/2 - r, 2*r, 2*r, 0, 0, {taille}, {taille});
}};
img.src = "{source.as_uri()}";''', str(sortie), taille)
    print("ok", sortie.name)
else:
    rendre('''const c = document.getElementById("c").getContext("2d");
const g = c.createRadialGradient(128,128,40,128,128,128);
g.addColorStop(0,"rgba(255,255,255,0.9)"); g.addColorStop(0.45,"rgba(255,255,255,0.45)"); g.addColorStop(1,"rgba(255,255,255,0)");
c.fillStyle = g; c.fillRect(0,0,256,256);''', str(ICI / "lueur.png"), 256)
    rendre('''const c = document.getElementById("c").getContext("2d");
const g = c.createRadialGradient(32,32,0,32,32,32);
g.addColorStop(0,"rgba(255,255,255,1)"); g.addColorStop(0.25,"rgba(255,255,255,0.85)"); g.addColorStop(1,"rgba(255,255,255,0)");
c.fillStyle = g; c.fillRect(0,0,64,64);''', str(ICI / "etincelle.png"), 64)
    print("ok lueur etincelle")
