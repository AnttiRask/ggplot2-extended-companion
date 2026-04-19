## Why

The "Suggest a Package" button in the sidebar and "Submit it here" link in the footer are currently disabled placeholders. With the Google Form created, both links can be activated.

## What Changes

- Add `google_form_url` to `inst/golem-config.yml`
- Activate sidebar "Suggest a Package" button: real href, target=_blank, remove disabled class
- Activate footer "Submit it here" link: change span to anchor tag

## Capabilities

### New Capabilities
- `package-submission-links`: Activated submission links in sidebar and footer

### Modified Capabilities

## Impact

- **Code**: `R/mod_sidebar.R`, `R/mod_footer.R`, `inst/golem-config.yml`
