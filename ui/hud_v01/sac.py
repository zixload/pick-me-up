"""Icône d'inventaire, version découpée : silhouette blanche pleine, détails creusés (le fond transparaît),
ombre douce. Rendu 128x128 transparent + planche de comparaison sur le gris du ciel de la référence."""
import subprocess, pathlib, sys
ICI = pathlib.Path(__file__).resolve().parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
B = "#fdfdfb"

# silhouette pleine, puis découpes (en noir dans le masque)
PLEIN = '''
  <rect x="44" y="9" width="40" height="18" rx="8"/>                                          <!-- poignée -->
  <path d="M10 62 L16 37 C18 30 24 26 32 26 L96 26 C104 26 110 30 112 37 L118 62 C100 61 78 62 64 68 C50 62 28 61 10 62 Z"/>  <!-- rabat évasé -->
  <path d="M20 66 L108 66 L106 101 C105 108 100 112 92 112 L36 112 C28 112 23 108 22 101 Z"/>   <!-- corps -->
  <rect x="28" y="110" width="17" height="10" rx="3"/><rect x="83" y="110" width="17" height="10" rx="3"/>  <!-- pieds -->
'''
CREUX = '''
  <rect x="54" y="14" width="20" height="7" rx="3.5"/>                                        <!-- jour de la poignée -->
  <path d="M10 63 C28 62 50 63 64 69 C78 63 100 62 118 63" stroke-width="5" fill="none"/>      <!-- bord du rabat -->
  <path d="M64 55 L75 67 L64 79 L53 67 Z" stroke-width="0"/>                                  <!-- logement du fermoir -->
  <path d="M35 72 L35 108 M48 72 L48 108 M80 72 L80 108 M93 72 L93 108" stroke-width="3.5"/>  <!-- sangles -->
  <rect x="31" y="80" width="21" height="10" rx="2" stroke-width="3.5" fill="none"/>          <!-- boucles -->
  <rect x="76" y="80" width="21" height="10" rx="2" stroke-width="3.5" fill="none"/>
  <path d="M26 111 L102 111" stroke-width="3"/>                                               <!-- pieds détachés -->
  <path d="M20 55 L54 56 M74 56 L108 55" stroke-width="2" stroke-dasharray="3 5" fill="none"/>  <!-- coutures -->
'''
AJOUT = '''
  <path d="M64 60 L71 67 L64 74 L57 67 Z"/>                                                   <!-- fermoir -->
'''

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="-6 -4 140 132"
 style="filter:drop-shadow(0 1px 1.5px rgba(0,0,0,.45))">
 <defs><mask id="m" maskUnits="userSpaceOnUse">
  <g fill="white">{PLEIN}</g>
  <g fill="black" stroke="black" stroke-linecap="round" stroke-linejoin="round">{CREUX}</g>
  <g fill="white">{AJOUT}</g>
 </mask></defs>
 <rect x="-10" y="-10" width="150" height="150" fill="{B}" mask="url(#m)"/>
</svg>'''

def rendre(html, sortie, taille):
    f = ICI / "_t.html"
    f.write_text(html, encoding="utf-8")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
                    f"--screenshot={sortie}", f"--window-size={taille}", f.as_uri()], check=True, capture_output=True)
    f.unlink()

rendre(f'<html><body style="margin:0">{svg}</body></html>', ICI / "inventaire.png", "128,128")
ref = pathlib.Path(r"C:\Users\ingam\AppData\Local\Temp\claude\c--Users-ingam-OneDrive-Documents-memoire\d3a6a12b-be59-49eb-b569-a88577c1615e\scratchpad\ref_sac.png").as_uri()
tour = sys.argv[1] if len(sys.argv) > 1 else "1"
rendre(f'''<html><body style="margin:0;background:#8f8a91;display:flex;gap:30px;padding:16px;align-items:center">
<img src="{ref}" width="200"><img src="inventaire.png" width="200" style="background:#8f8a91">
<img src="inventaire.png" width="44"></body></html>''', ICI / f"comparaison_sac_{tour}.png", "560,240")
print("ok")
