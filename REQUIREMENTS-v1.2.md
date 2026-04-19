# REQUIREMENTS.md
## ggplot2 extended (companion) — v1.2

### 1. Overview

- **Purpose**: *A polish release that improves mobile UX, desktop layout, and connection stability — bringing the app from "works" to "feels well-crafted."* No new feature areas, no architectural overhauls, no tech-stack changes. Every requirement in this document serves one of three pillars: (a) the app survives a tab left open over lunch, (b) a stranger opening it on their phone doesn't immediately leave, (c) a designer friend doesn't visibly wince.

- **Stakeholder posture**: This is a **community tool by an R developer, for R developers** — not a SaaS product. v1.2 polishes obvious rough edges. It does **not** add SaaS-product trappings (analytics dashboards, SEO funnels, social-preview optimisation, conversion tracking, A/B testing, etc.) just because external feedback expected them. When candidate scope creep appears during implementation, this posture is the test: does the change serve the community-tool framing, or is it product-isation drift?

- **Tech stack decision (parked)**: R/Shiny is final. Not revisiting in v1.2 or any near-term version. The app lives in the R/ggplot2 ecosystem, the maintainer is an R developer, and the data pipeline is already R-native. Rebuilding in another stack is explicitly out of scope and not subject to re-litigation.

- **Target Users**: R developers and data analysts who use ggplot2 and want to discover extension packages. Audience is desktop-dominant (R developers at workstations using RStudio/Positron). Mobile is a courtesy — see Mobile posture below — not the primary surface.

- **Mobile posture**: **(b) Mobile-aware** — actively designed to work well on mobile, key flows tested on mobile, but desktop remains the design target. Not mobile-first.

- **Success Criteria** (qualitative — used to judge whether v1.2 was worth shipping):
  1. *A stranger opening the app on their phone doesn't immediately leave.*
  2. *Someone leaving the tab open over lunch returns to a working app, not a dead grey screen.*
  3. *A friend who's a designer looks at it and doesn't visibly wince.*

- **Baseline (v1.1) — confirmed shipped**: All v1.1 work (Google Form submission flow, archived packages with `is_archived` column and UI, non-CRAN GitHub DESCRIPTION enrichment, version label rename) is implemented and live in the codebase. v1.2 is purely additive polish on top of the v1.1 baseline. The `is_essential → is_featured` rename described in §2.4 cannot be folded into v1.1 (already shipped) and will be a v1.2 schema migration.

### 2. Functional Requirements

#### 2.1 Connection Stability (Pillar 1)

##### 2.1.1 Background

The current app exhibits a known disconnection symptom: after roughly 2 minutes of inactivity, users report the page going "light-gray-ish" — this is the standard Shiny disconnected overlay that appears when the WebSocket connection drops, with no path back except a manual page reload. This violates success criterion #2 ("tab open over lunch is still working").

##### 2.1.2 Posture

**(C) Both** — tune session timeouts to be more forgiving **and** show a clean reconnect prompt when the session does eventually drop.

##### 2.1.3 Idle session survival

- Idle Shiny sessions must survive **30 minutes** of inactivity before being terminated.
- Cloud Run and Shiny configuration must be aligned to support this — specifically, the Cloud Run request/timeout settings, Shiny's `sessionTimeout`, and any intermediate WebSocket idle behaviour must not terminate connections earlier than 30 minutes.

##### 2.1.4 Activity ping (lightweight keep-alive)

- A client-side keep-alive ping must fire periodically (target: every ~5 minutes) to keep the WebSocket warm while the user is actively viewing the tab.
- **Constraint**: The activity ping must use the **Page Visibility API** and only fire while the tab is **visible**. When the tab is backgrounded, hidden, or the browser is minimised, the keep-alive must cease so the session can time out normally and the Cloud Run container can scale to zero.
- Rationale: this prevents the failure mode of "user opens the tab and walks away with it open in the background, container stays warm forever, billing escalates."

##### 2.1.5 Disconnect UI

- When the session does drop (after 30 min of legitimate inactivity, network failure, server restart, etc.), the user must see a **centered card** with a clear call to action — *not* the default Shiny grey overlay.
- The card must contain at minimum: a clear heading ("Your session expired" or equivalent), a brief explanation, and a button labelled to communicate reload intent (e.g., "Reload the app").
- The card's visual styling must match the rest of the app (bslib theme, dark/light mode aware) and meet the accessibility floor in §2.6.

##### 2.1.6 Filter state preservation across reconnect

- **Nice-to-have, not blocking.** If the Architect can preserve sidebar filter state across a reconnect cycle (e.g., via URL params or sessionStorage), do so. If not, accept that reload returns the user to the default filter state.

##### 2.1.7 Composition with existing loading polish

- The post-reconnect reload path automatically inherits the existing branded splash and "Loading packages" spinner. No separate "reconnecting…" UI is needed — the existing loading polish carries this.

#### 2.2 Mobile UX (Pillar 2)

##### 2.2.1 Background

External feedback summary: *"It's a desktop view compressed into a mobile view; normally you expand a mobile view into a desktop one."* The maintainer's lived experience confirms the most acute pain point: **the filter sidebar does not behave like a sidebar on mobile** — it ends up dumped at the bottom of the page or otherwise misplaced.

##### 2.2.2 Mobile sidebar (browse view)

- On mobile, the filter controls (currently in the sidebar) must behave as a proper mobile-native pattern, not a stack-at-the-bottom collapse.
- **Two acceptable patterns** — Solution Architect's call between them, based on bslib idioms and visual coherence with the rest of the app:
  - **Off-canvas drawer**: hamburger button opens a slide-in panel from the side, dims the background. bslib supports this via `sidebar(open = list(mobile = "closed"))`.
  - **Top accordion**: filters collapse into a "Filters" accordion above the table, expandable on tap.
- **Default state**: closed on mobile; the table is the primary content.

##### 2.2.3 Browse table on mobile

- Stakeholder leans toward a **card list** (each package becomes a tappable card with name, short description, key badges) but defers to the Solution Architect's judgment.
- Other acceptable patterns: same table with hidden columns at small breakpoints; same table with horizontal scroll (least preferred).
- **If the Architect picks a card list**: they must additionally decide whether desktop also gets cards (consistency) or stays a table (responsive divergence). Either choice is acceptable; the decision and rationale should be documented.

##### 2.2.4 Detail view on mobile

- The detail view itself "mostly works" on mobile per maintainer testing — no specific layout work required there.
- **However**: see §2.3.1 below for the cross-cutting decision that filters must not appear on the detail view at all (mobile or desktop). This addresses the maintainer's specific mobile pain point of filters appearing at the bottom of the detail view, which is conceptually inappropriate (filters belong to browse, not detail).

##### 2.2.5 Sidebar default state on desktop

- The desktop sidebar (currently collapsed by default) must be **open by default on desktop**.
- Combined with §2.2.2: the natural bslib pattern `open = list(desktop = "open", mobile = "closed")` applies.

#### 2.3 Desktop Layout Polish (Pillar 3)

##### 2.3.1 Filter sidebar visibility per view

- The filter sidebar belongs to the **browse view only**, not to the app globally.
- On the **detail view**, the filter sidebar must be **hidden entirely** on all devices (mobile and desktop).
- Implementation note for the Solution Architect: this is a navigation/state change, not a CSS hide. Two acceptable approaches:
  - Conditional rendering of the sidebar based on active view.
  - Per-view layout swap: browse uses `bslib::page_sidebar()`, detail uses a no-sidebar layout (`bslib::page_fillable()` or similar).
- **Side benefit**: the detail view gets the full width on desktop, providing more room for description, examples, and version card.

##### 2.3.2 Theme toggle

- **Placement**: Top-right corner of the navbar/header (standard 2026 pattern).
- **Form factor**: Icon-only button (sun ↔ moon). `bslib::input_dark_mode()` is the natural choice if not already in use.
- **Default on first visit**: Follow OS preference (`prefers-color-scheme`).
- **Persistence**: Remember the user's explicit choice in localStorage.
- **Live OS sync**: Follow OS changes live until the user makes an explicit choice; after explicit choice, that choice wins.
- **Implementation note**: `bslib::input_dark_mode()` handles the icon button and OS detection out of the box. The "follow OS live until user makes an explicit choice" behaviour may require a small amount of custom JavaScript to track whether the user has explicitly toggled and decide whether to subscribe to `prefers-color-scheme` change events.

##### 2.3.3 Header / intro accordion

- **Default state**: Open on first visit, closed on return visits (localStorage-backed).
- **Above-the-fold check**: On a typical desktop viewport (1440×900 or larger), with the intro in its default state for a returning visitor (closed), the top of the package table must be visible without scrolling. The Architect must verify this by direct measurement.
- **Layout stability**: On initial load, no element may jump or reflow unexpectedly when async data finishes loading. Async-load layout shift is a "designer would wince" issue and must be eliminated.
- **Intro content rewrite**: The intro copy must be rewritten to answer four questions clearly and concisely:
  1. *What is this directory?* (one sentence)
  2. *What's the connection to the book?* (one sentence)
  3. *What does the ⭐ mean?* — answered explicitly: *"These are the extensions featured in the companion book — the maintainer's recommended starting set."*
  4. *How is the data curated?* — using the tagline *"Manually curated, refreshed daily."*
- The link to the book and any other external resources should be informative ("learn more"), not promotional ("buy now").

##### 2.3.4 "Essential" → "Featured in the book" rename

This is a coordinated rename across data, UI, validation, tests, and documentation. The ⭐ marker has always meant "covered in the companion book" — the rename makes that semantic explicit and honest. The 1:1 mapping between ⭐ and book-featured packages is confirmed by the maintainer (every ⭐ is in the book; every book-featured package is ⭐).

| Surface | Today | After v1.2 |
|---|---|---|
| CSV column | `is_essential` | `is_featured` |
| Validation function | `validate_is_essential()` | `validate_is_featured()` |
| Filter parameter | `essential_only` | `featured_only` (Architect's call on naming) |
| Sidebar filter label | "Essential Extensions Only" | **"Featured in the Book"** |
| Detail view badge | "⭐ Essential Extension" | **"⭐ Featured in the book"** |
| Browse table tooltip on ⭐ | (whatever it is today) | **"Featured in the book"** |
| CSS class | `.badge-essential` | `.badge-featured` |
| JSON export key | `is_essential` | `is_featured` |
| Internal references in code | `is_essential` everywhere | `is_featured` everywhere |
| Documentation (README, SPEC, SPEC-v1.1) | "essential" terminology | Updated to "featured" terminology where present going forward |

- **JSON backward compatibility**: **Hard rename**. The companion app is still very new and there are no known external consumers of `packages.json`. The breaking change must be mentioned in the v1.2 release notes / README diff as good citizenship.
- **Migration scope**: Touched files include (non-exhaustive): `data-raw/packages_curated.csv`, `R/fct_validation.R`, `R/fct_filters.R`, `R/fct_pipeline.R`, `R/mod_sidebar.R`, `R/mod_browse.R`, `R/mod_detail.R`, `R/app_server.R`, `inst/app/www/styles.css`, `tests/testthat/test-fct_validation.R`, `tests/testthat/test-fct_filters.R`, `tests/testthat/test-fct_pipeline.R`, `inst/app/www/data/packages.json` (regenerated), `README.md`. The Architect should produce a complete file list before starting.

##### 2.3.5 Visual rhythm / spacing audit

- **Approach**: The Solution Architect performs a **structured visual audit** at standard breakpoints and produces a ranked list of the **top ~10 visual polish items**, with screenshots where helpful.
- **Reference point**: **Bootstrap defaults / bslib idioms.** The audit's quality bar is *"uses bslib idioms cleanly; doesn't introduce inconsistency through ad-hoc custom CSS."* The audit must explicitly flag any raw hex values (e.g., `#6b7280` in `.badge-archived`) that should be `var(--bs-*)` references.
- **Mode coverage**: The audit must explicitly check both **light and dark modes**. Polish items that look fine in dark may break in light and vice versa, especially around custom badges, package link styling, empty states, and any inline `style=""` attributes.
- **Stakeholder role**: The maintainer **approves, defers, or rejects** each audit item before implementation. This is not an open-ended polish budget — the audit produces a finite, prioritised list.

##### 2.3.6 Brand identity (light touch only)

- **Overall posture**: Keep the visual identity generic for v1.2. The book is still a work in progress; full brand work (logo, wordmark, custom typography, social-preview imagery) is deferred to v1.3 or later.
- **One identity element to apply**: the **accent red** shared by the book site (`https://ggplot2-extended-book.com/`) and the apps portfolio (`https://youcanbeapirate.com/`). The Architect must obtain the **exact hex value** from one of these canonical sources rather than eyeballing it.
- **Application approach**: Default to **theme-level** application via `bs_theme(primary = "<red-hex>")` so the colour propagates through Bootstrap components automatically. Fall back to targeted CSS overrides only if theme-level application produces undesirable effects somewhere.
- **Constraint**: The chosen red must hit at least WCAG AA contrast against its backgrounds in **both** light and dark modes. It must not be confused with Bootstrap's `--bs-danger` red (used for warnings/errors). If a single red value fails one of the modes, the Architect may use slightly different shades per mode (e.g., a deeper red on light, a lighter / more saturated red on dark). The visual audit (§2.3.5) is the gate that confirms this.

##### 2.3.7 Loading states (no work required)

- App initial load: existing branded splash is sufficient. **No changes.**
- Detail view transition: the brief blank during transition is acceptable per maintainer testing. **No changes.** The Architect should verify it isn't more jarring than remembered; if so, this becomes a parking-lot item, not a v1.2 work item.
- Parquet loading: existing "Loading packages" spinner is appropriate. **No changes.**
- This entire section is "audit-confirm only" — the loading-state polish from prior milestones is judged adequate for v1.2.

##### 2.3.8 Empty state — "Show all packages" affordance

- **Existing copy** (keep): *"No packages match your current filters."* The current copy ends with manual instructions ("Try adjusting your category, CRAN status, or license selections, or clearing the search."). The Architect should **tighten this copy** so that once the action button exists, the long instruction list is not redundant — preference is to drop the manual instructions and let the button carry the affordance, but keeping them is acceptable if a strong UX argument applies.
- **New affordance**: a button labelled **"Show all packages"** placed below the empty-state message.
- **Button behaviour**: clears **all sidebar filters AND the search input** in a single action. The empty-state must update immediately when clicked.
- **Failure-mode protection**: if the button is clicked and results do not return immediately, users will assume the app is broken. The Architect must guarantee the reactive chain produces visible results in the same render cycle.

#### 2.4 Testing Strategy (Pillar 4)

##### 2.4.1 Posture

**(B) Minimal e2e smoke test.** The existing testthat unit/integration suite is preserved; v1.2 adds **one** end-to-end happy-path test as a tripwire against catastrophic regressions.

##### 2.4.2 Tooling

- **`{shinytest2}`** — the official Posit-supported e2e testing framework for Shiny. Runs in headless Chromium via `{chromote}`, integrates with testthat.
- **Test style**: **Assertion tests, not snapshot tests.** Snapshots multiply across modes/breakpoints and are brittle; assertion tests are stable and right-sized for a single happy-path tripwire.

##### 2.4.3 Happy-path scope

The single test must exercise the following sequence:

1. App loads.
2. Package table renders with a reasonable number of rows.
3. A category filter is applied; row count decreases.
4. A package row is clicked.
5. Detail view loads and displays the right package name.
6. User returns to the browse view.

This sequence implicitly verifies session establishment, parquet data loading, sidebar reactive propagation, reactable rendering, click handling, detail module mounting, and view navigation. It does **not** test the disconnect-and-reconnect flow (hard to simulate in a browser test — covered by manual verification in §2.6).

##### 2.4.4 CI integration

- The shinytest2 happy-path test must run **on PRs to `main` only** — not on every push to feature branches.
- Failure of the smoke test must block merge.
- The Architect should confirm GitHub Actions' Ubuntu runners have Chromium / Chrome preinstalled (they do) and add any required `setup-r-dependencies` steps for `{chromote}` and `{shinytest2}`.

#### 2.5 Accessibility (basic floor)

The accessibility task is a **dedicated v1.2 milestone**, not a constraint woven through other work. Reasoning: the existing app likely has issues that won't be caught by reviewing only new v1.2 changes; a dedicated pass surfaces those.

##### 2.5.1 Floor (in scope)

1. **Keyboard navigation works end-to-end.** A user with no mouse can open the app, use sidebar filters, search, tab to a package in the table, open the detail view, tab through detail content, and return to browse — with no tab traps and no invisible focus.
2. **Visible focus indicators** on every focusable element in both light and dark modes. Default Bootstrap focus rings are usually sufficient; custom CSS that erases them must be flagged.
3. **WCAG AA colour contrast** at minimum, in both modes. Specifically: the brand accent red, the badges (⭐ Featured / 📁 Archived), and the empty-state message must all clear AA.
4. **Skip-to-content link** so screen-reader and keyboard users don't tab through the entire navbar/sidebar to reach the table. Standard `<a class="visually-hidden-focusable">` pattern.
5. **`alt` text on every meaningful image** — package screenshots, example plots, any decorative-vs-meaningful image must be classified and labelled appropriately.

##### 2.5.2 Out of scope

- Full WCAG 2.2 AAA audit
- Screen-reader testing across NVDA/JAWS/VoiceOver
- ARIA live regions for dynamic content updates
- Reduced-motion variants for animations
- High-contrast mode beyond the dark/light toggle

##### 2.5.3 Definition of done

- Keyboard nav: Architect-tested manually, recorded as a checklist with steps and outcomes.
- Focus indicators: visual inspection in both modes (manual).
- Contrast: automated tool (axe DevTools, Lighthouse, or equivalent) reports zero AA contrast failures.
- Skip link: tab from page load — first focusable element is the skip link.
- Alt text: code-review confirmation that every `<img>` and meaningful `tags$img()` has an `alt` attribute.

##### 2.5.4 Sequencing constraint

The accessibility task must run **after** the visual audit (§2.3.5), brand-red application (§2.3.6), and connection-stability work (§2.1) — but **before** v1.2 release. Rationale: visual and CSS work may introduce or fix contrast issues; running a11y last measures the final state and sweeps in the new disconnect card UI for free.

##### 2.5.5 Partial answer to the e2e concern

The accessibility task is in part a manual e2e walkthrough (tab through the app, click into details, exercise filters) — it catches the same class of broken-interaction issue as automated e2e tests. Combined with the shinytest2 happy-path (§2.4), v1.2 has both an automated tripwire and a manual end-to-end pass. Fuller browser-test coverage remains a future consideration (see §10).

### 3. Data Model

#### 3.1 Changes to package entity

| Field | Source | Change Type | Notes |
|---|---|---|---|
| `is_featured` | `packages_curated.csv` | **Renamed** from `is_essential` | Same semantics, more honest naming. 1:1 with book-featured packages. |

No other data-model changes in v1.2. All other v1.1 fields (`is_archived`, `notes`, `version`, `latest_version`, `github_*` fallback fields, etc.) remain as shipped.

#### 3.2 Data sources

No new data sources. No changes to CRAN, cranlogs, or GitHub API usage.

#### 3.3 Storage

No changes — existing Parquet files via the existing targets pipeline, plus `data/github_descriptions.rds` cache from v1.1.

#### 3.4 Refresh pipeline

No changes to refresh frequency, triggers, or workflow files.

#### 3.5 JSON export schema migration (breaking)

- `is_essential` field is **removed** from `packages.json`.
- `is_featured` field is **added** in its place.
- This is a hard, breaking schema change. It must be called out in the v1.2 release notes and the README diff.

### 4. Non-Functional Requirements

#### 4.1 Performance

No significant change expected. Activity ping (~every 5 min while tab visible) and 30-min idle session survival are the only changes that touch runtime behaviour; both are designed to be low-cost.

#### 4.2 Hosting

No platform change — Docker on Google Cloud Run remains. Current Cloud Run configuration is preserved unless the Architect identifies a tuning need (e.g., to align with the 30-min idle window):

| Setting | Current value | v1.2 expectation |
|---|---|---|
| CPU | 1 vCPU | Unchanged |
| Memory | 512 MiB | Unchanged unless Architect demonstrates a need |
| Min instances | 0 | **Unchanged — scale-to-zero must be preserved** |
| Max instances | 3 | Unchanged |
| Concurrency | 80 | Unchanged |
| Request timeout | (current default) | May need adjustment to support 30-min sessions; Architect to confirm |

#### 4.3 Cost

- **Soft target**: ~$10/month additional Cloud Run cost post-v1.2.
- **Hard ceiling (alert threshold)**: $20/month total Cloud Run spend — set a Cloud Run billing alert at this threshold.
- **Realistic estimate at current traffic levels** (concurrency 80, scale-to-zero, community-tool audience): **+$3–5/month** likely; +$10/month worst case.
- **Dominant cost lever**: scale-to-zero (`--min-instances 0`) — must be preserved in v1.2 deployment configuration.
- **Activity ping constraint** (already stated in §2.1.4): Page Visibility API only — must not keep container alive when tab is backgrounded.
- **Rollback lever**: idle session timeout reducible from 30 min → 15 min via configuration change without rebuilding the image.

#### 4.4 Authentication

No change. App remains fully public, no login.

#### 4.5 Responsiveness

Mobile (b-posture) and desktop both supported. See §2.2 and §2.3 for specific requirements.

#### 4.6 Accessibility

Basic floor as defined in §2.5.

#### 4.7 Analytics

**No new analytics or tracking in v1.2.** This is a deliberate scope choice consistent with the community-tool posture.

#### 4.8 API rate limits

No change. No new external API usage.

### 5. User Experience

- **Connection-recovery card**: centered, theme-aware, accessible, clearly worded, single primary action ("Reload the app" or equivalent).
- **Mobile filter pattern**: drawer or accordion (Architect's call) — must feel native to mobile, not desktop-compressed.
- **Mobile browse view**: card list preferred but Architect's call between cards, hidden columns, or horizontal scroll.
- **Detail view**: no filter sidebar on any device; full-width content area on desktop.
- **Theme toggle**: top-right corner of navbar, icon-only sun/moon button, OS-aware default with localStorage persistence.
- **Header accordion**: open on first visit, closed on return visits, must not push the table below the fold on a 1440×900 desktop viewport when closed.
- **Intro copy**: rewritten to four-question structure (what / book connection / ⭐ meaning / curation tagline).
- **"⭐ Featured in the book"** is the new badge label; the filter is "Featured in the Book"; the underlying field is `is_featured`.
- **Empty state**: existing message + "Show all packages" button that clears all filters and search input in one click.
- **Brand accent**: shared red from book site / apps portfolio applied at theme level via `bs_theme(primary = …)`. Must clear WCAG AA in both modes.
- **Visual rhythm**: ranked top-10 list of polish items from the Architect's audit; maintainer approves/defers/rejects each.

### 6. Content

- **Intro accordion text**: rewritten per §2.3.3.
- **Connection-recovery card text**: written by the Architect, theme- and accessibility-aware.
- **Empty-state copy**: existing first sentence kept; instruction list trimmed in favour of the action button (preferred) or kept (acceptable).
- **All "essential" terminology** in user-facing copy must become "featured in the book" or close paraphrase. Internal documentation may retain "essential" in historical records (e.g., SPEC.md history sections) but new documentation written in v1.2 uses "featured."

### 7. Maintenance & Operations

- **Maintainer**: Solo (Antti) — no change.
- **Cost monitoring (new)**:
  1. Set a Cloud Run billing alert at **$20/month** total spend in GCP Billing → Budgets & alerts.
  2. Watch the Cloud Run console `Instance Time` metric for **2–4 weeks** post-v1.2 launch. If aggregated billed instance-seconds triple over the pre-v1.2 baseline, the keep-alive is more aggressive than expected and the rollback lever (idle window 30 min → 15 min) should be considered.
- **Submission handling**: unchanged from v1.1 (manual via Google Forms email).
- **Archiving workflow**: unchanged from v1.1 (manual via `is_archived` column).
- **Featured workflow (renamed from essential)**: unchanged operationally — manual via `is_featured` column post-rename.
- **Non-CRAN data**: unchanged from v1.1 (automated weekly via pipeline).
- **Smoke test maintenance**: the shinytest2 happy-path test runs on every PR to `main`; failures block merge. If the test becomes flaky, fix the flake — do not disable.

### 8. Constraints

- **Budget**: cost ceiling per §4.3.
- **Timeline**: no hard deadline. v1.2 ships when ready.
- **Technical constraints**:
  - Tech stack is locked to R/Shiny (parked, see §1).
  - Cloud Run scale-to-zero (`--min-instances 0`) must be preserved.
  - Activity ping must use Page Visibility API and only fire when the tab is visible.
  - shinytest2 tests must use assertion style, not snapshot style.
  - `bs_theme(primary = …)` is the preferred mechanism for brand-red application; raw CSS overrides are a fallback only.
- **Legal/licensing**: no new concerns.
- **Sequencing**: accessibility task must run after visual audit, brand-red application, and connection-stability work.

### 9. Prioritisation

| Requirement | Priority |
|---|---|
| Disconnect / reconnect card UI replacing grey overlay | Must-have |
| 30-min idle session survival (Cloud Run + Shiny tuning) | Must-have |
| Activity ping with Page Visibility API constraint | Must-have |
| Mobile sidebar pattern (drawer or accordion) | Must-have |
| Mobile browse view (cards or hidden columns) | Must-have |
| Filter sidebar hidden on detail view (all devices) | Must-have |
| Desktop sidebar open by default | Must-have |
| Theme toggle to top-right, icon-only, OS-aware default + localStorage | Must-have |
| Header accordion default state (open first / closed return) | Must-have |
| Above-the-fold table verification on 1440×900 | Must-have |
| Intro copy rewrite (4-question structure) | Must-have |
| `is_essential → is_featured` rename across full surface area | Must-have |
| Hard JSON schema rename with release-note callout | Must-have |
| Brand accent red applied via `bs_theme(primary = …)` | Must-have |
| Empty-state "Show all packages" button (clears filters + search) | Must-have |
| Visual audit (top ~10 items, ranked, with screenshots) | Must-have |
| Maintainer approval/defer/reject pass on audit items | Must-have |
| Implementation of approved audit items | Must-have |
| Accessibility floor (keyboard nav, focus, contrast, skip link, alt text) | Must-have |
| shinytest2 happy-path test in CI on PRs to main | Must-have |
| Cloud Run billing alert at $20/month | Must-have |
| Filter state preservation across reconnect | Nice-to-have |
| Tighten empty-state copy (drop manual instruction list) | Should-have |
| Per-mode brand-red shade variants (only if single value fails contrast) | Nice-to-have (contingency) |
| README update to reflect v1.2 changes | Must-have (final step) |

### 10. Parking Lot (Future Considerations)

Items captured during discovery that are explicitly out of scope for v1.2:

- **Tech-stack rewrite** (React, Next.js, etc.) — explicitly parked. Not revisiting.
- **SaaS-product trappings** — analytics dashboards, SEO funnels, social-preview / Open Graph image work, conversion tracking, A/B testing. Out of scope by design.
- **Full brand identity** — logo, wordmark, custom typography, favicon redesign, book-cover-derived imagery. Deferred to v1.3+ once the book is closer to finished.
- **Mobile-first redesign (posture c)** — would contradict the desktop-dominant audience reality.
- **Smart empty-state suggestions** — "Removing the 'Networks' filter would show 18 packages." Pattern-3 affordance, v1.3+ if at all.
- **Detail view loading skeleton** — current brief blank is acceptable; only revisit if the visual audit flags it as more jarring than remembered.
- **Comprehensive shinytest2 suite** (Posture C) — covering all flows, themes, breakpoints. Out of scope; happy-path tripwire is the right ROI for a community tool.
- **Snapshot-based visual regression testing** — too brittle for the maintenance burden a solo maintainer can absorb.
- **Full WCAG 2.2 AAA audit, screen-reader matrix, reduced-motion variants, ARIA live regions** — accessibility is a basic floor in v1.2; deeper a11y work is a future project.
- **Automated CRAN/GitHub archive detection** (already parked from v1.1).
- **Automated GitHub issue creation from Google Form submissions** (already parked from v1.1).
- **In-app submission status tracking / feedback to submitters** (already parked from v1.1).
- **Spam protection on the Google Form** (already parked from v1.1).
- **Download trend chart** (already parked from v1.1).

### 11. Open Questions

| # | Question | Context | Who Resolves |
|---|---|---|---|
| 1 | What is the exact hex value of the shared brand red? | Must be obtained from `https://ggplot2-extended-book.com/` or `https://youcanbeapirate.com/` rather than eyeballed. Used in `bs_theme(primary = …)`. | Solution Architect (read from canonical source) |
| 2 | What is the right activity-ping interval? | Stakeholder agreed "lightweight" and target was sketched as ~5 min. Architect to finalise based on Cloud Run cost vs. session-keepalive trade-off. | Solution Architect |
| 3 | Drawer vs. accordion for the mobile sidebar? | Both acceptable; Architect picks based on bslib idioms and visual coherence. | Solution Architect |
| 4 | Card list vs. hidden columns for the mobile browse view? | Stakeholder leans cards but defers. If cards, decide whether desktop also gets cards or only mobile diverges. | Solution Architect |
| 5 | How to implement "follow OS live until user makes an explicit choice" for the theme toggle? | `bslib::input_dark_mode()` covers most of the behaviour; the "track explicit choice" nuance may need custom JS. | Solution Architect |
| 6 | Conditional sidebar render vs. per-view layout swap for hiding the sidebar on detail view? | Both acceptable; per-view layout swap is architecturally cleaner but may require restructuring `app_ui.R`. | Solution Architect |
| 7 | Does the existing Cloud Run request timeout support 30-min sessions, or does it need explicit adjustment? | Cloud Run defaults may terminate WebSocket connections earlier than the configured Shiny `sessionTimeout`. | Solution Architect / Developer (verify in deployment) |
| 8 | Final copy wording for the "Your session expired" card? | Architect drafts; maintainer reviews. | Solution Architect → Maintainer |
| 9 | Final intro accordion copy (four-question structure)? | Architect or maintainer drafts; the other reviews. | Maintainer (with Architect input) |
| 10 | If the brand red fails contrast in one mode, are per-mode shade variants acceptable, or should we pick a single value that clears both? | Stakeholder allowed per-mode variants as a contingency; Architect to recommend based on what the actual hex produces. | Solution Architect |
| 11 | Tighten the empty-state copy by dropping the manual instruction list, or keep it as belt-and-braces alongside the new button? | Stakeholder's default lean is "tighten." Open if a strong UX argument applies. | Solution Architect |
| 12 | Which v1.2 work items can run in parallel vs. which depend on others? Sequencing constraint already stated: a11y after visual + brand + connection. Other dependencies? | Affects milestone planning. | Solution Architect |
