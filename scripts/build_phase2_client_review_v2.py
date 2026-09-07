from pathlib import Path
from textwrap import wrap
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.utils import ImageReader

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "client-review/phase-2/FitCalgary_Phase_2_Client_Review.pdf"
ART = ROOT / ".artifacts"
W, H = letter
CREAM = colors.HexColor("#F4F1EA")
INK = colors.HexColor("#202428")
MUTED = colors.HexColor("#697071")
CORAL = colors.HexColor("#C85A4B")
PALE = colors.HexColor("#EAE4DA")
GREEN = colors.HexColor("#587460")
WHITE = colors.white

def txt(c, x, y, value, size=9, color=INK, bold=False):
    c.setFillColor(color); c.setFont("Helvetica-Bold" if bold else "Helvetica", size); c.drawString(x, y, value)

def wrap_text(c, x, y, value, width, size=9, leading=13, color=INK, bold=False, max_lines=None):
    c.setFillColor(color); c.setFont("Helvetica-Bold" if bold else "Helvetica", size)
    lines = wrap(value, max(20, int(width / (size * 0.48))))
    if max_lines: lines = lines[:max_lines]
    for line in lines: c.drawString(x, y, line); y -= leading
    return y

def rule(c, x, y, width, color=PALE, thickness=.7):
    c.setStrokeColor(color); c.setLineWidth(thickness); c.line(x, y, x + width, y)

def label(c, x, y, value, color=CORAL): txt(c, x, y, value.upper(), 7.5, color, True)

def footer(c, n):
    rule(c, 38, 32, W - 76); txt(c, 38, 18, "FITCALGARY INDEX  /  PHASE 2 CORE PRODUCT REVIEW", 6.5, MUTED, True); txt(c, W - 55, 18, f"{n:02d}", 6.5, MUTED, True)

def image_card(c, path, x, y, w, h, caption=None, bg=WHITE):
    c.setFillColor(bg); c.setStrokeColor(PALE); c.setLineWidth(.8); c.roundRect(x, y, w, h, 8, fill=1, stroke=1)
    p = Path(path)
    if p.exists(): c.drawImage(ImageReader(str(p)), x + 5, y + (22 if caption else 5), w - 10, h - (28 if caption else 10), preserveAspectRatio=True, anchor='c', mask='auto')
    if caption: txt(c, x + 9, y + 9, caption, 7.2, MUTED, True)

def pill(c, x, y, value, fill=GREEN, width=None):
    width = width or (len(value) * 4.9 + 18); c.setFillColor(fill); c.roundRect(x, y, width, 18, 9, fill=1, stroke=0); txt(c, x + 9, y + 6, value, 7, WHITE, True)

def status_card(c, x, y, w, title, value, detail=None):
    c.setFillColor(WHITE); c.setStrokeColor(PALE); c.roundRect(x, y, w, 58, 7, fill=1, stroke=1)
    txt(c, x + 10, y + 41, title.upper(), 7, MUTED, True); txt(c, x + 10, y + 23, value, 11, GREEN, True)
    if detail: txt(c, x + 10, y + 9, detail, 6.6, MUTED)

def node(c, x, y, w, h, title, sub, fill=WHITE, accent=CORAL):
    c.setFillColor(fill); c.setStrokeColor(PALE); c.roundRect(x, y, w, h, 8, fill=1, stroke=1); c.setFillColor(accent); c.roundRect(x, y + h - 5, w, 5, 3, fill=1, stroke=0)
    txt(c, x + 10, y + h - 22, title, 9, INK, True); wrap_text(c, x + 10, y + h - 38, sub, w - 20, 7.2, 10, MUTED)

def arrow(c, x1, y1, x2, y2):
    c.setStrokeColor(CORAL); c.setFillColor(CORAL); c.setLineWidth(1.4); c.line(x1, y1, x2, y2); c.line(x2, y2, x2 - 5, y2 + 3); c.line(x2, y2, x2 - 5, y2 - 3)

def page1(c):
    c.setFillColor(CREAM); c.rect(0, 0, W, H, fill=1, stroke=0); c.setFillColor(INK); c.rect(0, H - 320, W, 320, fill=1, stroke=0)
    label(c, 42, H - 48, "FitCalgary Index", CORAL); txt(c, 42, H - 92, "PHASE 2", 29, WHITE, True); txt(c, 42, H - 126, "CORE PRODUCT REVIEW", 22, WHITE, True)
    wrap_text(c, 42, H - 166, "A working FitCalgary product layer built on the tested Flutter, Go and PostgreSQL foundation.", 250, 10.5, 15, colors.HexColor("#D8D9D6")); pill(c, 42, H - 230, "READY FOR CLIENT REVIEW", CORAL, 142); txt(c, 42, H - 258, "September 2026  |  Phase 2 review", 7.5, colors.HexColor("#BFC1BD"))
    image_card(c, ART / "phase1-fresh/web-home.png", 330, H - 284, 240, 220, "Responsive web / FitCalgary home", colors.HexColor("#2A2D2E"))
    txt(c, 42, 414, "WHAT THIS MILESTONE ESTABLISHES", 8, CORAL, True); wrap_text(c, 42, 392, "The core product workflows now run through supported client surfaces and the Go/PostgreSQL service path: directory, pricing, clubs, events, profiles, boards, submissions, private evidence review, moderation and notifications.", 525, 11, 15, INK)
    cards = [("Flutter / Dart", "VERIFIED", "tests + analysis"), ("Go services", "VERIFIED", "tests / vet / build"), ("PostgreSQL", "VERIFIED", "8 migrations / import"), ("Auth + roles", "TESTED", "server enforced"), ("iOS", "SIMULATOR", "build + launch"), ("Android", "EMULATOR", "build + AAB"), ("Web", "VERIFIED", "type / lint / build"), ("Apple Watch", "SIMULATOR", "build + launch")]
    for i, (t, v, d) in enumerate(cards): status_card(c, 42 + (i % 4) * 132, 288 - (i // 4) * 70, 122, t, v, d)
    txt(c, 42, 134, "CENTRAL ACCEPTANCE PATH", 8, CORAL, True); txt(c, 42, 112, "submission  ->  private evidence  ->  correction or approval  ->  verified result  ->  official board  ->  notification", 8.3, INK, True); wrap_text(c, 42, 86, "Client-approved catalog integrated: 273 gyms, 743 clubs and 531 competitions. Physical devices, live provider credentials and store submission remain outside this local verification claim.", 525, 8.2, 11, MUTED); footer(c, 1); c.showPage()

def page2(c):
    c.setFillColor(CREAM); c.rect(0, 0, W, H, fill=1, stroke=0); label(c, 42, H - 48, "Product foundation", CORAL); txt(c, 42, H - 84, "The product in use.", 24, INK, True); wrap_text(c, 42, H - 110, "The Phase 2 build keeps the recognizable cream, black and coral editorial system while making the principal user journeys real and connected.", 490, 9.5, 13, MUTED)
    approved = ART / "phase2/client-data"
    image_card(c, approved / "gyms.png", 42, 392, 254, 260, "Client-approved gym directory"); image_card(c, approved / "gym-detail.png", 316, 392, 254, 260, "Structured pricing + gym detail")
    image_card(c, approved / "clubs.png", 42, 104, 254, 260, "Client-approved sport clubs"); image_card(c, approved / "events.png", 316, 104, 254, 260, "Client-approved competitions"); footer(c, 2); c.showPage()

def page3(c):
    c.setFillColor(CREAM); c.rect(0, 0, W, H, fill=1, stroke=0); label(c, 42, H - 48, "System proof", CORAL); txt(c, 42, H - 84, "One product path, one source of truth.", 23, INK, True); wrap_text(c, 42, H - 110, "The client surfaces share the same protected service contracts, authorization rules and production-shaped data model.", 510, 9.5, 13, MUTED)
    node(c, 42, 520, 150, 78, "CLIENTS", "iOS / Android / Web"); node(c, 231, 520, 150, 78, "APP LAYER", "Flutter / responsive routes"); node(c, 420, 520, 150, 78, "WATCH", "compact companion"); arrow(c, 192, 559, 231, 559); arrow(c, 381, 559, 420, 559)
    node(c, 137, 386, 170, 82, "GO SERVICE", "versioned API, validation, roles, workers"); node(c, 353, 386, 170, 82, "IDENTITY", "Keycloak OIDC / PKCE foundation"); arrow(c, 306, 520, 222, 468); arrow(c, 306, 520, 438, 468)
    node(c, 137, 248, 170, 82, "POSTGRESQL", "8 migrations + Client catalog"); node(c, 353, 248, 170, 82, "PRIVATE STORAGE", "ownership checks + signed playback"); arrow(c, 222, 386, 222, 330); arrow(c, 438, 386, 438, 330)
    rule(c, 42, 218, 528); txt(c, 42, 196, "VERIFICATION SNAPSHOT", 8, CORAL, True)
    checks = [("Flutter", "analysis + 20 tests", "PASS"), ("Go", "tests + vet + build", "PASS"), ("Database", "fresh init + migration/read-write path", "PASS"), ("Cross-platform", "iOS / Android / web / Watch", "PASS")]
    for i, (a, b, d) in enumerate(checks):
        x = 42 + (i % 2) * 265; y = 164 - (i // 2) * 42; c.setFillColor(WHITE); c.roundRect(x, y, 250, 30, 5, fill=1, stroke=0); txt(c, x + 9, y + 18, a, 7.5, INK, True); txt(c, x + 74, y + 18, b, 7, MUTED); txt(c, x + 212, y + 18, d, 7, GREEN, True)
    txt(c, 42, 62, "No production secrets are committed. Provider credentials and physical-device/store verification are explicitly separated from local evidence.", 7.5, MUTED); footer(c, 3); c.showPage()

def page4(c):
    c.setFillColor(CREAM); c.rect(0, 0, W, H, fill=1, stroke=0); label(c, 42, H - 48, "Acceptance matrix", CORAL); txt(c, 42, H - 84, "The required journeys are covered.", 23, INK, True); wrap_text(c, 42, H - 110, "The matrix below records the Phase 2 position using the exact status vocabulary: COMPLETE + VERIFIED, BLOCKED_EXTERNAL or INCOMPLETE.", 515, 9.5, 13, MUTED)
    groups = [("COMPLETE + VERIFIED", GREEN, ["1  Account, profile, saved gym and reload", "2  Directory, filters and structured comparison", "3  Client catalog: 273 gyms / 743 clubs / 531 competitions", "4  Community result to board and profile", "5  Submission -> evidence -> correction -> approval -> rank -> inbox", "6  Role/object denial and immediate revocation", "7  Moderation, preferences and notification outbox", "8  Shared client data path and Watch companion"]), ("BLOCKED_EXTERNAL", CORAL, ["Live Keycloak / SMTP / Google / Apple credentials", "FCM/APNs provider delivery credentials", "Physical devices, signed stores, hosting and DNS"])]
    y = 598
    for title, col, rows in groups:
        c.setFillColor(col); c.roundRect(42, y, 528, 24, 6, fill=1, stroke=0); txt(c, 53, y + 8, title, 8, WHITE, True); y -= 10
        for row in rows:
            c.setFillColor(WHITE); c.roundRect(42, y - 23, 528, 28, 5, fill=1, stroke=0); txt(c, 54, y - 10, row, 8, INK); txt(c, 540, y - 10, "PASS" if title.startswith("COMPLETE") else "EXTERNAL", 6.8, GREEN if title.startswith("COMPLETE") else CORAL, True); y -= 34
        y -= 12
    c.setFillColor(PALE); c.roundRect(42, 60, 528, 72, 8, fill=1, stroke=0); txt(c, 56, 110, "INCOMPLETE", 8, MUTED, True); txt(c, 56, 92, "No material Phase 2 acceptance item is currently classified as incomplete.", 10, INK, True); txt(c, 56, 76, "Release-only work is deliberately reserved for Phase 3 and is not presented as Phase 2 completion.", 7.5, MUTED); footer(c, 4); c.showPage()

def page5(c):
    c.setFillColor(CREAM); c.rect(0, 0, W, H, fill=1, stroke=0); label(c, 42, H - 48, "Boundaries and next step", CORAL); txt(c, 42, H - 84, "Ready for the next release phase.", 23, INK, True); image_card(c, ART / "phase1-fresh/watch-fresh-20260901.png", 428, 430, 142, 220, "Watch simulator")
    txt(c, 42, 620, "WHAT IS COMPLETE", 8, CORAL, True); wrap_text(c, 42, 600, "The Phase 2 core product is materially complete and verified in the local development/staging environment. Ramy's approved catalog is integrated through the production-shaped data model and visible in the product.", 360, 9.5, 13, INK)
    txt(c, 42, 510, "WHAT REMAINS EXTERNAL", 8, CORAL, True); wrap_text(c, 42, 490, "Production identity/provider credentials; hosting, storage, notification and store accounts; and physical-device access. These are dependencies, not hidden unfinished implementation.", 360, 9.5, 13, INK)
    txt(c, 42, 364, "PHASE 3 NEXT", 8, CORAL, True); wrap_text(c, 42, 344, "Release configuration, physical-device QA, signed archives/AAB, provider verification, performance/security review, store preparation, deployment and handoff documentation.", 528, 9.5, 13, INK)
    c.setFillColor(CORAL); c.roundRect(42, 176, 528, 108, 10, fill=1, stroke=0); txt(c, 60, 254, "PHASE 2 - READY FOR CLIENT REVIEW", 12, WHITE, True); wrap_text(c, 60, 231, "This package shows the working product, Client-approved catalog, tested service path and precise boundaries that remain external or belong to final release preparation. Client acceptance is not assumed.", 470, 9, 13, WHITE); txt(c, 60, 194, "Core product and Client catalog verified for Phase 2 review.", 7.5, colors.HexColor("#F7DDD7"), True); footer(c, 5); c.showPage()

def build():
    OUT.parent.mkdir(parents=True, exist_ok=True); c = canvas.Canvas(str(OUT), pagesize=letter, pageCompression=1); c.setTitle("FitCalgary Phase 2 Client Review"); page1(c); page2(c); page3(c); page4(c); page5(c); c.save(); print(OUT)

if __name__ == "__main__": build()
