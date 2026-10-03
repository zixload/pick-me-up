"""Découpe la carte du lobby (carte_lobby.png) au cercle du rempart : tout ce qui est hors du disque inscrit
devient transparent, bord lissé (masque dessiné 4x plus grand puis réduit). Sortie : carte_lobby_cercle.png.
Usage : python carte_cercle.py (Pillow requis)."""
import pathlib
from PIL import Image, ImageDraw
ICI = pathlib.Path(__file__).resolve().parent
carte = Image.open(ICI / "carte_lobby.png").convert("RGBA")
T, F = carte.size[0], 4
masque = Image.new("L", (T * F, T * F), 0)
ImageDraw.Draw(masque).ellipse((0, 0, T * F - 1, T * F - 1), fill=255)
masque = masque.resize((T, T), Image.LANCZOS)
alpha = Image.composite(carte.getchannel("A"), Image.new("L", (T, T), 0), masque)
carte.putalpha(alpha)
carte.save(ICI / "carte_lobby_cercle.png")
print("ok", carte.size)
