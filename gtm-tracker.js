(function() {
  var lastPath = '';

  function trackPageView() {
    var currentPath = window.location.pathname + window.location.search + window.location.hash;
    
    // Prevent logging duplicate triggers on the same page state
    if (currentPath === lastPath) return;
    lastPath = currentPath;

    window.dataLayer = window.dataLayer || [];
    window.dataLayer.push({
      'event': 'virtual_page_view',
      'page_path': currentPath,
      'page_title': document.title || currentPath
    });
  }

  // Intercept Flutter SPA routing (context.push / context.go)
  var origPushState = history.pushState;
  history.pushState = function() {
    origPushState.apply(this, arguments);
    setTimeout(trackPageView, 100);
  };

  var origReplaceState = history.replaceState;
  history.replaceState = function() {
    origReplaceState.apply(this, arguments);
    setTimeout(trackPageView, 100);
  };

  // Track browser back/forward buttons and hash changes
  window.addEventListener('popstate', function() { setTimeout(trackPageView, 100); });
  window.addEventListener('hashchange', function() { setTimeout(trackPageView, 100); });

  // Track initial load on static HTML pages (e.g., /blog/)
  window.addEventListener('DOMContentLoaded', trackPageView);
})();