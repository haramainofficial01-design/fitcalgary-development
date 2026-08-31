from __future__ import annotations

from pathlib import Path

from PIL import Image as PILImage
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import landscape, letter
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
CAPTURES = ROOT / ".artifacts/phase1-fresh"
OUTPUT = ROOT / "client-review/phase-1/FitCalgary_Phase_1_Client_Review.pdf"

PAGE_W, PAGE_H = landscape(letter)
INK = HexColor("#17191B")
PAPER = HexColor("#F6F3ED")
CORAL = HexColor("#C95C4B")
CORAL_PALE = HexColor("#F2DAD4")
GREEN = HexColor("#2F725B")
AMBER = HexColor("#9B681F")
MUTED = HexColor("#6E6D69")
LINE = HexColor("#CAC6BE")
PANEL = HexColor("#ECE8E0")
BLACK = HexColor("#111214")


def wrapped(text: str, font: str, size: float, width: float) -> list[str]:
    lines: list[str] = []
    current: list[str] = []
    for word in text.split():
        trial = " ".join(current + [word])
        if current and stringWidth(trial, font, size) > width:
            lines.append(" ".join(current))
            current = [word]
        else:
            current.append(word)
    if current:
        lines.append(" ".join(current))
    return lines


def paragraph(
    c: canvas.Canvas,
    text: str,
    x: float,
    y: float,
    width: float,
    *,
    font: str = "Helvetica",
    size: float = 9,
    leading: float = 12,
    color=MUTED,
    max_lines: int | None = None,
) -> float:
    lines = wrapped(text, font, size, width)
    if max_lines is not None:
        lines = lines[:max_lines]
    c.setFont(font, size)
    c.setFillColor(color)
    for line in lines:
        c.drawString(x, y, line)
        y -= leading
    return y


def page_frame(c: canvas.Canvas, section: str, page: int) -> None:
    c.setFillColor(PAPER)
    c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 15)
    c.drawString(36, PAGE_H - 31, "FITCALGARY")
    c.setFont("Helvetica-Bold", 7.5)
    c.drawString(138, PAGE_H - 30, "I N D E X")
    c.setFillColor(CORAL)
    c.setFont("Helvetica-Bold", 7)
    c.drawRightString(PAGE_W - 36, PAGE_H - 30, section.upper())
    c.setStrokeColor(INK)
    c.setLineWidth(0.8)
    c.line(36, PAGE_H - 44, PAGE_W - 36, PAGE_H - 44)
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 7)
    c.drawString(36, 18, "FitCalgary Index - Phase 1 Foundation Review - 31 August 2026")
    c.drawRightString(PAGE_W - 36, 18, f"{page} / 4")


def pill(c: canvas.Canvas, x: float, y: float, width: float, text: str, fill=GREEN) -> None:
    c.setFillColor(fill)
    c.roundRect(x, y, width, 17, 8.5, stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 6.7)
    c.drawCentredString(x + width / 2, y + 5.6, text)


def status_card(
    c: canvas.Canvas,
    x: float,
    y: float,
    width: float,
    title: str,
    status: str,
    fill=GREEN,
) -> None:
    c.setFillColor(white)
    c.setStrokeColor(LINE)
    c.roundRect(x, y, width, 58, 5, stroke=1, fill=1)
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 8.4)
    c.drawString(x + 9, y + 37, title)
    pill(c, x + 9, y + 10, width - 18, status, fill)


def section_heading(c: canvas.Canvas, kicker: str, title: str, y: float) -> None:
    c.setFillColor(CORAL)
    c.setFont("Helvetica-Bold", 7.5)
    c.drawString(42, y, kicker.upper())
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 25)
    c.drawString(42, y - 33, title)


def info_box(c: canvas.Canvas, x: float, y: float, width: float, height: float, title: str, body: str) -> None:
    c.setFillColor(white)
    c.setStrokeColor(LINE)
    c.roundRect(x, y, width, height, 5, stroke=1, fill=1)
    c.setFillColor(CORAL)
    c.rect(x, y, 4, height, stroke=0, fill=1)
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 8.4)
    c.drawString(x + 13, y + height - 18, title.upper())
    paragraph(c, body, x + 13, y + height - 35, width - 25, size=7.6, leading=10.2)


def fit_image(c: canvas.Canvas, path: Path, x: float, y: float, width: float, height: float, *, bg=white) -> None:
    image = PILImage.open(path).convert("RGB")
    iw, ih = image.size
    scale = min(width / iw, height / ih)
    dw, dh = iw * scale, ih * scale
    c.setFillColor(bg)
    c.roundRect(x, y, width, height, 5, stroke=0, fill=1)
    c.drawImage(ImageReader(image), x + (width - dw) / 2, y + (height - dh) / 2, dw, dh, mask="auto")
    c.setStrokeColor(LINE)
    c.roundRect(x, y, width, height, 5, stroke=1, fill=0)


def caption(c: canvas.Canvas, x: float, y: float, width: float, title: str, body: str) -> None:
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 7.7)
    c.drawString(x, y, title)
    paragraph(c, body, x, y - 11, width, size=6.6, leading=8.5, max_lines=2)


def page_one(c: canvas.Canvas) -> None:
    page_frame(c, "Executive overview", 1)
    c.setFillColor(CORAL)
    c.setFont("Helvetica-Bold", 8)
    c.drawString(42, 530, "PHASE 1 - FOUNDATION + PRODUCT REVIEW")
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 36)
    c.drawString(42, 485, "The FitCalgary foundation is working.")
    c.setFillColor(GREEN)
    c.setFont("Helvetica-Bold", 21)
    c.drawString(42, 448, "READY FOR CLIENT REVIEW")
    paragraph(
        c,
        "Phase 1 established the production-ready technical base and incorporated the Client's recognizable FitCalgary product direction into a working cross-platform application. The current build is ready for milestone review; final production credentials, approved data and physical-device checks remain clearly separate.",
        42,
        418,
        704,
        size=10.2,
        leading=14,
        max_lines=3,
    )
    cards = [
        ("Client product UI", "VERIFIED", GREEN),
        ("Onboarding + routes", "VERIFIED", GREEN),
        ("Go backend", "VERIFIED", GREEN),
        ("PostgreSQL", "VERIFIED", GREEN),
        ("iOS", "SIMULATOR VERIFIED", CORAL),
        ("Android", "EMULATOR VERIFIED", CORAL),
        ("Web", "BUILD + RUN VERIFIED", GREEN),
        ("Apple Watch", "SIMULATOR VERIFIED", CORAL),
        ("Authentication", "FOUNDATION VERIFIED", GREEN),
        ("Authorization", "TESTED", GREEN),
        ("Admin dashboard", "FOUNDATION VERIFIED", GREEN),
        ("Source + history", "ACTIVE + PRESERVED", GREEN),
    ]
    card_w, gap = 109, 9
    for index, item in enumerate(cards):
        row, col = divmod(index, 6)
        status_card(c, 42 + col * (card_w + gap), 287 - row * 68, card_w, *item)
    c.setFillColor(INK)
    c.roundRect(42, 89, 708, 63, 4, stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 9)
    c.drawString(57, 126, "VERIFICATION BOUNDARY")
    c.setFont("Helvetica", 8.1)
    c.drawString(57, 107, "Simulator/emulator and local development results are reported exactly as tested. Physical devices and production services are not claimed as verified.")
    c.showPage()


def page_two(c: canvas.Canvas) -> None:
    page_frame(c, "Product foundation", 2)
    section_heading(c, "Client product foundation", "Recognizable FitCalgary, running across platforms.", 528)
    paragraph(
        c,
        "The direct Flutter source preserves the supplied product identity while adding restrained improvements to spacing, hierarchy, feedback and responsive behavior. Primary navigation, onboarding and major visible controls work; development data is clearly separated from final Client content.",
        42,
        477,
        704,
        size=8.5,
        leading=11.5,
        max_lines=3,
    )
    fit_image(c, CAPTURES / "ios-onboarding.png", 42, 157, 118, 284, bg=BLACK)
    fit_image(c, CAPTURES / "ios-home.png", 170, 157, 118, 284, bg=BLACK)
    fit_image(c, CAPTURES / "android-gyms-live.png", 298, 157, 118, 284)
    fit_image(c, CAPTURES / "web-home.png", 426, 315, 211, 126)
    fit_image(c, CAPTURES / "web-admin-overview.png", 426, 157, 211, 112)
    fit_image(c, CAPTURES / "watch-home.png", 647, 157, 103, 284, bg=BLACK)
    caption(c, 42, 141, 118, "Onboarding", "First-launch flow and completion state.")
    caption(c, 170, 141, 118, "iOS - Home", "Current product shell in Simulator.")
    caption(c, 298, 141, 118, "Android - Gyms", "Live data through Go/PostgreSQL.")
    caption(c, 426, 300, 211, "Responsive web", "Current public product experience.")
    caption(c, 426, 141, 211, "Admin dashboard", "Authenticated, API-backed foundation.")
    caption(c, 647, 141, 103, "Apple Watch", "Companion target in Simulator.")
    c.setFillColor(CORAL_PALE)
    c.roundRect(42, 64, 708, 48, 4, stroke=0, fill=1)
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 8.2)
    c.drawString(56, 92, "WORKING PRODUCT SHELL")
    c.setFont("Helvetica", 7.6)
    c.drawString(56, 76, "Home, Gyms, Board, Compete, Me, account entry and role-protected administration are navigable without dead-end primary routes.")
    c.showPage()


def architecture_diagram(c: canvas.Canvas, x: float, y: float, width: float, height: float) -> None:
    c.setFillColor(white)
    c.setStrokeColor(LINE)
    c.roundRect(x, y, width, height, 6, stroke=1, fill=1)
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 8)
    c.drawString(x + 13, y + height - 19, "IMPLEMENTED SYSTEM PATH")
    nodes = [
        (x + 13, y + 117, 78, 28, "iOS / Android", PANEL, INK),
        (x + 101, y + 117, 52, 28, "Web", PANEL, INK),
        (x + 163, y + 117, 64, 28, "watchOS", PANEL, INK),
        (x + 73, y + 68, 101, 31, "Versioned Go API", CORAL, white),
        (x + 14, y + 16, 91, 31, "Keycloak OIDC", PANEL, INK),
        (x + 135, y + 16, 99, 31, "PostgreSQL 17.11", PANEL, INK),
    ]
    for nx, ny, nw, nh, label, fill, text_color in nodes:
        c.setFillColor(fill)
        c.roundRect(nx, ny, nw, nh, 4, stroke=0, fill=1)
        c.setFillColor(text_color)
        c.setFont("Helvetica-Bold", 6.8)
        c.drawCentredString(nx + nw / 2, ny + nh / 2 - 2.2, label)
    c.setStrokeColor(INK)
    c.line(x + 52, y + 117, x + 102, y + 99)
    c.line(x + 127, y + 117, x + 123, y + 99)
    c.line(x + 195, y + 117, x + 145, y + 99)
    c.line(x + 123, y + 68, x + 60, y + 47)
    c.line(x + 123, y + 68, x + 184, y + 47)


def result_row(c: canvas.Canvas, x: float, y: float, width: float, label: str, result: str = "PASS") -> None:
    c.setStrokeColor(LINE)
    c.line(x, y - 4, x + width, y - 4)
    c.setFillColor(INK)
    c.setFont("Helvetica", 7.5)
    c.drawString(x, y + 6, label)
    c.setFillColor(GREEN)
    c.setFont("Helvetica-Bold", 7)
    c.drawRightString(x + width, y + 6, result)


def page_three(c: canvas.Canvas) -> None:
    page_frame(c, "System proof + testing", 3)
    section_heading(c, "Technical foundation", "The product is connected to the real service and data layer.", 528)
    architecture_diagram(c, 42, 287, 249, 177)
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 9)
    c.drawString(315, 445, "PHASE 1 VERIFICATION")
    results = [
        "Flutter analysis + tests",
        "Go tests + vet + production build",
        "PostgreSQL clean/repeat migrations - 30 tables",
        "Flutter -> Go -> PostgreSQL read/write",
        "iOS Simulator build + route demonstration",
        "Android emulator + release AAB",
        "Flutter web + web lint/type/build/runtime",
        "watchOS Simulator build + launch",
        "Admin access: unauthenticated 401 / USER 403 / ADMIN 200",
    ]
    for index, label in enumerate(results):
        result_row(c, 315, 419 - index * 21, 435, label)
    boxes = [
        ("APPLICATION", "Flutter/Dart is the primary client stack. The source is maintained directly and is not dependent on a visual builder."),
        ("BACKEND + DATA", "Go provides the versioned API and server-side rules. PostgreSQL migrations reproducibly initialize the current 30-table schema."),
        ("AUTHENTICATION", "Keycloak OIDC/OAuth 2.0 + PKCE foundation covers email/password, verification/reset, secure sessions and Google/Apple integration hooks."),
        ("AUTHORIZATION + SECURITY", "Roles are enforced by the Go service. Secrets stay outside source; requests are validated and errors remain safe and structured."),
        ("CORE SERVICE CONTRACTS", "Foundational routes exist for gyms, events, leaderboards, submissions, notifications and administration."),
        ("SOURCE + VERSION HISTORY", "Development is maintained under Git-based version control with meaningful history preserved for contractual handoff."),
    ]
    for index, (title, body) in enumerate(boxes):
        row, col = divmod(index, 3)
        info_box(c, 42 + col * 237, 162 - row * 90, 222, 78, title, body)
    c.showPage()


def page_four(c: canvas.Canvas) -> None:
    page_frame(c, "Client review + next step", 4)
    section_heading(c, "Milestone boundary", "What is complete, what remains, and what comes next.", 528)
    info_box(
        c,
        42,
        322,
        222,
        141,
        "Phase 1 foundation",
        "The technical foundation, recognizable product shell, onboarding, primary routing, admin foundation, role protection, local integration and platform build paths shown in this review are ready for Client review.",
    )
    info_box(
        c,
        279,
        322,
        222,
        141,
        "Client / external items",
        "Final gym/pricing, club/event and ranking content; production Keycloak, email, Google/Apple, hosting/domain, storage, notification and store credentials remain Client/service dependencies. Development fixtures are not production data.",
    )
    info_box(
        c,
        516,
        322,
        222,
        141,
        "Later verification",
        "iOS and watchOS are Simulator verified; Android is emulator verified. Physical devices, signed store releases and production services are not represented as verified and remain part of later validation.",
    )
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 9)
    c.drawString(42, 284, "NEXT - PHASE 2: CORE PRODUCT")
    paragraph(
        c,
        "After Client authorization, Phase 2 extends this same codebase into the complete V1 workflows: final gym/index pricing, clubs and events, athlete profiles and boards, result submission and private evidence, judge review, approval/resubmission, full administration, notifications and the remaining agreed integrations. Existing working functionality is preserved.",
        42,
        264,
        696,
        size=8.5,
        leading=11.5,
        max_lines=4,
    )
    c.setFillColor(CORAL)
    c.roundRect(42, 90, 696, 118, 6, stroke=0, fill=1)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 10)
    c.drawString(59, 181, "PHASE 1 - READY FOR CLIENT REVIEW")
    paragraph(
        c,
        "The Phase 1 technical and product foundations are ready for review against the agreed milestone scope. This document shows what has been established, what was tested, and which production items still depend on later work or Client-supplied information.",
        59,
        157,
        655,
        size=8.7,
        leading=12,
        color=white,
        max_lines=3,
    )
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 8.2)
    c.drawString(59, 111, "If the Client is satisfied with the deliverables and demonstration, Phase 1 can be confirmed and Phase 2 authorized.")
    c.showPage()


def validate_inputs() -> None:
    required = [
        "ios-onboarding.png",
        "ios-home.png",
        "android-gyms-live.png",
        "web-home.png",
        "web-admin-overview.png",
        "watch-home.png",
    ]
    missing = [name for name in required if not (CAPTURES / name).is_file()]
    if missing:
        raise RuntimeError(f"Missing Phase 1 capture(s): {', '.join(missing)}")


def main() -> None:
    validate_inputs()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUTPUT), pagesize=(PAGE_W, PAGE_H), pageCompression=1)
    c.setTitle("FitCalgary Phase 1 Client Review")
    c.setAuthor("Sahl Shafiq")
    c.setSubject("FitCalgary Index Phase 1 foundation and product review")
    for draw in (page_one, page_two, page_three, page_four):
        draw(c)
    c.save()
    print(OUTPUT)


if __name__ == "__main__":
    main()
