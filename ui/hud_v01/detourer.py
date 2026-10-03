"""Retire le fond vert (#00FF00) des images Meshy et les réduit en PNG transparents carrés.
Le calcul se fait dans Chrome (canvas) : clé sur la dominance du vert, bords adoucis, vert résiduel retiré.
Options : « ombre » ajoute une ombre douce et recadre sur le dessin (icônes du haut, sans disque).
Usage : python detourer.py sources/x.png sortie.png [taille] [ombre]"""
import subprocess, pathlib, sys
ICI = pathlib.Path(__file__).resolve().parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
source, sortie = (ICI / sys.argv[1]).resolve(), (ICI / sys.argv[2]).resolve()
taille = int(sys.argv[3]) if len(sys.argv) > 3 else 256
ombre = "ombre" in sys.argv[4:]
page = ICI / "_detourer.html"
page.write_text(f'''<html><body style="margin:0;background:transparent"><canvas id="c" width="{taille}" height="{taille}"></canvas>
<script>
const img = new Image();
img.onload = () => {{
  const w = img.width, h = img.height, t = document.createElement("canvas");
  t.width = w; t.height = h;
  const x = t.getContext("2d"); x.drawImage(img, 0, 0);
  const d = x.getImageData(0, 0, w, h), p = d.data;
  for (let i = 0; i < p.length; i += 4) {{
    const r = p[i], g = p[i+1], b = p[i+2], cle = g - Math.max(r, b);
    if (cle > 70) p[i+3] = 0;
    else if (cle > 20) p[i+3] = Math.round(255 * (70 - cle) / 50);
    if (cle > 0) p[i+1] = Math.max(r, b);   // plus de liseré vert sur les bords
  }}
  x.putImageData(d, 0, 0);
  const c = document.getElementById("c").getContext("2d");
  c.imageSmoothingQuality = "high";
  let sx = 0, sy = 0, sw = w, sh = h;
  if ({str(ombre).lower()}) {{
    // recadrage carré sur le dessin, avec une marge pour l'ombre
    let x0 = w, y0 = h, x1 = 0, y1 = 0;
    for (let y = 0; y < h; y++) for (let x2 = 0; x2 < w; x2++) if (p[(y*w + x2)*4 + 3] > 20) {{
      if (x2 < x0) x0 = x2; if (x2 > x1) x1 = x2; if (y < y0) y0 = y; if (y > y1) y1 = y; }}
    const cote = Math.max(x1 - x0, y1 - y0) * 1.12, cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    sx = cx - cote / 2; sy = cy - cote / 2; sw = sh = cote;
    c.shadowColor = "rgba(0,0,0,0.5)"; c.shadowBlur = {taille} / 40; c.shadowOffsetY = {taille} / 128;
  }}
  c.drawImage(t, sx, sy, sw, sh, 0, 0, {taille}, {taille});
}};
img.src = "{source.as_uri()}";
</script></body></html>''', encoding="utf-8")
subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                "--default-background-color=00000000", "--virtual-time-budget=3000",
                f"--screenshot={sortie}", f"--window-size={taille},{taille}", page.as_uri()], check=True, capture_output=True)
page.unlink()
print("ok", sortie.name)
