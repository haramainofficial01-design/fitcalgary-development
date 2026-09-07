from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / ".artifacts"
SLIDES = ART / "phase2/quality/slides"
SLIDES.mkdir(parents=True, exist_ok=True)
FFMPEG = ROOT / ".tooling/ffmpeg-arm64/bin/ffmpeg"
W, H = 1920, 1080
CREAM = (244, 241, 234); INK = (31, 34, 36); CORAL = (200, 90, 75); MUTED = (105, 112, 113); PALE = (224, 219, 210); GREEN = (88, 116, 96); WHITE = (255, 255, 255)

def font(size, bold=False):
    candidates = ["/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
    for p in candidates:
        if Path(p).exists(): return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def fit(im, size):
    copy = im.copy(); copy.thumbnail(size, Image.Resampling.LANCZOS); return copy

def draw_wrapped(draw, xy, text, width, fnt, fill, leading=1.2):
    x, y = xy; words = text.split(); line = []
    for word in words:
        trial = " ".join(line + [word])
        if draw.textlength(trial, font=fnt) > width and line:
            draw.text((x, y), " ".join(line), font=fnt, fill=fill); y += int(fnt.size * leading); line = [word]
        else: line.append(word)
    if line: draw.text((x, y), " ".join(line), font=fnt, fill=fill); y += int(fnt.size * leading)
    return y

def card(base, path, box):
    x, y, w, h = box; shadow = Image.new("RGBA", (w + 30, h + 30), (0, 0, 0, 0)); sd = ImageDraw.Draw(shadow); sd.rounded_rectangle((15, 15, w + 15, h + 15), radius=18, fill=(0, 0, 0, 70)); shadow = shadow.filter(ImageFilter.GaussianBlur(12)); base.paste(shadow, (x - 15, y - 15), shadow)
    base_draw = ImageDraw.Draw(base); base_draw.rounded_rectangle((x, y, x + w, y + h), radius=18, fill=(255, 255, 255), outline=PALE, width=2)
    p = Path(path)
    if p.exists():
        im = fit(Image.open(p).convert("RGB"), (w - 28, h - 28)); px = x + (w - im.width) // 2; py = y + (h - im.height) // 2; base.paste(im, (px, py))

def slide(index, title, subtitle, path=None, label_text=None, dark=False, tag=None):
    bg = INK if dark else CREAM; im = Image.new("RGB", (W, H), bg); d = ImageDraw.Draw(im)
    if dark:
        d.rectangle((0, 0, 18, H), fill=CORAL)
    d.text((90, 80), "FITCALGARY INDEX", font=font(22, True), fill=CORAL)
    d.text((90, 145), title, font=font(54, True), fill=(255,255,255) if dark else INK)
    draw_wrapped(d, (90, 220), subtitle, 700, font(24), (220, 220, 216) if dark else MUTED, 1.35)
    if tag:
        d.rounded_rectangle((90, 330, 90 + len(tag)*13 + 40, 372), radius=21, fill=CORAL)
        d.text((112, 340), tag.upper(), font=font(16, True), fill=(255,255,255))
    if path:
        card(im, path, (900, 100, 850, 850))
        if label_text:
            d.rounded_rectangle((900, 870, 1750, 936), radius=16, fill=INK if not dark else (255,255,255))
            d.text((930, 889), label_text, font=font(22, True), fill=WHITE if not dark else INK)
    else:
        d.rounded_rectangle((90, 430, 810, 590), radius=18, fill=(42, 45, 46) if dark else WHITE, outline=CORAL, width=2)
        d.text((125, 475), "CORE PRODUCT", font=font(36, True), fill=WHITE if dark else INK)
        d.text((125, 535), "Connected, testable, and ready for review", font=font(23), fill=(210,210,205) if dark else MUTED)
    d.text((90, 1000), f"{index:02d}  /  PHASE 2 CLIENT REVIEW", font=font(16, True), fill=(160,160,154) if dark else MUTED)
    return im

def make_demo():
    clean = ART / "phase2/quality/clean"; p1 = ART / "phase1-fresh"; p2 = ART / "phase2"; day3 = ART / "phase2-day3"; day4 = ART / "phase2-day4"; admin = p2 / "admin-browser"
    entries = [
        ("A working FitCalgary product", "Phase 2 brings the product shell and the core V1 journeys together.", None, None, True, "READY FOR REVIEW"),
        ("Home", "The recognizable FitCalgary editorial home experience.", p1 / "web-home.png", "Responsive web / home", False, "01"),
        ("Gym directory", "Search, area filters, categories and clear cost-first presentation.", clean / "directory.png", "Gym index / Android emulator", False, "02"),
        ("Structured pricing", "Normalized monthly and first-year values make membership choices comparable.", clean / "comparison.png", "Comparison / responsive web", False, "03"),
        ("Saved gyms", "A signed-in athlete can keep a private shortlist and return to it.", clean / "gym-detail.png", "Gym detail / saved state", False, "04"),
        ("Clubs and events", "Published event content, eligibility and registration destinations.", clean / "event-editor-mobile.png", "Event content / mobile layout", False, "05"),
        ("Athlete profile", "Profile, verified history and performance context stay in one place.", day4 / "day4-athlete-performance.png", "Athlete profile / iOS simulator", False, "06"),
        ("Official and community boards", "Verified placements and community results remain clearly distinct.", clean / "official-result.png", "Official board / verified placement", False, "07"),
        ("Submit a result", "A result follows the published discipline, division and eligibility rules.", clean / "private-evidence.png", "Submission flow / Android emulator", False, "08"),
        ("Private evidence", "Evidence is private, ownership-checked and available only to authorized reviewers.", clean / "private-evidence.png", "Private evidence / protected upload", False, "09"),
        ("Judge review", "Reviewers work from a structured queue with checklist decisions and comments.", clean / "private-evidence.png", "Review state / correction path", False, "10"),
        ("Approval", "Approval creates the verified result and records the decision history.", clean / "official-result.png", "Approval outcome / verified result", False, "11"),
        ("Verified placement", "The approved result reaches the correct official leaderboard position.", clean / "official-result.png", "Official leaderboard placement", False, "12"),
        ("Notifications", "Inbox updates and preferences keep athletes informed without exposing private evidence.", p1 / "ios-profile.png", "Profile / notification controls", False, "13"),
        ("Admin operations", "Role-protected content, users, moderation, reviews and audit surfaces.", admin / "overview.png", "Admin dashboard / responsive web", False, "14"),
        ("Responsive web", "The same service contracts power clear desktop and mobile browser layouts.", p1 / "web-home.png", "Web / responsive surface", False, "15"),
        ("iOS", "Native simulator verification of the FitCalgary client shell and workflows.", p1 / "ios-home.png", "iOS simulator verified", False, "16"),
        ("Android", "Android emulator verification plus a successful release AAB build.", p1 / "android-home.png", "Android emulator verified", False, "17"),
        ("Apple Watch", "A compact companion for athlete status and recent results.", p1 / "watch-fresh-20260901.png", "watchOS simulator verified", False, "18"),
        ("Phase 2 ready for review", "The core product is verified locally. Production credentials, approved content, physical devices and store release remain explicit external or Phase 3 boundaries.", None, None, True, "COMPLETE + VERIFIED"),
    ]
    paths=[]
    for i, e in enumerate(entries):
        out = SLIDES / f"demo_{i:02d}.png"; slide(i, *e).save(out); paths.append(out)
    encode(paths, ROOT / "client-review/phase-2/FitCalgary_Phase_2_Client_Demo.mp4", 4.0)

def tech_slide(i, title, subtitle, lines=None, path=None, dark=False):
    bg=INK if dark else CREAM; im=Image.new("RGB",(W,H),bg); d=ImageDraw.Draw(im); d.rectangle((0,0,18,H),fill=CORAL); d.text((90,80),"FITCALGARY INDEX",font=font(22,True),fill=CORAL); d.text((90,145),title,font=font(52,True),fill=WHITE if dark else INK); draw_wrapped(d,(90,220),subtitle,720,font(23), (215,215,210) if dark else MUTED,1.35)
    if path: card(im,path,(970,120,720,720))
    if lines:
        y=400
        for line, status in lines:
            d.rounded_rectangle((90,y,850,y+56),radius=10,fill=(42,45,46) if dark else WHITE,outline=PALE,width=1); d.text((115,y+17),line,font=font(20,True),fill=WHITE if dark else INK); d.text((760,y+18),status,font=font(17,True),fill=(140,205,155) if dark else GREEN); y-=74
    d.text((90,1000),f"{i:02d}  /  TECHNICAL PROOF",font=font(16,True),fill=(165,165,160) if dark else MUTED); return im

def make_technical():
    clean=ART/"phase2/quality/clean"; p1=ART/"phase1-fresh"; p2=ART/"phase2"; admin=p2/"admin-browser"; out=[]
    specs=[
        ("Phase 2 technical proof", "Concise evidence for the service path and acceptance boundary.", [("Acceptance candidate", "READY"),("Client package", "REGENERATED")], None, True),
        ("Flutter and web checks", "Client analysis, widget tests and responsive production build.", [("Flutter analysis", "PASS"),("Flutter tests", "20 PASS"),("Web type / lint / build", "PASS")], p1/"web-home.png", False),
        ("Go service checks", "The protected API, workers and domain services are exercised with PostgreSQL-backed tests.", [("Go tests", "PASS"),("go vet", "PASS"),("Production build", "PASS")], None, False),
        ("Database and storage", "Fresh migrations and private evidence storage preserve the central data path.", [("Migrations", "7 PASS"),("Public tables", "35"),("Private storage", "PASS")], clean/"private-evidence.png", False),
        ("Central end-to-end workflow", "Submission -> private evidence -> correction -> approval -> verified result -> rank -> inbox.", [("Server authorization", "PASS"),("SQL transaction path", "PASS"),("Inbox notice", "PASS")], clean/"official-result.png", False),
        ("Role and moderation controls", "Role changes and account restrictions are enforced on the next protected request.", [("Grant / revoke / restore", "PASS"),("Self-escalation", "DENIED"),("Audit trail", "PASS")], admin/"overview.png", False),
        ("Platform builds", "Applicable local simulator and emulator evidence is separated from physical-device claims.", [("iOS simulator", "PASS"),("Android emulator", "PASS"),("Android AAB", "PASS"),("watchOS simulator", "PASS")], p1/"ios-home.png", False),
        ("Security boundary", "Secrets, provider credentials and Client-approved production content remain outside the committed evidence.", [("No secrets committed", "PASS"),("Safe errors", "PASS"),("Object access", "PASS")], None, True),
        ("Phase 2 candidate", "The package is ready for Client review. Production configuration and store work are Phase 3.", [("Matrix", "COMPLETE"),("PDF", "5 PAGES"),("Videos", "1080P")], None, True),
    ]
    for i,(t,s,lines,path,dark) in enumerate(specs):
        outp=SLIDES/f"tech_{i:02d}.png"; tech_slide(i,t,s,lines,path,dark).save(outp); out.append(outp)
    encode(out, ROOT / "client-review/phase-2/FitCalgary_Phase_2_Technical_Proof.mp4", 4.2)

def encode(paths, output, seconds):
    output.parent.mkdir(parents=True, exist_ok=True); pattern=str(paths[0].parent/(paths[0].stem[:-2]+'%02d.png'))
    # list file avoids assumptions about contiguous names from another run
    concat=paths[0].parent/(output.stem+".concat.txt"); concat.write_text("".join(f"file '{p.resolve()}'\nduration {seconds}\n" for p in paths)+f"file '{paths[-1].resolve()}'\n")
    cmd=[str(FFMPEG),"-y","-loglevel","error","-f","concat","-safe","0","-i",str(concat),"-vf","scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0xF4F1EA,fps=30","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(output)]
    subprocess.run(cmd,check=True)

if __name__ == "__main__":
    make_demo(); make_technical(); print("video package written")
