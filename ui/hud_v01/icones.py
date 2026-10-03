"""Icônes du HUD (haut à droite), dessinées à la main en SVG : pictogrammes blancs pleins, détails en creux,
ombre douce. Même gabarit que la référence fournie par le joueur, dessins originaux.
Rendu PNG 128x128 transparent avec Chrome sans fenêtre. Usage : python icones.py"""
import subprocess, pathlib

ICI = pathlib.Path(__file__).resolve().parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
B, G = "#fbfbf8", "#9aa0a8"   # blanc des pictogrammes, gris des creux

ICONES = {
  # carte : anneau et rose des vents
  "carte": f'''
    <circle cx="64" cy="64" r="44" fill="none" stroke="{B}" stroke-width="9"/>
    <path d="M64 30 L74 64 L64 98 L54 64 Z" fill="{B}"/>
    <path d="M64 30 L74 64 L64 64 Z" fill="{G}"/>
    <path d="M30 64 L64 56 L98 64 L64 72 Z" fill="{B}" opacity="0.85"/>
    <circle cx="64" cy="64" r="6" fill="{G}"/>''',
  # événement : flamme-emblème avec étoile à quatre branches au cœur
  "evenement": f'''
    <path d="M64 14 C78 34 98 46 98 74 C98 96 82 112 64 112 C46 112 30 96 30 74 C30 58 40 48 46 40
             C48 52 54 58 60 60 C56 44 58 28 64 14 Z" fill="{B}"/>
    <path d="M64 58 L69 77 L86 82 L69 87 L64 104 L59 87 L42 82 L59 77 Z" fill="{G}"/>''',
  # offres du jour : gemme taillée et éclat
  "offres": f'''
    <path d="M38 34 L90 34 L108 56 L64 108 L20 56 Z" fill="{B}"/>
    <path d="M20 56 L108 56" stroke="{G}" stroke-width="5"/>
    <path d="M50 34 L42 56 L64 108 L86 56 L78 34" fill="none" stroke="{G}" stroke-width="5" stroke-linejoin="round"/>
    <path d="M104 12 L107 22 L117 25 L107 28 L104 38 L101 28 L91 25 L101 22 Z" fill="{B}"/>''',
  # quêtes quotidiennes : livre ouvert et signet coché
  "quetes": f'''
    <path d="M14 34 C30 28 48 28 61 36 L61 104 C48 96 30 96 14 102 Z" fill="{B}"/>
    <path d="M114 34 C98 28 80 28 67 36 L67 104 C80 96 98 96 114 102 Z" fill="{B}"/>
    <path d="M24 48 C34 45 44 45 52 49 M24 62 C34 59 44 59 52 63 M24 76 C34 73 44 73 52 77" stroke="{G}" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M78 54 L87 64 L104 44" stroke="{G}" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>''',
  # inventaire : sac à dos à rabat
  "inventaire": f'''
    <path d="M48 26 C48 14 80 14 80 26" stroke="{B}" stroke-width="7" fill="none"/>
    <rect x="26" y="28" width="76" height="84" rx="18" fill="{B}"/>
    <path d="M26 54 C44 64 84 64 102 54 L102 46 C102 36 92 28 80 28 L48 28 C36 28 26 36 26 46 Z" fill="{G}"/>
    <rect x="56" y="58" width="16" height="14" rx="3" fill="{B}" stroke="{G}" stroke-width="4"/>
    <rect x="40" y="82" width="48" height="20" rx="6" fill="none" stroke="{G}" stroke-width="4"/>''',
  # constructions : toit de maison et marteau en travers
  "constructions": f'''
    <path d="M10 62 L56 22 L102 62 L90 62 L56 34 L22 62 Z" fill="{B}"/>
    <path d="M26 64 L56 40 L86 64 L86 108 L26 108 Z" fill="{B}"/>
    <rect x="48" y="80" width="16" height="28" fill="{G}"/>
    <g transform="rotate(40 96 76)">
      <rect x="91" y="62" width="10" height="54" rx="4" fill="{B}" stroke="#3a3d44" stroke-width="3"/>
      <rect x="76" y="50" width="40" height="18" rx="4" fill="{B}" stroke="#3a3d44" stroke-width="3"/>
    </g>''',
}

def page(svg: str) -> str:
    return f'''<html><body style="margin:0;background:transparent">
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="-4 -4 136 136"
     style="filter:drop-shadow(0 1px 2px rgba(0,0,0,.55)) drop-shadow(0 0 4px rgba(0,0,0,.25))">{svg}</svg></body></html>'''

for nom, svg in ICONES.items():
    html = ICI / f"_{nom}.html"
    html.write_text(page(svg), encoding="utf-8")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
                    f"--screenshot={ICI / (nom + '.png')}", "--window-size=128,128", html.as_uri()],
                   check=True, capture_output=True)
    html.unlink()

# planche d'aperçu, sur un ciel comme en jeu
cellules = "".join(f'<div style="display:inline-block;margin:0 14px;text-align:center;color:#fff;font:12px sans-serif">'
                   f'<img src="{nom}.png" width="64"><br>{nom}</div>' for nom in ICONES)
apercu = ICI / "_apercu.html"
apercu.write_text(f'<html><body style="margin:0;padding:18px;background:linear-gradient(#3d8fd8,#a9d4f5)">{cellules}</body></html>', encoding="utf-8")
subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--screenshot={ICI / 'apercu.png'}",
                "--window-size=640,120", apercu.as_uri()], check=True, capture_output=True)
apercu.unlink()
print("ok")
