from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CAPTURES = ROOT / ".artifacts/phase1-fresh"
WORK = ROOT / "tmp/client-review/final-video"
OUTPUT = ROOT / "client-review/phase-1"
FFMPEG = ROOT / ".tooling/ffmpeg-arm64/bin/ffmpeg"

WIDTH, HEIGHT = 1920, 1080
PAPER = "#F6F3ED"
INK = "#17191B"
BLACK = "#111214"
CORAL = "#C95C4B"
GREEN = "#2F725B"
MUTED = "#6E6D69"
LINE = "#CAC6BE"
FONT = "/System/Library/Fonts/Helvetica.ttc"


def typeface(size: int, bold: bool = False):
    return ImageFont.truetype(FONT, size=size, index=1 if bold else 0)


def wrap(draw: ImageDraw.ImageDraw, text: str, width: int, font) -> list[str]:
    lines: list[str] = []
    current: list[str] = []
    for word in text.split():
        trial = " ".join(current + [word])
        if current and draw.textbbox((0, 0), trial, font=font)[2] > width:
            lines.append(" ".join(current))
            current = [word]
        else:
            current.append(word)
    if current:
        lines.append(" ".join(current))
    return lines


def paragraph(draw: ImageDraw.ImageDraw, text: str, x: int, y: int, width: int, font, fill: str, leading: int = 12) -> int:
    for line in wrap(draw, text, width, font):
        draw.text((x, y), line, font=font, fill=fill)
        y += font.size + leading
    return y


def base(section: str) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", (WIDTH, HEIGHT), PAPER)
    draw = ImageDraw.Draw(image)
    draw.text((76, 43), "FITCALGARY", font=typeface(32, True), fill=INK)
    draw.text((315, 54), "I N D E X", font=typeface(15, True), fill=INK)
    draw.text((1844, 54), section.upper(), font=typeface(16, True), fill=CORAL, anchor="ra")
    draw.line((76, 102, 1844, 102), fill=INK, width=2)
    return image, draw


def footer(draw: ImageDraw.ImageDraw, proof: bool = False) -> None:
    draw.text((76, 1027), "FitCalgary Index - Phase 1", font=typeface(16), fill=MUTED)
    draw.text((1844, 1027), "TECHNICAL PROOF" if proof else "CLIENT DEMONSTRATION", font=typeface(16, True), fill=MUTED, anchor="ra")


def pill(draw: ImageDraw.ImageDraw, text: str, x: int, y: int, fill: str = GREEN) -> None:
    font = typeface(24, True)
    width = draw.textbbox((0, 0), text, font=font)[2] + 54
    draw.rounded_rectangle((x, y, x + width, y + 54), radius=27, fill=fill)
    draw.text((x + 27, y + 13), text, font=font, fill="white")


def save_title(name: str, title: str, body: str, status: str, *, proof: bool = False) -> Path:
    image, draw = base("Technical proof" if proof else "Client demonstration")
    draw.rectangle((0, 103, WIDTH, HEIGHT), fill=BLACK)
    draw.text((100, 235), "PHASE 1 - FOUNDATION + PRODUCT", font=typeface(24, True), fill="#F08370")
    y = paragraph(draw, title, 100, 300, 1580, typeface(78, True), "white", 8)
    y = paragraph(draw, body, 100, y + 45, 1430, typeface(31), "#D4D2CD", 12)
    pill(draw, status, 100, y + 58, CORAL)
    draw.text((100, 985), "FITCALGARY INDEX", font=typeface(22, True), fill="white")
    target = WORK / f"{name}.png"
    image.save(target)
    return target


def place(image: Image.Image, source: Path, box: tuple[int, int, int, int], background: str = "white") -> None:
    x, y, width, height = box
    picture = Image.open(source).convert("RGB")
    picture.thumbnail((width, height), Image.Resampling.LANCZOS)
    frame = Image.new("RGB", (width, height), background)
    frame.paste(picture, ((width - picture.width) // 2, (height - picture.height) // 2))
    image.paste(frame, (x, y))


def save_visual(
    name: str,
    section: str,
    title: str,
    body: str,
    visuals: list[tuple[Path, str]],
    status: str,
    *,
    proof: bool = False,
) -> Path:
    image, draw = base(section)
    draw.text((76, 148), title, font=typeface(54, True), fill=INK)
    paragraph(draw, body, 76, 220, 1460, typeface(26), MUTED, 8)
    pill(draw, status, 1510, 145, GREEN)
    count = len(visuals)
    gap = 32
    card_width = (WIDTH - 152 - gap * (count - 1)) // count
    for index, (source, label) in enumerate(visuals):
        x = 76 + index * (card_width + gap)
        draw.rounded_rectangle((x, 310, x + card_width, 970), radius=18, fill="white", outline=LINE, width=2)
        draw.text((x + 25, 334), label.upper(), font=typeface(21, True), fill=CORAL)
        place(image, source, (x + 25, 378, card_width - 50, 565), BLACK if "watch" in source.name else "white")
    footer(draw, proof)
    target = WORK / f"{name}.png"
    image.save(target)
    return target


def save_results(name: str, section: str, title: str, intro: str, items: list[tuple[str, str]], *, proof: bool = True) -> Path:
    image, draw = base(section)
    draw.text((76, 148), title, font=typeface(54, True), fill=INK)
    paragraph(draw, intro, 76, 220, 1660, typeface(26), MUTED, 8)
    y = 340
    for label, result in items:
        draw.line((76, y + 52, 1844, y + 52), fill=LINE, width=2)
        draw.text((76, y), label, font=typeface(30), fill=INK)
        draw.text((1844, y), result, font=typeface(27, True), fill=GREEN, anchor="ra")
        y += 76
    footer(draw, proof)
    target = WORK / f"{name}.png"
    image.save(target)
    return target


def save_architecture(name: str, *, proof: bool = False) -> Path:
    image, draw = base("Connected foundation")
    draw.text((76, 145), "One application system, connected end to end.", font=typeface(54, True), fill=INK)
    draw.text((76, 218), "The current Flutter client reads and writes development data through the Go API and PostgreSQL.", font=typeface(26), fill=MUTED)
    nodes = [
        (90, 345, 300, 125, "Flutter / Dart", PAPER, INK),
        (510, 345, 300, 125, "Versioned Go API", CORAL, "white"),
        (930, 345, 300, 125, "PostgreSQL", PAPER, INK),
        (510, 650, 300, 125, "Keycloak OIDC", PAPER, INK),
    ]
    for x, y, width, height, label, fill, text in nodes:
        draw.rounded_rectangle((x, y, x + width, y + height), radius=18, fill=fill, outline=INK, width=2)
        draw.text((x + width // 2, y + height // 2), label, font=typeface(29, True), fill=text, anchor="mm")
    draw.text((444, 407), ">", font=typeface(58, True), fill=CORAL, anchor="mm")
    draw.text((864, 407), ">", font=typeface(58, True), fill=CORAL, anchor="mm")
    draw.line((660, 470, 660, 650), fill=INK, width=3)
    draw.text((1300, 350), "VERIFIED DEVELOPMENT RESULT", font=typeface(21, True), fill=CORAL)
    facts = [
        "30-table schema initialized from migrations",
        "Gym record returned through the service",
        "Client showed normalized development value",
        "Admin access: 401 / 403 / 200 as expected",
    ]
    y = 405
    for fact in facts:
        draw.rounded_rectangle((1310, y + 8, 1331, y + 29), radius=5, fill=GREEN)
        y = paragraph(draw, fact, 1360, y, 440, typeface(25), INK, 8) + 20
    footer(draw, proof)
    target = WORK / f"{name}.png"
    image.save(target)
    return target


def run(command: list[str]) -> None:
    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode:
        raise RuntimeError(completed.stderr[-5000:])


def still(source: Path, seconds: int, target: Path) -> None:
    run([
        str(FFMPEG), "-y", "-loop", "1", "-framerate", "30", "-i", str(source), "-t", str(seconds),
        "-vf", "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0xF6F3ED",
        "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "21", "-pix_fmt", "yuv420p", "-r", "30", str(target),
    ])


def live(source: Path, seconds: int, target: Path, *, start: int = 0) -> None:
    run([
        str(FFMPEG), "-y", "-ss", str(start), "-i", str(source), "-t", str(seconds),
        "-map", "0:v:0", "-vf", "scale=1540:980:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x111214",
        "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "21", "-pix_fmt", "yuv420p", "-r", "30", str(target),
    ])


def assemble(filename: str, segments: list[tuple[str, Path, int, int]]) -> Path:
    segment_paths: list[Path] = []
    for index, (kind, source, start, seconds) in enumerate(segments):
        target = WORK / f"{Path(filename).stem}-{index:02d}.mp4"
        if kind == "still":
            still(source, seconds, target)
        else:
            live(source, seconds, target, start=start)
        segment_paths.append(target)
    manifest = WORK / f"{Path(filename).stem}.txt"
    manifest.write_text("".join(f"file '{path}'\n" for path in segment_paths), encoding="utf-8")
    output = OUTPUT / filename
    run([
        str(FFMPEG), "-y", "-f", "concat", "-safe", "0", "-i", str(manifest), "-c", "copy", "-movflags", "+faststart",
        "-metadata", "title=FitCalgary Phase 1 Review", "-metadata", "artist=Sahl Shafiq", str(output),
    ])
    return output


def validate_inputs() -> None:
    required = [
        "android-demo-clean.mp4",
        "ios-demo-clean.mp4",
        "web-demo-real.webm",
        "ios-onboarding.png",
        "android-gyms-live.png",
        "web-home.png",
        "web-admin-denied.png",
        "web-admin-overview.png",
        "watch-home.png",
    ]
    missing = [item for item in required if not (CAPTURES / item).is_file()]
    if missing:
        raise RuntimeError(f"Missing Phase 1 video input(s): {', '.join(missing)}")
    if not FFMPEG.is_file():
        raise RuntimeError(f"ffmpeg not found: {FFMPEG}")


def main() -> None:
    validate_inputs()
    WORK.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)

    demo_cover = save_title(
        "demo-cover",
        "FitCalgary Phase 1 is ready for Client review.",
        "The recognizable product shell is running on the production-oriented Flutter, Go, PostgreSQL and Keycloak foundation.",
        "CURRENT BUILD VERIFIED",
    )
    demo_onboarding = save_visual(
        "demo-onboarding", "Onboarding", "A guided first-launch experience", "Completion is persisted and returning users go directly to the product.",
        [(CAPTURES / "ios-onboarding.png", "iOS - first launch")], "ROUTES VERIFIED",
    )
    demo_platforms = save_visual(
        "demo-platforms", "Cross-platform product", "The same FitCalgary identity across platforms", "These are real captures from the current project.",
        [(CAPTURES / "android-gyms-live.png", "Android - live gym data"), (CAPTURES / "web-home.png", "Responsive web"), (CAPTURES / "watch-home.png", "Apple Watch")],
        "RUNNING",
    )
    demo_admin = save_visual(
        "demo-admin", "Administration", "A real, role-protected admin foundation", "The dashboard is responsive, API-backed and rejects unauthorized access.",
        [(CAPTURES / "web-admin-overview.png", "Admin overview"), (CAPTURES / "web-admin-denied.png", "Unauthorized access rejected")], "AUTHORIZATION TESTED",
    )
    demo_arch = save_architecture("demo-architecture")
    demo_next = save_results(
        "demo-next", "Next milestone", "Phase 2 completes the agreed V1 workflows", "After Client authorization, the same codebase is extended without restarting or removing working features.",
        [("Gym index, pricing, clubs and events", "PHASE 2"), ("Athlete profiles, boards and rankings", "PHASE 2"), ("Submissions, private evidence and judge review", "PHASE 2"), ("Full admin, notifications and integrations", "PHASE 2")], proof=False,
    )
    demo_close = save_title(
        "demo-close", "Phase 1 - Ready for Client Review", "Technical foundation and Client product shell verified. Awaiting Client acceptance before substantial Phase 2 work begins.", "AWAITING CLIENT REVIEW",
    )

    demo = assemble("FitCalgary_Phase_1_Client_Demo.mp4", [
        ("still", demo_cover, 0, 9),
        ("still", demo_onboarding, 0, 10),
        ("live", CAPTURES / "ios-demo-clean.mp4", 0, 19),
        ("live", CAPTURES / "android-demo-clean.mp4", 0, 34),
        ("still", demo_platforms, 0, 12),
        ("live", CAPTURES / "web-demo-real.webm", 0, 38),
        ("still", demo_admin, 0, 12),
        ("still", demo_arch, 0, 13),
        ("still", demo_next, 0, 13),
        ("still", demo_close, 0, 9),
    ])

    tech_cover = save_title(
        "tech-cover", "Phase 1 technical proof", "Focused verification of the current application, service, database, access controls and platform builds.", "ALL PHASE 1 GATES PASS", proof=True,
    )
    tech_tests = save_results(
        "tech-tests", "Fresh verification", "Current repository checks", "Commands were rerun in the local macOS development environment before packaging.",
        [("flutter analyze + flutter test", "PASS"), ("go test + go vet + production build", "PASS"), ("web lint + type check + production build", "PASS"), ("secret/configuration scan", "PASS")],
    )
    tech_arch = save_architecture("tech-architecture", proof=True)
    tech_auth = save_results(
        "tech-auth", "Authentication + authorization", "Server-side access boundaries", "Development identities were supplied through environment configuration; no reusable credentials appear in this video.",
        [("No session on protected admin route", "401"), ("USER role on protected admin route", "403"), ("ADMIN role on protected admin route", "200"), ("OIDC/OAuth 2.0 + PKCE foundation", "VERIFIED")],
    )
    tech_platforms = save_results(
        "tech-platforms", "Platform verification", "Fresh build and launch results", "Simulator and emulator checks are kept separate from physical-device verification.",
        [("iOS build + Simulator route demonstration", "PASS"), ("Android build + emulator + release AAB", "PASS"), ("Flutter web + responsive runtime", "PASS"), ("watchOS build + Simulator launch", "PASS")],
    )
    tech_admin = save_visual(
        "tech-admin", "Administration", "A real, role-protected admin foundation", "The dashboard is responsive, API-backed and rejects unauthorized access.",
        [(CAPTURES / "web-admin-overview.png", "Admin overview"), (CAPTURES / "web-admin-denied.png", "Unauthorized access rejected")], "AUTHORIZATION TESTED", proof=True,
    )
    tech_source = save_results(
        "tech-source", "Version control", "Development history preserved", "Authentic project commits and milestone references are maintained for contractual handoff.",
        [("Foundation snapshot preserved", "VERIFIED"), ("Client source retained as read-only reference", "VERIFIED"), ("Developer private repository", "VERIFIED"), ("Fresh-clone recovery", "VERIFIED")],
    )
    tech_close = save_title(
        "tech-close", "Phase 1 evidence is complete.", "No production service or physical-device result is overstated. External credentials and approved content remain explicitly outstanding.", "READY FOR CLIENT REVIEW", proof=True,
    )

    technical = assemble("FitCalgary_Phase_1_Technical_Proof.mp4", [
        ("still", tech_cover, 0, 9),
        ("still", tech_tests, 0, 15),
        ("still", tech_arch, 0, 14),
        ("still", CAPTURES / "android-gyms-live.png", 0, 10),
        ("still", tech_auth, 0, 14),
        ("live", CAPTURES / "web-demo-real.webm", 8, 30),
        ("still", tech_platforms, 0, 14),
        ("still", tech_admin, 0, 12),
        ("still", tech_source, 0, 12),
        ("still", tech_close, 0, 9),
    ])
    print(demo)
    print(technical)


if __name__ == "__main__":
    main()
