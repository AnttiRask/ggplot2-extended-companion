// =============================================================================
// dark-mode-icons.js
//
// Swaps the bslib dark/light mode toggle icons so that:
// - Sun shows in dark mode (meaning "click to switch to light")
// - Moon shows in light mode (meaning "click to switch to dark")
//
// bslib's default shows the current mode icon (moon = dark active,
// sun = light active). Users expect the target mode icon instead.
//
// The toggle uses shadow DOM, so we inject CSS directly into it.
// =============================================================================

document.addEventListener("DOMContentLoaded", function() {
  // Wait for the custom element to be defined and rendered
  function injectSwapCSS() {
    var toggle = document.querySelector("bslib-input-dark-mode");
    if (!toggle || !toggle.shadowRoot) {
      // Retry until the component is ready
      setTimeout(injectSwapCSS, 100);
      return;
    }

    var style = document.createElement("style");
    style.textContent = [
      // In dark mode: show sun (the "switch to light" icon)
      '[data-theme="dark"] .sun-and-moon > .sun {',
      '  transform: scale(1) !important;',
      '}',
      '[data-theme="dark"] .sun-and-moon > .sun-beams {',
      '  opacity: 1 !important;',
      '}',
      '[data-theme="dark"] .sun-and-moon > .moon > circle {',
      '  transform: translateX(0) !important;',
      '}',
      '@supports (cx: 1) {',
      '  [data-theme="dark"] .sun-and-moon > .moon > circle {',
      '    cx: 25 !important;',
      '  }',
      '}',
      // In light mode: show moon (the "switch to dark" icon)
      '[data-theme="light"] .sun-and-moon > .sun {',
      '  transform: scale(1.6) !important;',
      '}',
      '[data-theme="light"] .sun-and-moon > .sun-beams {',
      '  opacity: 0 !important;',
      '}',
      '[data-theme="light"] .sun-and-moon > .moon > circle {',
      '  transform: translateX(-10px) !important;',
      '}',
      '@supports (cx: 1) {',
      '  [data-theme="light"] .sun-and-moon > .moon > circle {',
      '    cx: 15 !important;',
      '  }',
      '}'
    ].join("\n");

    toggle.shadowRoot.appendChild(style);
  }

  injectSwapCSS();
});
