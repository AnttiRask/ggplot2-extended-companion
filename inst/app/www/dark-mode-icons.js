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
// Approach: observe data-bs-theme changes on <html> and override
// the toggle button's internal data-theme attribute to the opposite
// value, which tricks the component into showing the "wrong" icon
// (which is actually the one the user expects).
// =============================================================================

document.addEventListener("DOMContentLoaded", function() {
  function swapToggleIcon() {
    var toggle = document.querySelector("bslib-input-dark-mode");
    if (!toggle || !toggle.shadowRoot) {
      setTimeout(swapToggleIcon, 100);
      return;
    }

    var button = toggle.shadowRoot.querySelector("button");
    if (!button) {
      setTimeout(swapToggleIcon, 100);
      return;
    }

    // Swap the button's data-theme to the opposite of the actual theme.
    // This makes the component render the "target" icon instead of "current".
    function updateIcon() {
      var currentTheme = document.documentElement.getAttribute("data-bs-theme");
      var opposite = (currentTheme === "dark") ? "light" : "dark";
      button.setAttribute("data-theme", opposite);
    }

    // Initial swap
    updateIcon();

    // Watch for theme changes
    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        if (mutation.attributeName === "data-bs-theme") {
          // Small delay to let the component update first, then override
          setTimeout(updateIcon, 50);
        }
      });
    });

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-bs-theme"]
    });
  }

  swapToggleIcon();
});
