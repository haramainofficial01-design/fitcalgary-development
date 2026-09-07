from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".artifacts/phase2/quality/clean"
OUT.mkdir(parents=True, exist_ok=True)

def font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()

def cover(path, output, boxes, labels=()):
    im = Image.open(path).convert("RGB")
    draw = ImageDraw.Draw(im)
    for box, label in zip(boxes, labels):
        draw.rectangle(box, fill="#F4F1EA")
        x, y, _, _ = box
        draw.text((x + 8, y + 8), label, fill="#242628", font=font(18, True))
    im.save(output, quality=95)

def make_assets():
    cover(ROOT / ".artifacts/phase1-fresh/android-gyms-live.png", OUT / "directory.png",
          [(45, 1600, 1030, 2220)],
          ("City Fitness - Downtown",))
    cover(ROOT / ".artifacts/phase2/admin-browser/consumer-gym-details.png", OUT / "gym-detail.png",
          [(18, 250, 370, 410), (18, 490, 370, 710)],
          ("City Fitness - Downtown", "Standard membership  |  from $21 biweekly"))
    cover(ROOT / ".artifacts/phase2/admin-browser/gym-comparison.png", OUT / "comparison.png",
          [(20, 470, 370, 610), (20, 635, 370, 695)],
          ("City Fitness - Downtown", "Standard membership"))
    cover(ROOT / ".artifacts/phase2/admin-browser/verified-official-result.png", OUT / "official-result.png",
          [(70, 380, 350, 435)],
          ("Verified athlete",))
    cover(ROOT / ".artifacts/phase2/android-private-workflow.png", OUT / "private-evidence.png",
          [(45, 1915, 1035, 2085)],
          ("Private evidence attached",))
    cover(ROOT / ".artifacts/phase2/admin-browser/event-editor.png", OUT / "event-editor.png",
          [(285, 220, 1290, 330)],
          ("Calgary Open Series",))
    cover(ROOT / ".artifacts/phase2/admin-browser/mobile-event-editor.png", OUT / "event-editor-mobile.png",
          [(35, 180, 355, 300)],
          ("Calgary Open Series",))

if __name__ == "__main__":
    make_assets()
    print(OUT)
