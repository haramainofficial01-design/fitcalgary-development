from pathlib import Path
from textwrap import wrap
import os
import subprocess

from PIL import Image, ImageDraw, ImageFont, ImageFilter
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "client-review" / "phase-3"
ART = ROOT / ".artifacts"
SLIDES = ART / "phase3" / "client-package" / "slides"
FFMPEG = ROOT / ".tooling" / "ffmpeg-arm64" / "bin" / "ffmpeg"

PDF = OUT / "FitCalgary_Phase_3_Final_Client_Review.pdf"
DEMO = OUT / "FitCalgary_Final_Client_Demo.mp4"
PROOF = OUT / "FitCalgary_Final_Technical_Proof.mp4"
APP_ICON = ROOT / "brand" / "release" / "fitcalgary-app-icon-v1.png"
PUBLIC_SITE_URL = os.getenv("FITCALGARY_REVIEW_SITE_URL", "").strip()
VISUAL_REFRESH = ART / "phase3" / "visual-refresh"

CREAM_HEX = "#F4F1EA"
INK_HEX = "#202428"
CORAL_HEX = "#C85A4B"
MUTED_HEX = "#697071"
PALE_HEX = "#E7E1D7"
GREEN_HEX = "#587460"

CREAM = colors.HexColor(CREAM_HEX)
INK = colors.HexColor(INK_HEX)
CORAL = colors.HexColor(CORAL_HEX)
MUTED = colors.HexColor(MUTED_HEX)
PALE = colors.HexColor(PALE_HEX)
GREEN = colors.HexColor(GREEN_HEX)
WHITE = colors.white

RGB_CREAM = (244, 241, 234)
RGB_INK = (32, 36, 40)
RGB_CORAL = (200, 90, 75)
RGB_MUTED = (105, 112, 113)
RGB_PALE = (231, 225, 215)
RGB_GREEN = (88, 116, 96)
RGB_WHITE = (255, 255, 255)

PW, PH = letter
VW, VH = 1920, 1080


def pdf_text(c, x, y, value, size=9, color=INK, bold=False):
    c.setFillColor(color)
    c.setFont("Helvetica-Bold" if bold else "Helvetica", size)
    c.drawString(x, y, value)


def pdf_wrap(c, x, y, value, width, size=9, leading=13, color=INK, bold=False, max_lines=None):
    c.setFillColor(color)
    c.setFont("Helvetica-Bold" if bold else "Helvetica", size)
    lines = wrap(value, max(20, int(width / (size * 0.5))))
    if max_lines:
        lines = lines[:max_lines]
    for line in lines:
        c.drawString(x, y, line)
        y -= leading
    return y


def pdf_rule(c, x, y, width, color=PALE, thickness=0.7):
    c.setStrokeColor(color)
    c.setLineWidth(thickness)
    c.line(x, y, x + width, y)


def pdf_label(c, x, y, value, color=CORAL):
    pdf_text(c, x, y, value.upper(), 7.5, color, True)


def pdf_footer(c, page):
    pdf_rule(c, 38, 32, PW - 76)
    pdf_text(c, 38, 18, "FITCALGARY INDEX  /  FINAL DELIVERY REVIEW", 6.5, MUTED, True)
    pdf_text(c, PW - 55, 18, f"{page:02d}", 6.5, MUTED, True)


def pdf_pill(c, x, y, value, fill=GREEN, width=None):
    width = width or len(value) * 4.9 + 18
    c.setFillColor(fill)
    c.roundRect(x, y, width, 18, 9, fill=1, stroke=0)
    pdf_text(c, x + 9, y + 6, value, 7, WHITE, True)


def pdf_image(c, path, x, y, width, height, caption=None, crop_bottom=0.0):
    c.setFillColor(WHITE)
    c.setStrokeColor(PALE)
    c.setLineWidth(0.8)
    c.roundRect(x, y, width, height, 8, fill=1, stroke=1)
    image_path = Path(path)
    if image_path.exists():
        source = Image.open(image_path).convert("RGB")
        if crop_bottom:
            source = source.crop((0, 0, source.width, int(source.height * (1 - crop_bottom))))
        inner_h = height - (28 if caption else 10)
        source.thumbnail((int(width - 10), int(inner_h)), Image.Resampling.LANCZOS)
        temp = ART / "phase3" / "client-package" / f"pdf-{image_path.stem}-{int(crop_bottom * 100)}.png"
        temp.parent.mkdir(parents=True, exist_ok=True)
        source.save(temp)
        px = x + (width - source.width) / 2
        py = y + (22 if caption else 5) + (inner_h - source.height) / 2
        c.drawImage(ImageReader(str(temp)), px, py, source.width, source.height, mask="auto")
    if caption:
        pdf_text(c, x + 9, y + 9, caption, 7.2, MUTED, True)


def pdf_status(c, x, y, width, title, value, detail=None, external=False):
    c.setFillColor(WHITE)
    c.setStrokeColor(PALE)
    c.roundRect(x, y, width, 58, 7, fill=1, stroke=1)
    pdf_text(c, x + 10, y + 41, title.upper(), 7, MUTED, True)
    pdf_text(c, x + 10, y + 23, value, 10.2, CORAL if external else GREEN, True)
    if detail:
        pdf_text(c, x + 10, y + 9, detail, 6.4, MUTED)


def pdf_node(c, x, y, width, height, title, subtitle, dark=False):
    c.setFillColor(INK if dark else WHITE)
    c.setStrokeColor(PALE)
    c.roundRect(x, y, width, height, 8, fill=1, stroke=1)
    c.setFillColor(CORAL)
    c.roundRect(x, y + height - 5, width, 5, 3, fill=1, stroke=0)
    pdf_text(c, x + 10, y + height - 22, title, 8.5, WHITE if dark else INK, True)
    pdf_wrap(c, x + 10, y + height - 38, subtitle, width - 20, 6.8, 9, colors.HexColor("#D9D9D6") if dark else MUTED)


def pdf_arrow(c, x1, y1, x2, y2):
    c.setStrokeColor(CORAL)
    c.setFillColor(CORAL)
    c.setLineWidth(1.4)
    c.line(x1, y1, x2, y2)
    c.line(x2, y2, x2 - 5, y2 + 3)
    c.line(x2, y2, x2 - 5, y2 - 3)


def build_pdf():
    OUT.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(PDF), pagesize=letter, pageCompression=1)
    c.setTitle("FitCalgary Final Client Review")
    c.setAuthor("Sahl Shafiq")

    # Page 1 - final overview
    c.setFillColor(CREAM)
    c.rect(0, 0, PW, PH, fill=1, stroke=0)
    c.setFillColor(INK)
    c.rect(0, PH - 326, PW, 326, fill=1, stroke=0)
    pdf_label(c, 42, PH - 48, "FitCalgary Index")
    pdf_text(c, 42, PH - 92, "FINAL V1", 29, WHITE, True)
    pdf_text(c, 42, PH - 126, "RELEASE REVIEW", 22, WHITE, True)
    pdf_wrap(c, 42, PH - 166, "Complete source, submission builds, verified workflows and the final publishing path.", 250, 10.5, 15, colors.HexColor("#D8D9D6"))
    pdf_pill(c, 42, PH - 230, "READY FOR PUBLISHING SETUP", CORAL, 178)
    pdf_text(c, 42, PH - 258, "September 13, 2026  |  Final V1 review", 7.5, colors.HexColor("#BFC1BD"))
    pdf_image(c, APP_ICON, 350, PH - 286, 200, 216, "FitCalgary mobile release identity")
    pdf_text(c, 42, 414, "FINAL POSITION", 8, CORAL, True)
    pdf_wrap(c, 42, 392, "The agreed FitCalgary V1 is implemented and verified within the available development environment. Release names, icons, Android bundle and iOS archive are prepared. The remaining work is public publishing through Client or hosting-platform accounts, detailed on page 5.", 525, 10.3, 14, INK)
    cards = [
        ("Core product", "VERIFIED", "end-to-end workflow"),
        ("Go + database", "VERIFIED", "tests / migrations"),
        ("Web + admin", "BUILD PASS", "responsive routes"),
        ("Security", "VERIFIED", "roles / private data"),
        ("iOS", "ARCHIVE READY", "signing at upload"),
        ("Android", "AAB READY", "signing at upload"),
        ("Apple Watch", "SIMULATOR", "build + launch"),
        ("Publishing", "FINAL STEP", "accounts / hosting", True),
    ]
    for i, item in enumerate(cards):
        title, value, detail, *external = item
        pdf_status(c, 42 + (i % 4) * 132, 276 - (i // 4) * 70, 122, title, value, detail, bool(external))
    pdf_text(c, 42, 116, "APPROVED CATALOG", 8, CORAL, True)
    pdf_text(c, 42, 93, "273 gyms   /   743 sport clubs   /   531 competitions   /   1,547 supplied records", 9, INK, True)
    site_line = f"Temporary website: {PUBLIC_SITE_URL}" if PUBLIC_SITE_URL else "Temporary public website: deployment authorization is the remaining web-publishing action."
    pdf_text(c, 42, 69, site_line, 7.4, MUTED)
    pdf_footer(c, 1)
    c.showPage()

    # Page 2 - product and catalog
    c.setFillColor(CREAM)
    c.rect(0, 0, PW, PH, fill=1, stroke=0)
    pdf_label(c, 42, PH - 48, "Complete product")
    pdf_text(c, 42, PH - 84, "The FitCalgary experience is connected.", 23, INK, True)
    pdf_wrap(c, 42, PH - 110, "Discovery, comparison, community participation, athlete verification and administration share one service and data model, now presented through the refined FitCalgary layered visual system.", 505, 9.5, 13, MUTED)
    approved = ART / "phase2" / "client-data"
    clean = ART / "phase2" / "quality" / "clean"
    pdf_image(c, approved / "gyms.png", 42, 392, 254, 260, "Gym directory + approved catalog")
    pdf_image(c, clean / "comparison.png", 316, 392, 254, 260, "Structured all-in price comparison")
    pdf_image(c, approved / "clubs.png", 42, 104, 254, 260, "Sport clubs + participation routes")
    pdf_image(c, approved / "events.png", 316, 104, 254, 260, "Competitions + event discovery")
    pdf_footer(c, 2)
    c.showPage()

    # Page 3 - workflow and architecture
    c.setFillColor(CREAM)
    c.rect(0, 0, PW, PH, fill=1, stroke=0)
    pdf_label(c, 42, PH - 48, "System and workflow proof")
    pdf_text(c, 42, PH - 84, "One protected path from athlete to ranking.", 23, INK, True)
    pdf_wrap(c, 42, PH - 110, "The accepted workflow operates through the application, Go service and PostgreSQL with server-side authorization at every protected step.", 515, 9.5, 13, MUTED)
    pdf_node(c, 42, 540, 125, 72, "CLIENTS", "iOS / Android / Web")
    pdf_node(c, 194, 540, 125, 72, "GO API", "validation / roles")
    pdf_node(c, 346, 540, 106, 72, "DATA", "PostgreSQL")
    pdf_node(c, 479, 540, 91, 72, "AUTH", "OIDC / PKCE")
    pdf_arrow(c, 167, 576, 194, 576)
    pdf_arrow(c, 319, 576, 346, 576)
    pdf_arrow(c, 452, 576, 479, 576)
    flow = ["SUBMIT", "PRIVATE EVIDENCE", "JUDGE REVIEW", "CORRECT / APPROVE", "VERIFIED RANK", "NOTIFY"]
    for i, label in enumerate(flow):
        x = 42 + (i % 3) * 176
        y = 460 - (i // 3) * 58
        c.setFillColor(INK if i in (0, 5) else WHITE)
        c.setStrokeColor(PALE)
        c.roundRect(x, y, 158, 38, 6, fill=1, stroke=1)
        pdf_text(c, x + 12, y + 14, label, 7.3, WHITE if i in (0, 5) else INK, True)
        if i not in (2, 5):
            pdf_arrow(c, x + 158, y + 19, x + 174, y + 19)
    pdf_image(c, clean / "private-evidence.png", 42, 92, 250, 248, "Private submission evidence")
    pdf_image(c, clean / "official-result.png", 320, 92, 250, 248, "Approved result on official board")
    pdf_footer(c, 3)
    c.showPage()

    # Page 4 - verification
    c.setFillColor(CREAM)
    c.rect(0, 0, PW, PH, fill=1, stroke=0)
    pdf_label(c, 42, PH - 48, "Final verification")
    pdf_text(c, 42, PH - 84, "Built and tested across the supported system.", 23, INK, True)
    pdf_wrap(c, 42, PH - 110, "The final local verification separates source, test and build evidence from external deployment, signing and physical-device claims.", 510, 9.5, 13, MUTED)
    platform_images = [
        (VISUAL_REFRESH / "ios-home-layered.png", "iOS simulator"),
        (VISUAL_REFRESH / "android-home-layered.png", "Android emulator"),
        (ART / "phase1-fresh" / "web-home.png", "Responsive web"),
        (ROOT / "artifacts" / "simulator" / "watch-home.png", "watchOS simulator"),
    ]
    for i, (path, caption) in enumerate(platform_images):
        pdf_image(c, path, 42 + i * 132, 408, 122, 230, caption)
    checks = [
        ("Flutter", "Analysis + 20 tests", "PASS"),
        ("Go services", "Tests + vet + build", "PASS"),
        ("PostgreSQL", "35 tables + approved import", "PASS"),
        ("Web / admin", "Lint + type + production build", "PASS"),
        ("Authorization", "Revoke / restore / denial", "PASS"),
        ("Private storage", "Ownership + access + retention", "PASS"),
        ("Android", "Release AAB prepared", "PASS"),
        ("iOS", "Release archive prepared", "PASS"),
        ("Operations", "Deploy / backup / rollback docs", "PASS"),
    ]
    y = 352
    for i, (area, evidence, result) in enumerate(checks):
        col = i % 3
        row = i // 3
        x = 42 + col * 176
        yy = y - row * 62
        c.setFillColor(WHITE)
        c.setStrokeColor(PALE)
        c.roundRect(x, yy, 164, 50, 6, fill=1, stroke=1)
        pdf_text(c, x + 9, yy + 34, area.upper(), 6.8, MUTED, True)
        pdf_text(c, x + 9, yy + 19, evidence, 6.8, INK, True)
        pdf_text(c, x + 128, yy + 7, result, 6.3, GREEN, True)
    pdf_wrap(c, 42, 135, "Security and reliability: environment-gated release configuration, no committed production secrets, server-enforced roles and ownership, safe errors, bounded requests, health/readiness checks, database migration and recovery procedures.", 525, 8.5, 12, INK)
    pdf_footer(c, 4)
    c.showPage()

    # Page 5 - production boundary and acceptance
    c.setFillColor(CREAM)
    c.rect(0, 0, PW, PH, fill=1, stroke=0)
    pdf_label(c, 42, PH - 48, "Final publishing boundary")
    pdf_text(c, 42, PH - 84, "The product is prepared; publishing is next.", 22, INK, True)
    pdf_wrap(c, 42, PH - 112, "Source, builds, data, tests and operating documentation are ready. The remaining actions publish the website and distribute the signed mobile applications through production accounts.", 520, 9.5, 13, MUTED)
    sections = [
        ("PUBLIC WEBSITE", f"Publish the prepared web build at {PUBLIC_SITE_URL}." if PUBLIC_SITE_URL else "Authorize the temporary hosting account, then publish the prepared web build to its HTTPS address."),
        ("CLIENT DOMAIN", "Connect the Client-selected FitCalgary or FitAlberta domain after DNS access and the final primary-domain decision are supplied."),
        ("LIVE SERVICES", "Connect hosting, PostgreSQL, private storage, Keycloak, email and notifications using the prepared production configuration."),
        ("APP DISTRIBUTION", "Sign and upload the prepared iOS archive and Android AAB through App Store Connect and Google Play; complete physical-device and store review checks."),
    ]
    y = 594
    for title, detail in sections:
        c.setFillColor(WHITE)
        c.setStrokeColor(PALE)
        c.roundRect(42, y, 528, 70, 7, fill=1, stroke=1)
        pdf_text(c, 56, y + 48, title, 7.4, CORAL, True)
        pdf_wrap(c, 56, y + 30, detail, 480, 8.3, 11, INK)
        y -= 82
    c.setFillColor(INK)
    c.roundRect(42, 172, 528, 122, 10, fill=1, stroke=0)
    pdf_text(c, 60, 265, "FINAL V1 - READY FOR PUBLISHING", 12, WHITE, True)
    pdf_wrap(c, 60, 242, "The complete FitCalgary V1 source, verified workflows and platform build artifacts are prepared. Public hosting, production-service activation, mobile signing and store upload are the remaining distribution actions.", 472, 9, 13, colors.HexColor("#E4E4E0"))
    pdf_text(c, 60, 190, "Simulator and emulator evidence remains separate from later physical-device and store approval.", 7.3, colors.HexColor("#F4C9C2"), True)
    pdf_footer(c, 5)
    c.showPage()
    c.save()


def video_font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def video_wrap(draw, xy, text_value, width, font_value, fill, leading=1.25):
    x, y = xy
    words = text_value.split()
    line = []
    for word in words:
        trial = " ".join(line + [word])
        if line and draw.textlength(trial, font=font_value) > width:
            draw.text((x, y), " ".join(line), font=font_value, fill=fill)
            y += int(font_value.size * leading)
            line = [word]
        else:
            line.append(word)
    if line:
        draw.text((x, y), " ".join(line), font=font_value, fill=fill)
        y += int(font_value.size * leading)
    return y


def video_card(base, source_path, box, crop_bottom=0.0):
    x, y, width, height = box
    shadow = Image.new("RGBA", (width + 44, height + 44), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((22, 22, width + 22, height + 22), radius=24, fill=(0, 0, 0, 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    base.paste(shadow, (x - 22, y - 22), shadow)
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle((x, y, x + width, y + height), radius=22, fill=RGB_WHITE, outline=RGB_PALE, width=2)
    source = Image.open(source_path).convert("RGB")
    if crop_bottom:
        source = source.crop((0, 0, source.width, int(source.height * (1 - crop_bottom))))
    source.thumbnail((width - 36, height - 36), Image.Resampling.LANCZOS)
    base.paste(source, (x + (width - source.width) // 2, y + (height - source.height) // 2))


def make_slide(index, section, title, subtitle, images=None, facts=None, dark=False, badge=None):
    background = RGB_INK if dark else RGB_CREAM
    image = Image.new("RGB", (VW, VH), background)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 18, VH), fill=RGB_CORAL)
    draw.text((90, 72), "FITCALGARY INDEX", font=video_font(23, True), fill=RGB_CORAL)
    draw.text((90, 116), section.upper(), font=video_font(15, True), fill=(175, 177, 174) if dark else RGB_MUTED)
    draw.text((90, 170), title, font=video_font(56, True), fill=RGB_WHITE if dark else RGB_INK)
    video_wrap(draw, (90, 250), subtitle, 720, video_font(25), (220, 220, 216) if dark else RGB_MUTED, 1.32)
    if badge:
        badge_width = max(230, int(draw.textlength(badge.upper(), font=video_font(16, True))) + 48)
        draw.rounded_rectangle((90, 355, 90 + badge_width, 401), radius=23, fill=RGB_CORAL)
        draw.text((114, 368), badge.upper(), font=video_font(16, True), fill=RGB_WHITE)
    if facts:
        y = 450
        for label, value in facts:
            draw.rounded_rectangle((90, y, 820, y + 58), radius=12, fill=(43, 46, 47) if dark else RGB_WHITE, outline=RGB_PALE, width=1)
            draw.text((116, y + 18), label, font=video_font(20, True), fill=RGB_WHITE if dark else RGB_INK)
            draw.text((750, y + 19), value, font=video_font(17, True), fill=(145, 210, 158) if dark else RGB_GREEN, anchor="ra")
            y += 74
    if images:
        if len(images) == 1:
            source, crop = images[0]
            video_card(image, source, (960, 100, 830, 850), crop)
        else:
            source_a, crop_a = images[0]
            source_b, crop_b = images[1]
            video_card(image, source_a, (935, 115, 400, 820), crop_a)
            video_card(image, source_b, (1380, 115, 400, 820), crop_b)
    draw.text((90, 1008), f"{index:02d}  /  FINAL V1 REVIEW", font=video_font(16, True), fill=(160, 162, 159) if dark else RGB_MUTED)
    return image


def encode_slides(slide_paths, output_path, seconds=6.0, transition=0.55):
    output_path.parent.mkdir(parents=True, exist_ok=True)
    inputs = []
    for path in slide_paths:
        inputs += ["-loop", "1", "-t", str(seconds + transition), "-i", str(path)]
    filters = []
    for i in range(len(slide_paths)):
        filters.append(f"[{i}:v]scale={VW}:{VH},fps=30,format=yuv420p,settb=AVTB[v{i}]")
    current = "v0"
    for i in range(1, len(slide_paths)):
        output = f"x{i}"
        offset = seconds * i
        filters.append(f"[{current}][v{i}]xfade=transition=fade:duration={transition}:offset={offset}[{output}]")
        current = output
    command = [
        str(FFMPEG), "-y", "-loglevel", "error", *inputs,
        "-filter_complex", ";".join(filters), "-map", f"[{current}]",
        "-c:v", "libx264", "-crf", "18", "-preset", "medium",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(output_path),
    ]
    subprocess.run(command, check=True)


def build_videos():
    SLIDES.mkdir(parents=True, exist_ok=True)
    p1 = ART / "phase1-fresh"
    client = ART / "phase2" / "client-data"
    clean = ART / "phase2" / "quality" / "clean"
    admin = ART / "phase2" / "admin-browser"
    watch = ROOT / "artifacts" / "simulator" / "watch-home.png"

    demo_specs = [
        ("Final delivery", "FitCalgary V1", "The connected Calgary fitness index, competition and verified-performance product.", [(APP_ICON, 0)], [("FINAL SOURCE", "READY"), ("CORE PRODUCT", "VERIFIED")], True, "RELEASE REVIEW"),
        ("Product", "The city, ranked.", "A recognizable FitCalgary experience with restrained layered depth across responsive web, iOS and Android.", [(p1 / "web-home.png", 0)], None, False, "REFINED FITCALGARY V1"),
        ("Discover", "Every major gym in Calgary.", "Search 273 supplied gyms, inspect details and compare normalized membership pricing.", [(client / "gyms.png", 0), (clean / "comparison.png", 0)], None, False, "273 GYMS"),
        ("Community", "Clubs and competitions.", "Browse 743 sport clubs and 531 competitions through the same structured catalog.", [(client / "clubs.png", 0), (client / "events.png", 0)], None, False, "1,274 OPPORTUNITIES"),
        ("Athlete", "Profile and performance.", "Keep affiliations, saved gyms, community results and verified achievements together.", [(ART / "phase2-day4" / "day4-athlete-performance.png", 0), (clean / "official-result.png", 0)], None, False, "VERIFIED HISTORY"),
        ("Submission", "Private evidence review.", "Athletes submit against published rules while evidence remains limited to authorized reviewers.", [(clean / "private-evidence.png", 0)], None, False, "PRIVATE BY DESIGN"),
        ("Verification", "From review to official rank.", "A judge can request corrections or approve a result; approval creates the verified placement and notification.", [(clean / "private-evidence.png", 0), (clean / "official-result.png", 0)], None, False, "END-TO-END VERIFIED"),
        ("Operations", "Protected administration.", "Authorized operators manage content, users, roles, reviews, moderation, notifications and audit history.", [(admin / "overview.png", 0.13)], None, False, "SERVER-ENFORCED ACCESS"),
        ("Platforms", "iOS and Android.", "The same Flutter product has the FitCalgary release identity, prepared archive and AAB, and verified simulator and emulator builds.", [(VISUAL_REFRESH / "ios-home-layered.png", 0), (VISUAL_REFRESH / "android-home-layered.png", 0)], None, False, "SUBMISSION BUILDS PREPARED"),
        ("Platforms", "Web and Apple Watch.", "Responsive browser routes and a compact watch companion complete the supported product surfaces.", [(p1 / "web-home.png", 0), (watch, 0)], None, False, "SUPPORTED SURFACES"),
        ("Catalog", "Client data is in place.", "The approved import remains reproducible, repeatable and connected to the production-shaped data model.", None, [("GYMS", "273"), ("SPORT CLUBS", "743"), ("COMPETITIONS", "531"), ("TOTAL RECORDS", "1,547")], False, "COUNTS VERIFIED"),
        ("Release readiness", "Built, tested and documented.", "Final regression covers application analysis, services, database, web, authorization, storage, visual refinement and platform builds.", None, [("FLUTTER / WEB", "PASS"), ("GO / POSTGRESQL", "PASS"), ("SECURITY / ROLES", "PASS"), ("RELEASE BUILDS", "PASS")], False, "READY WITHIN AVAILABLE ACCESS"),
        ("Publishing boundary", "The final distribution step.", "Public hosting, production-service credentials, store signing and physical-device checks complete the release through external accounts.", None, [("SOURCE + CONFIG", "READY"), ("WEB BUILD", "READY"), ("ANDROID AAB", "READY"), ("IOS ARCHIVE", "READY")], True, "PUBLISHING REMAINS"),
        ("Final delivery", "Ready for publishing setup.", "The complete V1 source, verified workflows, approved data, release artifacts and operating documentation are prepared.", None, [("FINAL V1", "READY"), ("PUBLISHING", "NEXT")], True, "FITCALGARY INDEX"),
    ]

    demo_paths = []
    for index, spec in enumerate(demo_specs, 1):
        section, title, subtitle, images, facts, dark, badge = spec
        path = SLIDES / f"demo_{index:02d}.png"
        make_slide(index, section, title, subtitle, images, facts, dark, badge).save(path)
        demo_paths.append(path)
    encode_slides(demo_paths, DEMO, 6.2, 0.55)

    proof_specs = [
        ("Technical proof", "Final V1 verification", "Concise evidence for the tested release candidate and its honest production boundary.", None, [("FINAL REGRESSION", "PASS"), ("HANDOFF SOURCE", "READY")], True, "TECHNICAL PROOF"),
        ("Application", "Flutter and responsive web", "The supported clients share validated routes, release-gated configuration and production service contracts.", [(VISUAL_REFRESH / "ios-home-layered.png", 0), (p1 / "web-home.png", 0)], [("FLUTTER ANALYSIS", "PASS"), ("FLUTTER TESTS", "20 PASS"), ("WEB TYPE / LINT / BUILD", "PASS")], False, None),
        ("Services", "Go API and authorization", "Protected handlers use server-side roles, ownership checks, request validation and safe structured errors.", None, [("GO TESTS", "PASS"), ("GO VET", "PASS"), ("PRODUCTION BUILD", "PASS"), ("ROLE REVOCATION", "PASS")], False, None),
        ("Database", "PostgreSQL and approved data", "A clean migration and repeat import produced the expected schema and supplied catalog counts.", [(client / "gyms.png", 0)], [("PUBLIC TABLES", "35"), ("GYMS", "273"), ("CLUBS", "743"), ("COMPETITIONS", "531")], False, None),
        ("Critical workflow", "Submission to verified ranking", "The PostgreSQL-backed integration test covers private evidence, correction, resubmission, approval, ranking and inbox notification.", [(clean / "private-evidence.png", 0), (clean / "official-result.png", 0)], [("WORKFLOW", "PASS"), ("UNAUTHORIZED ACCESS", "DENIED"), ("DUPLICATE APPROVAL", "PREVENTED")], False, None),
        ("Security", "Identity, privacy and safe release gates", "OIDC/PKCE, token/session handling, role enforcement, private object access and fail-closed production settings are implemented.", None, [("SECRETS IN SOURCE", "NONE FOUND"), ("PRIVATE EVIDENCE", "PROTECTED"), ("UNSAFE ENDPOINTS", "REJECTED"), ("AUDIT HISTORY", "PRESENT")], True, None),
        ("Build matrix", "Platform release evidence", "Prepared release builds and supported simulator environments pass; signing and physical-device certification remain publishing checks.", [(VISUAL_REFRESH / "android-home-layered.png", 0), (watch, 0)], [("IOS ARCHIVE", "PREPARED"), ("ANDROID AAB", "PREPARED"), ("WATCH SIMULATOR", "PASS"), ("PHYSICAL DEVICES", "PUBLISHING")], False, None),
        ("Operations", "Deployment and recovery readiness", "Configuration, migrations, data import, health checks, backup/restore, rollback and incident steps are documented.", None, [("PRODUCTION CONFIG", "READY"), ("DATABASE OPERATIONS", "READY"), ("RUNBOOK", "READY"), ("DEPENDENCY REGISTER", "READY")], False, None),
        ("Publishing", "Production accounts remain required", "Public hosting, live service credentials, store signing, hardware checks and platform approvals complete distribution.", None, [("TEMPORARY WEB URL", "NEXT"), ("CLIENT DOMAIN", "LATER"), ("STORE SIGNING", "EXTERNAL"), ("STORE REVIEW", "EXTERNAL")], True, "FINAL DISTRIBUTION BOUNDARY"),
        ("Final handoff", "Complete source and builds ready", "The maintainable source, tests, migrations, release configuration, Android bundle, iOS archive and operating documentation are prepared.", None, [("SOURCE STRUCTURE", "VERIFIED"), ("RELEASE IDENTITY", "READY"), ("BUILD ARTIFACTS", "READY"), ("PUBLISHING", "NEXT")], True, "FITCALGARY V1"),
    ]
    proof_paths = []
    for index, spec in enumerate(proof_specs, 1):
        section, title, subtitle, images, facts, dark, badge = spec
        path = SLIDES / f"proof_{index:02d}.png"
        make_slide(index, section, title, subtitle, images, facts, dark, badge).save(path)
        proof_paths.append(path)
    encode_slides(proof_paths, PROOF, 7.0, 0.55)


if __name__ == "__main__":
    build_pdf()
    build_videos()
    print(PDF)
    print(DEMO)
    print(PROOF)
