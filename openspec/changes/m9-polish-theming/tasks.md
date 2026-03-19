## 1. Loading States & Error Handling

- [x] 1.1 Add loading spinner to mod_browse.R while table renders
- [x] 1.2 Loading spinner via conditionalPanel + table_ready output flag
- [x] 1.3 Add structured logging to app_server.R for startup and data loading
- [x] 1.4 User-friendly empty state when data files are missing (already in browse module)

## 2. CSS Polish

- [x] 2.1 Refine styles.css — loading spinner, code block, footer, search input, accordion, sidebar
- [x] 2.2 Loading spinner uses Bootstrap spinner-border with primary colour
- [x] 2.3 Dark/light mode overrides for code blocks, footer, reactable search

## 3. App UI Polish

- [x] 3.1 Dark mode is default (set in M0), toggle works (input_dark_mode in M0)
- [x] 3.2 Favicon reference in place via golem bundle_resources

## 4. Verification

- [x] 4.1 Run full test suite — 226 pass, 3 skip
- [x] 4.2 App launches with loading spinner, all components styled
