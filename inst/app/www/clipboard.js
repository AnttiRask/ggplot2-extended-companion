// =============================================================================
// clipboard.js
//
// Copy-to-clipboard functionality for code example blocks.
// Called from the code example card in the detail view.
//
// Part of Milestone 6: Code Examples Pipeline & Display
// =============================================================================

/**
 * Copy text content to the clipboard and provide visual feedback.
 *
 * @param {string} elementId - The ID of the <code> element containing the text.
 * @param {string} buttonId - The ID of the button element for feedback.
 */
function copyCodeToClipboard(elementId, buttonId) {
  var codeElement = document.getElementById(elementId);
  var button = document.getElementById(buttonId);

  if (!codeElement) return;

  var text = codeElement.textContent || codeElement.innerText;

  navigator.clipboard.writeText(text).then(function() {
    // Visual feedback: change button text briefly
    if (button) {
      var originalText = button.textContent;
      button.textContent = "Copied!";
      setTimeout(function() {
        button.textContent = originalText;
      }, 2000);
    }
  }).catch(function(err) {
    // Fallback for older browsers
    console.warn("Clipboard API failed, using fallback:", err);
    var textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.style.position = "fixed";
    textArea.style.left = "-9999px";
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand("copy");
    document.body.removeChild(textArea);

    if (button) {
      var originalText = button.textContent;
      button.textContent = "Copied!";
      setTimeout(function() {
        button.textContent = originalText;
      }, 2000);
    }
  });
}
