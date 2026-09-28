# -*- coding: utf-8 -*-
"""
legal_content.py'deki metinleri uygulamaya ve web'e basar:
  1) assets/translations/{tr,en}.json  -> legal.* anahtarları
  2) lib/features/settings/{terms,privacy_policy}_page.dart -> bölüm sayısı
  3) legal/terms.html, legal/privacy.html -> GitHub Pages sayfaları
Kullanım (repo kökünden):  python3 legal/build_legal.py
"""
import html, io, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from legal_content import TERMS, PRIVACY, UPDATED, CONTACT, OWNER

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TITLES = {"tr": ("Kullanım Koşulları", "Gizlilik Politikası"),
          "en": ("Terms of Use", "Privacy Policy")}
UPD_LABEL = {"tr": "Son güncelleme", "en": "Last updated"}
assert len(TERMS["tr"]) == len(TERMS["en"]) and len(PRIVACY["tr"]) == len(PRIVACY["en"])

# ── 1) Çeviri dosyaları: sadece "legal" bloğu yeniden yazılır ─────────────
def update_translations(lang):
    p = os.path.join(ROOT, "assets", "translations", f"{lang}.json")
    raw = io.open(p, encoding="utf-8", newline="").read()
    data = json.loads(raw)
    old = data["legal"]
    sec = re.compile(r"^(terms|privacy)_s\d+_(title|body)$")
    new = {k: v for k, v in old.items() if not sec.match(k)}
    new["terms_title"], new["privacy_title"] = TITLES[lang]
    new["terms_last_updated"] = f"{UPD_LABEL[lang]}: {UPDATED[lang]}"
    new["privacy_last_updated"] = f"{UPD_LABEL[lang]}: {UPDATED[lang]}"
    for i, (t, b) in enumerate(TERMS[lang], 1):
        new[f"terms_s{i}_title"], new[f"terms_s{i}_body"] = t, b
    for i, (t, b) in enumerate(PRIVACY[lang], 1):
        new[f"privacy_s{i}_title"], new[f"privacy_s{i}_body"] = t, b

    lines = raw.split("\n")
    start = next(i for i, l in enumerate(lines) if l.strip() == '"legal": {')
    ind = lines[start][: len(lines[start]) - len(lines[start].lstrip())]
    depth, end = 0, None
    for i in range(start, len(lines)):
        depth += lines[i].count("{") - lines[i].count("}")
        if depth == 0:
            end = i; break
    closing = lines[end]
    body = [f'{ind}  {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)},'
            for k, v in new.items()]
    body[-1] = body[-1][:-1]
    lines[start + 1:end] = body
    out = "\n".join(lines)
    check = json.loads(out)
    assert check["legal"] == new
    assert {k: v for k, v in check.items() if k != "legal"} == \
           {k: v for k, v in data.items() if k != "legal"}
    io.open(p, "w", encoding="utf-8", newline="").write(out)
    print("ceviri guncellendi:", p)

# ── 2) Dart sayfaları: sabit bölüm listesi -> döngü ──────────────────────
def update_page(fname, prefix, count):
    p = os.path.join(ROOT, "lib", "features", "settings", fname)
    s = io.open(p, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in s else "\n"
    pat = re.compile(
        r"([ \t]*)_buildSection\(context, 'legal\.%s_s\d+_title'\.tr\(\), "
        r"'legal\.%s_s\d+_body'\.tr\(\)\),[ \t]*(?:\r?\n\1_buildSection\(context, "
        r"'legal\.%s_s\d+_title'\.tr\(\), 'legal\.%s_s\d+_body'\.tr\(\)\),[ \t]*)*"
        % ((prefix,) * 4))
    loop = re.compile(r"([ \t]*)for \(var i = 1; i <= \d+; i\+\+\)" + r"[\s\S]*?'legal\.%s_s\$\{i\}_body'\.tr\(\),\s*\)," % prefix)
    def repl(m):
        i = m.group(1)
        return (f"{i}for (var i = 1; i <= {count}; i++){nl}"
                f"{i}  _buildSection({nl}"
                f"{i}    context,{nl}"
                f"{i}    'legal.{prefix}_s${{i}}_title'.tr(),{nl}"
                f"{i}    'legal.{prefix}_s${{i}}_body'.tr(),{nl}"
                f"{i}  ),")
    if loop.search(s):
        s2 = loop.sub(repl, s, count=1)
    else:
        s2, n = pat.subn(repl, s, count=1)
        assert n == 1, f"{fname}: bolum listesi bulunamadi"
    io.open(p, "w", encoding="utf-8", newline="").write(s2)
    print(f"sayfa guncellendi: {fname} ({count} bolum)")

# ── 3) HTML ──────────────────────────────────────────────────────────────
def body_html(text):
    out, items = [], []
    def flush():
        if items:
            out.append("<ul>" + "".join(f"<li>{x}</li>" for x in items) + "</ul>")
            items.clear()
    for line in text.split("\n"):
        esc = html.escape(line.strip())
        esc = esc.replace(CONTACT, f'<a href="mailto:{CONTACT}">{CONTACT}</a>')
        if not esc:
            continue
        if esc.startswith("• "):
            items.append(esc[2:])
        else:
            flush(); out.append(f"<p>{esc}</p>")
    flush()
    return "\n".join(out)

CSS = """
:root{--bg:#f6f8f7;--card:#fff;--text:#1d2320;--muted:#5d6b64;--accent:#3a8a64;--line:#e3e9e6}
@media (prefers-color-scheme:dark){:root{--bg:#0e1113;--card:#161a1d;--text:#e9eeeb;--muted:#9aa6a0;--accent:#5cb58a;--line:#262c30}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:760px;margin:0 auto;padding:32px 20px 64px}
header{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:8px}
.brand{font-weight:700;font-size:20px;color:var(--accent);text-decoration:none}
.langs button{font:inherit;font-size:14px;padding:6px 14px;border:1px solid var(--line);background:var(--card);color:var(--muted);border-radius:999px;cursor:pointer}
.langs button[aria-pressed=true]{background:var(--accent);border-color:var(--accent);color:#fff}
h1{font-size:30px;line-height:1.25;margin:24px 0 4px}
.updated{color:var(--muted);font-size:14px;margin:0 0 24px}
section{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px 20px;margin:0 0 14px}
h2{font-size:18px;margin:0 0 8px}
p{margin:0 0 10px}p:last-child{margin-bottom:0}
ul{margin:4px 0 10px;padding-left:22px}li{margin:2px 0}
a{color:var(--accent)}
footer{margin-top:28px;color:var(--muted);font-size:14px}
html.js [lang-block]:not(.active){display:none}
"""

JS = """
document.documentElement.classList.add('js');
(function(){
  var q=new URLSearchParams(location.search).get('lang');
  var lang=(q||navigator.language||'en').toLowerCase().indexOf('tr')===0?'tr':'en';
  function set(l){
    document.querySelectorAll('[lang-block]').forEach(function(e){e.classList.toggle('active',e.getAttribute('lang-block')===l)});
    document.querySelectorAll('.langs button').forEach(function(b){b.setAttribute('aria-pressed',b.dataset.l===l)});
    document.documentElement.lang=l;
  }
  document.addEventListener('DOMContentLoaded',function(){
    document.querySelectorAll('.langs button').forEach(function(b){b.onclick=function(){set(b.dataset.l)}});
    set(lang);
  });
})();
"""

def page(kind, links=None, extra=None):
    links = links or {"terms": "terms", "privacy": "privacy"}
    extra = extra or {}
    content = TERMS if kind == "terms" else PRIVACY
    idx = 0 if kind == "terms" else 1
    other = links["privacy" if kind == "terms" else "terms"]
    blocks = []
    for lang in ("tr", "en"):
        title = TITLES[lang][idx]
        other_title = TITLES[lang][1 - idx]
        secs = "\n".join(f"<section><h2>{html.escape(t)}</h2>\n{body_html(b)}</section>"
                         for t, b in content[lang])
        blocks.append(f"""<div lang-block="{lang}" lang="{lang}">
<h1>MeetIt — {html.escape(title)}</h1>
<p class="updated">{UPD_LABEL[lang]}: {UPDATED[lang]}</p>
{secs}
<footer><a href="{other}">{html.escape(other_title)}</a>{''.join(f' · <a href="{h}">{html.escape(t[lang])}</a>' for h, t in extra.items())} · <a href="mailto:{CONTACT}">{CONTACT}</a></footer>
</div>""")
    t = f"MeetIt — {TITLES['tr'][idx]} / {TITLES['en'][idx]}"
    return f"""<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(t)}</title>
<meta name="description" content="{html.escape(t)}">
<style>{CSS}</style>
<script>{JS}</script>
</head>
<body>
<div class="wrap">
<header><a class="brand" href="{links['terms']}">MeetIt</a>
<div class="langs" role="group" aria-label="Language"><button data-l="tr" aria-pressed="false">Türkçe</button> <button data-l="en" aria-pressed="false">English</button></div></header>
{blocks[0]}
{blocks[1]}
</div>
</body>
</html>
"""

if __name__ == "__main__":
    for lang in ("tr", "en"):
        update_translations(lang)
    update_page("terms_page.dart", "terms", len(TERMS["tr"]))
    update_page("privacy_policy_page.dart", "privacy", len(PRIVACY["tr"]))
    # 1) meetit-privacy reposu (Google Play): .../meetit-privacy/{terms,privacy}
    for kind in ("terms", "privacy"):
        p = os.path.join(ROOT, "legal", f"{kind}.html")
        io.open(p, "w", encoding="utf-8").write(page(kind))
        print("html yazildi:", p)
    # 2) meet-it reposunun kendisi (App Store Connect'teki gizlilik linki):
    #    .../meet-it/privacy-policy  ve  .../meet-it/terms-and-conditions
    site = {"terms": "terms-and-conditions", "privacy": "privacy-policy"}
    for kind in ("terms", "privacy"):
        p = os.path.join(ROOT, f"{site[kind]}.html")
        extra = {"delete-account.html": {"tr": "Hesap Silme", "en": "Delete Account"},
                 "support.html": {"tr": "Destek", "en": "Support"}}
        io.open(p, "w", encoding="utf-8").write(page(kind, site, extra))
        print("html yazildi:", p)
