from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, Image, KeepTogether
)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "client-review/phase-2/FitCalgary_Phase_2_Client_Review.pdf"
ART = ROOT / ".artifacts"
CREAM = colors.HexColor("#F4F1EA")
INK = colors.HexColor("#202428")
MUTED = colors.HexColor("#6E7475")
CORAL = colors.HexColor("#CA5A4C")
LINE = colors.HexColor("#D6D2C9")
PALE = colors.HexColor("#EAE5DC")
GREEN = colors.HexColor("#59735E")

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="Kicker", parent=styles["Normal"], fontName="Helvetica-Bold", fontSize=8, leading=10, textColor=CORAL, tracking=1.6, spaceAfter=6))
styles.add(ParagraphStyle(name="TitleFit", parent=styles["Title"], fontName="Helvetica-Bold", fontSize=28, leading=30, textColor=INK, spaceAfter=8))
styles.add(ParagraphStyle(name="H2Fit", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=15, leading=18, textColor=INK, spaceBefore=8, spaceAfter=5))
styles.add(ParagraphStyle(name="BodyFit", parent=styles["BodyText"], fontName="Helvetica", fontSize=9.2, leading=13, textColor=INK, spaceAfter=5))
styles.add(ParagraphStyle(name="SmallFit", parent=styles["BodyText"], fontName="Helvetica", fontSize=7.5, leading=10, textColor=MUTED))
styles.add(ParagraphStyle(name="CardHead", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=8, leading=10, textColor=INK))
styles.add(ParagraphStyle(name="CardValue", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=8, leading=10, textColor=GREEN))
styles.add(ParagraphStyle(name="TableHead", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=7.5, leading=9, textColor=INK))
styles.add(ParagraphStyle(name="TableCell", parent=styles["BodyText"], fontName="Helvetica", fontSize=7.5, leading=9, textColor=INK))

def p(text, style="BodyFit"):
    return Paragraph(text, styles[style])

def image(path, width, height=None):
    path = Path(path)
    if not path.exists():
        return p("Evidence image unavailable", "SmallFit")
    im = Image(str(path), width=width, height=height)
    im.hAlign = "CENTER"
    return im

def status_card(name, value, width=1.35*inch):
    t = Table([[p(name.upper(), "CardHead")], [p(value, "CardValue")]], colWidths=[width], rowHeights=[0.28*inch, 0.33*inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,-1), colors.white),
        ("BOX", (0,0), (-1,-1), .6, LINE),
        ("LEFTPADDING", (0,0), (-1,-1), 8), ("RIGHTPADDING", (0,0), (-1,-1), 8),
        ("TOPPADDING", (0,0), (-1,-1), 6), ("BOTTOMPADDING", (0,0), (-1,-1), 5),
    ]))
    return t

def footer(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(MUTED)
    canvas.setFont("Helvetica", 7)
    canvas.drawString(0.55*inch, 0.35*inch, "FITCALGARY INDEX  /  PHASE 2 CORE PRODUCT REVIEW")
    canvas.drawRightString(7.95*inch, 0.35*inch, f"{doc.page:02d}")
    canvas.restoreState()

class FitDoc(BaseDocTemplate):
    def __init__(self, filename):
        super().__init__(filename, pagesize=letter, leftMargin=.55*inch, rightMargin=.55*inch, topMargin=.5*inch, bottomMargin=.55*inch, title="FitCalgary Phase 2 Client Review")
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="main")
        self.addPageTemplates([PageTemplate(id="fit", frames=[frame], onPage=footer)])

def build():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = FitDoc(str(OUT))
    story = []

    # Page 1
    story += [p("FITCALGARY INDEX", "Kicker"), p("PHASE 2 - CORE PRODUCT REVIEW", "TitleFit"), p("September 2026  |  Client review candidate", "SmallFit"), Spacer(1, 8)]
    story += [p("READY FOR CLIENT REVIEW", "H2Fit"), p("Phase 2 turns the tested technical foundation into the working FitCalgary core product: directory and pricing comparison, clubs and events, athlete profiles, leaderboards, private evidence review, moderation and notifications across the supported clients.")]
    cards = [[status_card("Flutter / Dart", "VERIFIED"), status_card("Go services", "VERIFIED"), status_card("PostgreSQL", "VERIFIED"), status_card("Web", "VERIFIED")], [status_card("iOS", "SIMULATOR"), status_card("Android", "EMULATOR"), status_card("Watch", "SIMULATOR"), status_card("Auth / roles", "TESTED")]]
    t = Table(cards, colWidths=[1.7*inch]*4, rowHeights=[.78*inch, .78*inch], hAlign="LEFT")
    t.setStyle(TableStyle([("LEFTPADDING", (0,0), (-1,-1), 0), ("RIGHTPADDING", (0,0), (-1,-1), 8), ("TOPPADDING", (0,0), (-1,-1), 5), ("BOTTOMPADDING", (0,0), (-1,-1), 5)]))
    story += [t, Spacer(1, 10), p("The central acceptance path is working in development: athlete submission -> private evidence -> judge correction or approval -> verified result -> official leaderboard placement -> notification. Physical devices, live provider credentials, final Client content and store submission remain clearly separated from local verification.", "BodyFit")]
    story += [Spacer(1, 8), p("PRODUCT CHARACTER", "Kicker"), p("The recognizable cream, black and coral FitCalgary editorial system is preserved. The mobile clients use adaptive layered surfaces and accessible fallbacks; the web and admin surfaces use restrained elevation, responsive layouts and clear operational states.")]
    story += [PageBreak()]

    # Page 2
    story += [p("WHAT PHASE 2 DELIVERED", "Kicker"), p("A working core product", "TitleFit")]
    sections = [
        ("DIRECTORY AND PRICING", "Searchable gyms, structured membership plans, normalized monthly and first-year cost comparison, saved gyms and responsive detail views."),
        ("CLUBS AND EVENTS", "Published club and event browse/detail experiences, registration links, eligibility and temporal states, plus admin content operations."),
        ("ATHLETE AND LEADERBOARDS", "Profiles, official and community result separation, personal best/history, configurable disciplines/divisions, ties, eligibility and privacy-aware placement."),
        ("PRIVATE EVIDENCE WORKFLOW", "Real multipart storage path with ownership checks, signed playback, correction/resubmission, judge queue, checklist decisions, comments, approval and retention behavior."),
        ("ADMIN AND MODERATION", "Role-protected operations console with users, roles, content, reviews, moderation, notifications, analytics and audit visibility. Immediate role/account restrictions are enforced by the Go service."),
        ("NOTIFICATIONS AND SECURITY", "In-app inbox, preferences, essential notices, idempotent announcements, encrypted device-token registration, retry/backoff and invalid-token cleanup. Secrets stay outside source control; validation and safe errors are applied at service boundaries."),
    ]
    rows = []
    for title, body in sections:
        rows.append([p(title, "CardHead"), p(body, "BodyFit")])
    table = Table(rows, colWidths=[1.75*inch, 5.25*inch], hAlign="LEFT")
    table.setStyle(TableStyle([("BACKGROUND", (0,0), (-1,-1), colors.white), ("BOX", (0,0), (-1,-1), .6, LINE), ("INNERGRID", (0,0), (-1,-1), .35, LINE), ("VALIGN", (0,0), (-1,-1), "TOP"), ("LEFTPADDING", (0,0), (-1,-1), 10), ("RIGHTPADDING", (0,0), (-1,-1), 10), ("TOPPADDING", (0,0), (-1,-1), 9), ("BOTTOMPADDING", (0,0), (-1,-1), 4)]))
    story += [table, Spacer(1, 10), p("Development fixtures are isolated and clearly treated as development data. The application is built against the production-shaped data model so Client-approved content can be imported without rewriting the product.", "SmallFit"), PageBreak()]

    # Page 3 visual proof
    story += [p("VISUAL PROOF", "Kicker"), p("The product in use", "TitleFit"), p("Real project screenshots from the current verification runs. Simulator and emulator labels are intentional; they are not physical-device claims.", "SmallFit"), Spacer(1, 8)]
    img = [
        (ART/"phase2/final/ios-current.png", "iOS simulator - FitCalgary onboarding and shell"),
        (ART/"phase2/android-private-workflow.png", "Android emulator - private evidence submission"),
        (ART/"phase2/admin-browser/gym-comparison.png", "Responsive web - structured gym comparison"),
        (ART/"phase2/admin-browser/verified-official-result.png", "Responsive web - verified official board"),
        (ART/"phase1-fresh/watch-fresh-20260901.png", "Apple Watch simulator - compact athlete view"),
        (ART/"phase2/admin-browser/overview.png", "Admin dashboard - role-protected operations console"),
    ]
    cells = []
    for path, caption in img:
        cells.append([image(path, 2.22*inch, 2.05*inch), p(caption, "SmallFit")])
    grid = Table([cells[0:3], cells[3:6]], colWidths=[2.34*inch]*3, rowHeights=[2.38*inch, 2.38*inch], hAlign="LEFT")
    grid.setStyle(TableStyle([("BACKGROUND", (0,0), (-1,-1), colors.white), ("BOX", (0,0), (-1,-1), .5, LINE), ("INNERGRID", (0,0), (-1,-1), .5, LINE), ("VALIGN", (0,0), (-1,-1), "TOP"), ("LEFTPADDING", (0,0), (-1,-1), 6), ("RIGHTPADDING", (0,0), (-1,-1), 6), ("TOPPADDING", (0,0), (-1,-1), 6), ("BOTTOMPADDING", (0,0), (-1,-1), 6)]))
    story += [grid, PageBreak()]

    # Page 4 proof
    story += [p("SYSTEM AND TEST PROOF", "Kicker"), p("One service path, tested end to end", "TitleFit")]
    arch = Table([[p("iOS / Android / Web", "CardHead")], [p("        |", "BodyFit")], [p("Flutter / responsive web clients", "BodyFit")], [p("        |", "BodyFit")], [p("Go API + authorization + workers", "CardHead")], [p("        |", "BodyFit")], [p("Keycloak OIDC/PKCE + PostgreSQL + private storage", "BodyFit")]], colWidths=[7.0*inch], hAlign="LEFT")
    arch.setStyle(TableStyle([("BACKGROUND", (0,0), (-1,-1), PALE), ("BOX", (0,0), (-1,-1), .6, LINE), ("LEFTPADDING", (0,0), (-1,-1), 14), ("TOPPADDING", (0,0), (-1,-1), 4), ("BOTTOMPADDING", (0,0), (-1,-1), 4)]))
    story += [arch, Spacer(1, 10)]
    proof = [
        [p("CHECK", "TableHead"), p("RESULT", "TableHead"), p("BOUNDARY", "TableHead")],
        [p("Flutter analysis + tests", "TableCell"), p("PASS", "TableCell"), p("20 tests; registration lifecycle, workflows and presentation states", "TableCell")],
        [p("Go tests + vet + production build", "TableCell"), p("PASS", "TableCell"), p("All packages with PostgreSQL-backed workflow tests", "TableCell")],
        [p("PostgreSQL initialization", "TableCell"), p("PASS", "TableCell"), p("Fresh database, 7 migrations, 35 public tables", "TableCell")],
        [p("Private evidence workflow", "TableCell"), p("PASS", "TableCell"), p("Multipart storage, signed playback, correction, approval, rank and inbox", "TableCell")],
        [p("Web typecheck + lint + production build", "TableCell"), p("PASS", "TableCell"), p("Responsive routes and admin/public surfaces", "TableCell")],
        [p("iOS / Android / watchOS", "TableCell"), p("SIMULATOR / EMULATOR PASS", "TableCell"), p("No physical-device claim", "TableCell")],
        [p("Android release AAB", "TableCell"), p("PASS", "TableCell"), p("Unsigned local release output; store signing remains external", "TableCell")],
    ]
    pt = Table(proof, colWidths=[2.1*inch, 1.35*inch, 3.55*inch], hAlign="LEFT")
    pt.setStyle(TableStyle([("BACKGROUND", (0,0), (-1,0), PALE), ("BOX", (0,0), (-1,-1), .6, LINE), ("INNERGRID", (0,0), (-1,-1), .35, LINE), ("VALIGN", (0,0), (-1,-1), "TOP"), ("LEFTPADDING", (0,0), (-1,-1), 7), ("RIGHTPADDING", (0,0), (-1,-1), 7), ("TOPPADDING", (0,0), (-1,-1), 6), ("BOTTOMPADDING", (0,0), (-1,-1), 6)]))
    story += [pt, PageBreak()]

    # Page 5
    story += [p("REMAINING BOUNDARIES", "Kicker"), p("Ready for review, with the next release work explicit", "TitleFit")]
    story += [p("PHASE 2 STATUS", "H2Fit"), p("The core product workflows are materially complete and verified in the local development/staging environment. The code is committed to the private development repository at the acceptance candidate prepared with this package. This review is not a production deployment claim.")]
    story += [p("CLIENT / EXTERNAL INPUTS", "H2Fit"), p("Final gym, pricing, club, event and ranking content; production Keycloak host and SMTP; Google and Apple identity credentials; Firebase/APNs credentials; hosting, domain, storage and store accounts remain Client or service-provider dependencies. Development fixtures are not represented as final Client data.")]
    story += [p("PHYSICAL DEVICES AND PRODUCTION", "H2Fit"), p("iOS, Android and Apple Watch were verified in the applicable simulator/emulator environments. Physical-device verification, signed release artifacts, production configuration, store submission and public release cleanliness are Phase 3 work and are not marked complete here.")]
    story += [p("PHASE 3 NEXT", "H2Fit"), p("Phase 3 completes the release candidate: production credentials/configuration, approved data import, physical-device QA, signed archives/AAB, notification provider verification, performance and security review, store assets/submission preparation, deployment and handoff documentation.")]
    box = Table([[p("PHASE 2 - READY FOR CLIENT REVIEW", "H2Fit")], [p("The preceding pages show the working product, the tested service path and the boundaries that remain external or belong to final release preparation. Client acceptance is not assumed. Once reviewed and accepted, the project can proceed to Phase 3 release readiness.")]], colWidths=[7.0*inch], hAlign="LEFT")
    box.setStyle(TableStyle([("BACKGROUND", (0,0), (-1,0), CORAL), ("TEXTCOLOR", (0,0), (-1,0), colors.white), ("BACKGROUND", (0,1), (-1,1), colors.white), ("BOX", (0,0), (-1,-1), .8, CORAL), ("LEFTPADDING", (0,0), (-1,-1), 12), ("RIGHTPADDING", (0,0), (-1,-1), 12), ("TOPPADDING", (0,0), (-1,-1), 10), ("BOTTOMPADDING", (0,0), (-1,-1), 6)]))
    story += [Spacer(1, 10), box]
    doc.build(story)
    print(OUT)

if __name__ == "__main__":
    build()
