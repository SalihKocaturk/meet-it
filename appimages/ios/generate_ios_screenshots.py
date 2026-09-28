"""
MeetIt — App Store (iPhone 6.5") ekran görüntüsü üretici.

Ham Android ekran görüntülerini (../*.jpg) alır; Android durum çubuğunu ve
jest çubuğunu kesip yerine iOS durum çubuğu + Dynamic Island + iOS ev çubuğu
çizer, iPhone çerçevesine yerleştirir ve iki stilde (A: yeşil/logolu,
C: koyu) TR + EN olarak dışa aktarır.

Kullanım:  python3 generate_ios_screenshots.py
Gereken:   pip install pillow   +  Poppins fontu (aşağıdaki FONT_DIRS)
"""
import os, glob
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)                      # appimages/
LOGO = os.path.join(SRC, '..', 'assets', 'images', 'logo_icon.png')
OUT = HERE
CANVAS = (1284, 2778)                            # App Store 6.5"

FONT_DIRS = ['/usr/share/fonts/truetype/google-fonts',
             os.path.expanduser('~/Library/Fonts'), '/Library/Fonts']
def font(name, size):
    for d in FONT_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    raise SystemExit(f'Font bulunamadı: {name} — Poppins kur.')

SCREENS = [
  ('01', 'home_page',
   ('Arkadaşlarını gör, tek dokunuşla buluş', 'Ana sayfadan hızlı buluşma'),
   ('See your friends, meet in one tap', 'Fast meetups from the home screen')),
  ('02', 'meeting_setup',
   ('Aktiviteni seç, gerisini bize bırak', 'Kafe, restoran, park, sinema ve daha fazlası'),
   ('Pick your activity, leave the rest to us', 'Cafe, restaurant, park, cinema and more')),
  ('03', 'meeting_map_view',
   ('Tam ikinizin ortasında buluşun', 'Konumlarınızın orta noktasına en yakın mekanlar'),
   ('Meet exactly in the middle', 'Venues nearest the midpoint of your locations')),
  ('04', 'venue_detail',
   ('Mekanı incele, yorumları oku', 'Puanlar, fotoğraflar ve yol tarifi tek ekranda'),
   ('Explore the venue, read the reviews', 'Ratings, photos and directions in one place')),
  ('05', 'personality_analysis',
   ('Kişilik profilin zamanla gelişir', 'Yorum yazdıkça analizin güncellenir'),
   ('Your personality profile evolves', 'It updates as you review the places you go')),
  ('06', 'friend_compatibility',
   ('Arkadaşınla uyumunu ölç', 'Radar grafiğiyle profil karşılaştırması'),
   ('Measure your compatibility', 'Profile comparison on a radar chart')),
  ('07', 'personality_type_gourmet',
   ('5 farklı kişilik tipi', 'Gurme, Maceraperest, Sakin Ruh ve dahası'),
   ('Five personality types', 'Gourmet, Adventurer, Calm Soul and more')),
  ('08', 'friend_code',
   ('6 haneli kodla arkadaş ekle', 'Kodunu paylaş, saniyeler içinde bağlan'),
   ('Add friends with a 6-digit code', 'Share your code, connect in seconds')),
]

ANDROID_TOP = 118      # Android durum çubuğu (1080 genişlikte)
CONTENT_H = 2182       # durum çubuğu + jest çubuğu kesildikten sonra kalan
SCREEN_ASPECT = 2.168  # iPhone 15/16 Pro ekran oranı

SAFE_BOTTOM = 80       # iOS alt güvenli alan (1080 genişlikte piksel)

def with_safe_area(content):
    """Alt sekme çubuğu varsa altına iOS güvenli alanı ekler, böylece ev
    çubuğu sekme etiketlerinin üstüne binmez. Toplam yükseklik aynı kalsın
    diye sekme çubuğunun hemen üstündeki gövdeden kırpılır."""
    import numpy as np
    a = np.asarray(content).astype(int)
    h = a.shape[0]
    nav_bg = np.median(a[h - 6], 0)
    body_bg = np.median(a[h // 2], 0)
    # Alt satır gövde renginden belirgin farklı değilse sekme çubuğu yok.
    if np.abs(nav_bg - body_bg).max() < 3:
        return content
    y = h - 6
    while y > h - 400 and np.abs(np.median(a[y], 0) - nav_bg).max() <= 3:
        y -= 1
    nav_top = y + 1
    if h - nav_top < 60:                       # sekme çubuğu bulunamadı
        return content
    body = content.crop((0, 0, content.width, nav_top - SAFE_BOTTOM))
    nav = content.crop((0, nav_top, content.width, h))
    out = Image.new('RGB', (content.width, h), tuple(int(v) for v in nav_bg))
    out.paste(body, (0, 0))
    out.paste(nav, (0, nav_top - SAFE_BOTTOM))
    return out

# ── iOS ekranı (durum çubuğu + Dynamic Island + ev çubuğu) ────────────────
def ios_screen(raw_path, screen_w):
    raw = Image.open(raw_path).convert('RGB')
    content = raw.crop((0, ANDROID_TOP, raw.width, ANDROID_TOP + CONTENT_H))
    content = with_safe_area(content)
    ch = round(screen_w * content.height / raw.width)
    content = content.resize((screen_w, ch), Image.LANCZOS)
    sh = round(screen_w * SCREEN_ASPECT)
    band = sh - ch
    scr = Image.new('RGB', (screen_w, sh))
    # Üst bant: içeriğin ilk satırlarının yumuşatılmış devamı
    # (düz ekranlarda düz renk, harita/fotoğrafta doğal geçiş).
    strip = content.crop((0, 0, screen_w, 10)).resize((screen_w, band + 20))
    strip = strip.filter(ImageFilter.GaussianBlur(18))
    scr.paste(strip.crop((0, 0, screen_w, band)), (0, 0))
    scr.paste(content, (0, band))

    s = screen_w / 393.0                          # iOS point → piksel
    d = ImageDraw.Draw(scr, 'RGBA')
    # Hafif karartma: açık renkli içerikte beyaz yazı okunsun
    for y in range(band):
        a = int(70 * (1 - y / band))
        d.line([(0, y), (screen_w, y)], fill=(0, 0, 0, a))
    cy = band * 0.5 + 2 * s
    # Dynamic Island
    iw, ih = 125 * s, 36 * s
    d.rounded_rectangle([(screen_w - iw) / 2, cy - ih / 2,
                         (screen_w + iw) / 2, cy + ih / 2],
                        radius=ih / 2, fill=(0, 0, 0, 255))
    # Saat
    f = font('Poppins-Medium.ttf', round(16.5 * s))
    t = '9:41'
    tb = d.textbbox((0, 0), t, font=f)
    tx = (screen_w / 2 - iw / 2) / 2 - (tb[2] - tb[0]) / 2
    d.text((tx, cy - (tb[3] + tb[1]) / 2), t, font=f, fill='white')
    # Sağ: sinyal, wifi, pil
    right_c = screen_w - (screen_w / 2 - iw / 2) / 2
    gw = 72 * s
    x0 = right_c - gw / 2
    for i in range(4):                             # hücresel çubuklar
        bh = (4 + i * 2.6) * s
        bx = x0 + i * 4.6 * s
        d.rounded_rectangle([bx, cy + 5 * s - bh, bx + 3.2 * s, cy + 5 * s],
                            radius=0.9 * s, fill='white')
    wx = x0 + 25 * s                              # wifi (3 yay)
    for i, r in enumerate((10.5, 7, 3.5)):
        r *= s
        d.arc([wx + 8 * s - r, cy + 4 * s - r, wx + 8 * s + r, cy + 4 * s + r],
              start=225, end=315, fill='white', width=round(2.1 * s))
    d.ellipse([wx + 6.6 * s, cy + 2.6 * s, wx + 9.4 * s, cy + 5.4 * s], fill='white')
    bx = x0 + 45 * s                              # pil
    d.rounded_rectangle([bx, cy - 6 * s, bx + 25 * s, cy + 6 * s],
                        radius=3.6 * s, outline=(255, 255, 255, 110), width=round(1.1 * s))
    d.rounded_rectangle([bx + 2 * s, cy - 4 * s, bx + 23 * s, cy + 4 * s],
                        radius=2.2 * s, fill='white')
    d.rounded_rectangle([bx + 26 * s, cy - 2 * s, bx + 27.6 * s, cy + 2 * s],
                        radius=0.8 * s, fill=(255, 255, 255, 110))
    # Ev çubuğu (home indicator)
    hw = 134 * s
    d.rounded_rectangle([(screen_w - hw) / 2, sh - 13 * s,
                         (screen_w + hw) / 2, sh - 8 * s],
                        radius=2.5 * s, fill=(255, 255, 255, 235))
    return scr

# ── iPhone gövdesi ────────────────────────────────────────────────────────
def iphone(scr):
    sw, sh = scr.size
    bez = round(sw * 0.024)
    rad = round(sw * 0.135)
    W, H = sw + 2 * bez, sh + 2 * bez
    body = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=rad + bez, fill=(72, 74, 79))
    d.rounded_rectangle([3, 3, W - 4, H - 4], radius=rad + bez - 3, fill=(22, 22, 24))
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=rad, fill=255)
    body.paste(scr, (bez, bez), mask)
    return body

def shadow(img, blur, alpha, color=(0, 0, 0)):
    a = img.split()[3].point(lambda v: alpha if v else 0)
    sh = Image.new('RGBA', img.size, color + (0,))
    sh.putalpha(a)
    pad = blur * 3
    out = Image.new('RGBA', (img.width + 2 * pad, img.height + 2 * pad), (0, 0, 0, 0))
    out.paste(sh, (pad, pad))
    return out.filter(ImageFilter.GaussianBlur(blur)), pad

def wrap(d, text, f, maxw):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=f) <= maxw: cur = t
        else: lines.append(cur); cur = w
    lines.append(cur)
    return lines

def centered(d, y, lines, f, fill, lh):
    for ln in lines:
        w = d.textlength(ln, font=f)
        d.text(((CANVAS[0] - w) / 2, y), ln, font=f, fill=fill)
        y += lh
    return y

# ── Stil A: yeşil degrade, başlık üstte, telefon tam görünür ──────────────
# Logo + "MeetIt" yalnızca ilk görselde (show_logo=True). Telefon boyutu ve
# konumu 8 görselde de aynı, App Store'da yan yana dizildiğinde zıplamasın.
A_SCREEN_W = 915
A_BOTTOM_MARGIN = 80

def style_a(raw, title, sub, show_logo=False):
    W, H = CANVAS
    bg = Image.new('RGB', CANVAS)
    top, bot = (110, 200, 152), (52, 128, 92)
    px = bg.load()
    for y in range(H):
        for x in range(W):
            t = min(1, max(0, (x / W) * 0.35 + (y / H) * 0.75))
            px[x, y] = tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    ov = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.ellipse([W * 0.42, -W * 0.30, W * 1.55, W * 0.85], fill=(255, 255, 255, 16))
    od.ellipse([-W * 0.55, H * 0.55, W * 0.55, H * 1.05], fill=(255, 255, 255, 12))
    bg = Image.alpha_composite(bg.convert('RGBA'), ov)
    d = ImageDraw.Draw(bg)

    ph = iphone(ios_screen(raw, A_SCREEN_W))
    ph_top = H - A_BOTTOM_MARGIN - ph.height

    ft, fs = font('Poppins-Bold.ttf', 84), font('Poppins-Light.ttf', 44)
    tl = wrap(d, title, ft, W - 150)
    sl = wrap(d, sub, fs, W - 150)
    block_h = len(tl) * 100 + 6 + len(sl) * 58

    if show_logo:
        logo = Image.open(LOGO).convert('RGBA').resize((136, 136), Image.LANCZOS)
        fl = font('Poppins-Bold.ttf', 104)
        tw = d.textlength('MeetIt', font=fl)
        lx = (W - (136 + 26 + tw)) / 2
        bg.alpha_composite(logo, (round(lx), 110))
        d.text((lx + 162, 104), 'MeetIt', font=fl, fill='white')
        y0 = 300
    else:
        y0 = round((ph_top - block_h) / 2) - 10

    y = centered(d, y0, tl, ft, 'white', 100)
    centered(d, y + 6, sl, fs, (235, 247, 240), 58)

    shd, pad = shadow(ph, 40, 110)
    px_ = (W - ph.width) // 2
    bg.alpha_composite(shd, (px_ - pad, ph_top - pad + 20))
    bg.alpha_composite(ph, (px_, ph_top))
    return bg.convert('RGB')

# ── Stil C: koyu zemin, yeşil ışıma, telefon ortada, başlık altta ─────────
def style_c(raw, title, sub):
    W, H = CANVAS
    bg = Image.new('RGBA', CANVAS, (11, 15, 16, 255))
    glow = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([W * 0.02, H * 0.12, W * 0.98, H * 0.72],
                                 fill=(40, 130, 90, 70))
    bg = Image.alpha_composite(bg, glow.filter(ImageFilter.GaussianBlur(160)))
    ph = iphone(ios_screen(raw, 925))
    shd, pad = shadow(ph, 45, 160)
    px_, py_ = (W - ph.width) // 2, 175
    bg.alpha_composite(shd, (px_ - pad, py_ - pad + 24))
    bg.alpha_composite(ph, (px_, py_))
    d = ImageDraw.Draw(bg)
    ly = py_ + ph.height + 62
    d.rounded_rectangle([W / 2 - 70, ly, W / 2 + 70, ly + 9], radius=5, fill=(86, 180, 132))
    ft, fs = font('Poppins-Bold.ttf', 80), font('Poppins-Regular.ttf', 40)
    y = centered(d, ly + 40, wrap(d, title, ft, W - 130), ft, 'white', 94)
    centered(d, y + 8, wrap(d, sub, fs, W - 130), fs, (160, 168, 170), 54)
    return bg.convert('RGB')

if __name__ == '__main__':
    for num, key, tr, en in SCREENS:
        raw = os.path.join(SRC, key + '.jpg')
        for style, fn in (('A', style_a), ('C', style_c)):
            for lang, (title, sub) in (('tr', tr), ('en', en)):
                d = os.path.join(OUT, f'style_{style}_{lang}')
                os.makedirs(d, exist_ok=True)
                if style == 'A':
                    img = fn(raw, title, sub, show_logo=(num == '01'))
                else:
                    img = fn(raw, title, sub)
                assert img.size == CANVAS
                img.save(os.path.join(d, f'{num}_{key}.png'), optimize=True)
        print('ok', num, key)
