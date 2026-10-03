"""Image de la mini-carte du lobby (vue du dessus, nord en haut = -Z de Roblox), dessinée d'après carte_lobby.txt :
une case par 420/256 studs, relevée dans Studio par rayons verticaux (g herbe, s socle, p allée/place, d décor,
r rempart, t arbre, w eau, a sable, c roche, o autre, v vide). Couvre x et z de -210 à 210.
Sorties : carte_lobby.png (1024), fleche_joueur.png, cone_vue.png. Usage : python carte.py"""
import subprocess, pathlib
ICI = pathlib.Path(__file__).resolve().parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
donnees = (ICI / "carte_lobby.txt").read_text(encoding="utf-8").strip()

def rendre(js: str, sortie: str, taille: int):
    page = ICI / "_carte.html"
    page.write_text(f'<html><body style="margin:0;background:transparent"><canvas id="c" width="{taille}" height="{taille}"></canvas><script>{js}</script></body></html>', encoding="utf-8")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
                    "--virtual-time-budget=5000", f"--screenshot={ICI / sortie}", f"--window-size={taille},{taille}", page.as_uri()],
                   check=True, capture_output=True)
    page.unlink()

CARTE = r"""
const DONNEES = "%s", N = 256, T = 1024, K = T / N;
const grille = DONNEES.split("|").map(l => { const r = []; for (const m of l.matchAll(/([a-z])(\d+)/g)) for (let i = 0; i < +m[2]; i++) r.push(m[1]); return r; });
const c = document.getElementById("c").getContext("2d");
// masque lissé puis seuillé : contours arrondis au lieu de l'escalier des cases
function masque(test, flou) {
  const m = document.createElement("canvas"); m.width = m.height = N;
  const x = m.getContext("2d"), d = x.createImageData(N, N);
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) if (test(grille[j][i])) d.data[(j*N+i)*4+3] = 255;
  x.putImageData(d, 0, 0);
  const g = document.createElement("canvas"); g.width = g.height = T;
  const y = g.getContext("2d"); y.imageSmoothingEnabled = true; y.imageSmoothingQuality = "high";
  y.filter = `blur(${flou}px)`; y.drawImage(m, 0, 0, T, T);
  const a = y.getImageData(0, 0, T, T).data, r = new Uint8Array(T*T);
  for (let p = 0; p < T*T; p++) r[p] = a[p*4+3] >= 128 ? 1 : 0;
  return r;
}
function bord(m, p, e) {
  const x = p %% T, y = (p / T) | 0;
  return (x >= e && !m[p-e]) || (x < T-e && !m[p+e]) || (y >= e && !m[p-e*T]) || (y < T-e && !m[p+e*T]);
}
// bruit doux pour l'herbe
const bruit = document.createElement("canvas"); bruit.width = bruit.height = 24;
const bx = bruit.getContext("2d"), bd = bx.createImageData(24, 24);
let graine = 7; const hasard = () => (graine = (graine * 16807) %% 2147483647) / 2147483647;
for (let p = 0; p < 24*24; p++) { const v = hasard()*255; bd.data[p*4] = bd.data[p*4+1] = bd.data[p*4+2] = v; bd.data[p*4+3] = 255; }
bx.putImageData(bd, 0, 0);
const bg = document.createElement("canvas"); bg.width = bg.height = T;
const bgx = bg.getContext("2d"); bgx.imageSmoothingQuality = "high"; bgx.drawImage(bruit, 0, 0, T, T);
const nb = bgx.getImageData(0, 0, T, T).data;

// flou plus fort sur la pierre et les remparts : bouche les trous laissés par les touffes d'herbe
const pierre = masque(k => "spdo".includes(k), 4), rempart = masque(k => k == "r", 3.5), eau = masque(k => k == "w", 2);
const sable = masque(k => k == "a" || k == "c", 2);
const img = c.createImageData(T, T), o = img.data;
const mettre = (p, r, g, b) => { o[p*4] = r; o[p*4+1] = g; o[p*4+2] = b; o[p*4+3] = 255; };
for (let p = 0; p < T*T; p++) {
  const n = (nb[p*4] / 255 - 0.5) * 14;
  if (rempart[p]) bord(rempart, p, 3) ? mettre(p, 84, 91, 101) : mettre(p, 122, 130, 142);
  else if (pierre[p]) bord(pierre, p, 3) ? mettre(p, 186, 172, 138) : mettre(p, 229, 221, 197);
  else if (eau[p]) mettre(p, 143, 195, 227);
  else if (sable[p]) mettre(p, 214, 199, 160);
  else mettre(p, 166 + n, 189 + n, 108 + n * 0.6);
}
c.putImageData(img, 0, 0);
// arbres : touffes rondes avec une ombre portée, fusionnées quand elles se touchent
const arbres = [];
for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) if (grille[j][i] == "t") arbres.push([(i+0.5)*K, (j+0.5)*K]);
c.fillStyle = "rgba(60,80,40,0.35)";
for (const [x, y] of arbres) { c.beginPath(); c.arc(x+2, y+3, 7, 0, 7); c.fill(); }
c.fillStyle = "#6f9447";
for (const [x, y] of arbres) { c.beginPath(); c.arc(x, y, 7, 0, 7); c.fill(); }
c.fillStyle = "#86ab58";
for (const [x, y] of arbres) { c.beginPath(); c.arc(x-1.5, y-1.5, 4.5, 0, 7); c.fill(); }
""" % donnees

FLECHE = """
const c = document.getElementById("c").getContext("2d");
c.translate(64, 64);
c.shadowColor = "rgba(0,0,0,0.45)"; c.shadowBlur = 6;
c.beginPath(); c.moveTo(0, -46); c.lineTo(34, 40); c.lineTo(0, 22); c.lineTo(-34, 40); c.closePath();
c.fillStyle = "#ffffff"; c.fill();
c.shadowBlur = 0;
c.beginPath(); c.moveTo(0, -34); c.lineTo(24, 30); c.lineTo(0, 15); c.lineTo(-24, 30); c.closePath();
const g = c.createLinearGradient(0, -34, 0, 30); g.addColorStop(0, "#8ff0ff"); g.addColorStop(1, "#2fb8e8");
c.fillStyle = g; c.fill();
"""

CONE = """
const c = document.getElementById("c").getContext("2d");
const g = c.createRadialGradient(128, 256, 0, 128, 256, 256);
g.addColorStop(0, "rgba(255,255,255,0.55)"); g.addColorStop(1, "rgba(255,255,255,0)");
c.fillStyle = g;
c.beginPath(); c.moveTo(128, 256); c.arc(128, 256, 256, -Math.PI/2 - 0.75, -Math.PI/2 + 0.75); c.closePath(); c.fill();
"""

rendre(CARTE, "carte_lobby.png", 1024)
rendre(FLECHE, "fleche_joueur.png", 128)
rendre(CONE, "cone_vue.png", 256)
print("ok")
