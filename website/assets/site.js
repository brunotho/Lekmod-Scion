// Changelog filters (versions, tags, search; kept in the URL), civ search, sidebar highlighting and
// the phone sidebar toggle. Without JavaScript every page still shows everything.
(function () {
  "use strict";

  var $ = function (sel, root) { return (root || document).querySelector(sel); };
  var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };

  // --- Changelog --------------------------------------------------------------------------------
  var controls = $("#controls");
  if (controls) {
    var fromSel = $("#from"), toSel = $("#to"), search = $("#search"), clear = $("#clear");
    var tagButtons = $$(".tag", controls);
    var cards = $$("#changelog .card");
    var defaults = { from: fromSel.value, to: toSel.value };

    var readUrl = function () {
      var p = new URLSearchParams(location.search);
      if (p.get("from") !== null && $('option[value="' + p.get("from") + '"]', fromSel)) fromSel.value = p.get("from");
      if (p.get("to") !== null && $('option[value="' + p.get("to") + '"]', toSel)) toSel.value = p.get("to");
      search.value = p.get("q") || "";
      var tags = (p.get("tags") || "").split(",").filter(Boolean);
      tagButtons.forEach(function (b) { b.setAttribute("aria-pressed", tags.indexOf(b.dataset.tag) >= 0 ? "true" : "false"); });
    };

    var selectedTags = function () {
      return tagButtons.filter(function (b) { return b.getAttribute("aria-pressed") === "true"; })
        .map(function (b) { return b.dataset.tag; });
    };

    var writeUrl = function () {
      var p = new URLSearchParams();
      if (fromSel.value !== defaults.from) p.set("from", fromSel.value);
      if (toSel.value !== defaults.to) p.set("to", toSel.value);
      if (search.value.trim()) p.set("q", search.value.trim());
      var tags = selectedTags();
      if (tags.length) p.set("tags", tags.join(","));
      var qs = p.toString();
      history.replaceState(null, "", location.pathname + (qs ? "?" + qs : "") + location.hash);
    };

    var apply = function () {
      var from = parseInt(fromSel.value, 10), to = parseInt(toSel.value, 10);
      if (from >= to) { from = to - 1; }
      var tags = selectedTags();
      var words = search.value.toLowerCase().split(/\s+/).filter(Boolean);
      var anyVisible = false;
      cards.forEach(function (card) {
        var visibleEntries = 0;
        $$(".entry", card).forEach(function (e) {
          var r = parseInt(e.dataset.release, 10);
          var show = r > from && r <= to;
          e.hidden = !show;
          if (show) visibleEntries++;
        });
        var cardTags = card.dataset.tags.split("|");
        var tagOk = tags.length === 0 || tags.some(function (t) { return cardTags.indexOf(t) >= 0; });
        var text = card.dataset.search;
        var searchOk = words.every(function (w) { return text.indexOf(w) >= 0; });
        card.hidden = !(visibleEntries > 0 && tagOk && searchOk);
        card.classList.toggle("multi", visibleEntries > 1);
        if (!card.hidden) anyVisible = true;
      });
      $$("#changelog .subsection").forEach(function (m) {
        m.hidden = $$(".card", m).every(function (c) { return c.hidden; });
      });
      $$("#changelog .group").forEach(function (g) {
        var n = $$(".card", g).filter(function (c) { return !c.hidden; }).length;
        g.hidden = n === 0;
        var count = $('[data-count-for="' + g.dataset.section + '"]');
        if (count) {
          count.textContent = n;
          count.parentNode.parentNode.hidden = n === 0;
        }
      });
      $("#no-results").hidden = anyVisible;
      clear.hidden = !(tags.length || words.length);
      writeUrl();
      updateActive();
    };

    tagButtons.forEach(function (b) {
      b.addEventListener("click", function () {
        b.setAttribute("aria-pressed", b.getAttribute("aria-pressed") === "true" ? "false" : "true");
        apply();
      });
    });
    [fromSel, toSel].forEach(function (s) { s.addEventListener("change", apply); });
    search.addEventListener("input", apply);
    clear.addEventListener("click", function () {
      search.value = "";
      tagButtons.forEach(function (b) { b.setAttribute("aria-pressed", "false"); });
      apply();
    });
    readUrl();
    apply();
  }

  // --- Civ list search ---------------------------------------------------------------------------
  var civSearch = $("#civ-search");
  if (civSearch) {
    var civs = $$("#civlist .civ");
    civSearch.addEventListener("input", function () {
      var words = civSearch.value.toLowerCase().split(/\s+/).filter(Boolean);
      civs.forEach(function (c) {
        var text = c.dataset.search;
        c.hidden = !words.every(function (w) { return text.indexOf(w) >= 0; });
        var link = $('[data-section-link="' + c.dataset.section + '"]');
        if (link) link.parentNode.hidden = c.hidden;
      });
      updateActive();
    });
  }

  // --- Sidebar: highlight the section in view; phone toggle ----------------------------------------
  function updateActive() {
    var sections = $$("[data-section]").filter(function (s) { return !s.hidden; });
    if (!sections.length) return;
    var line = (parseInt(getComputedStyle(document.documentElement).getPropertyValue("--header-h"), 10) || 56) + 24;
    var current = sections[0];
    sections.forEach(function (s) { if (s.getBoundingClientRect().top <= line) current = s; });
    $$("[data-section-link]").forEach(function (a) {
      a.classList.toggle("active", a.dataset.sectionLink === current.dataset.section);
    });
  }
  var ticking = false;
  window.addEventListener("scroll", function () {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () { ticking = false; updateActive(); });
  }, { passive: true });
  updateActive();

  var toggle = $(".sidebar-toggle"), sidebar = $("#sidebar");
  if (toggle && sidebar) {
    toggle.addEventListener("click", function () {
      var open = sidebar.classList.toggle("open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
    $$("a", sidebar).forEach(function (a) {
      a.addEventListener("click", function () {
        sidebar.classList.remove("open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  // Download buttons: point straight at the newest release's zip (GitHub API); without it they open the release page.
  var latest = {};
  $$("[data-latest-asset]").forEach(function (a) {
    var repo = a.dataset.latestAsset;
    if (!latest[repo]) {
      latest[repo] = fetch("https://api.github.com/repos/" + repo + "/releases/latest")
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (rel) {
          var zip = rel && (rel.assets || []).filter(function (x) { return /\.zip$/i.test(x.name); })[0];
          return zip ? zip.browser_download_url : null;
        })
        .catch(function () { return null; });
    }
    latest[repo].then(function (url) { if (url) a.href = url; });
  });

  // Policy trees: hovering or focusing a policy shows its text in the panel below the tree.
  $$(".ptree").forEach(function (tree) {
    var panel = $(".ptree-panel", tree);
    $$(".pnode, .pbar", tree).forEach(function (btn) {
      btn.removeAttribute("title");
      var show = function () {
        $$(".active", tree).forEach(function (x) { x.classList.remove("active"); });
        btn.classList.add("active");
        panel.innerHTML = btn.dataset.help || "";
        panel.classList.add("filled");
      };
      btn.addEventListener("mouseenter", show);
      btn.addEventListener("focus", show);
      btn.addEventListener("click", show);
    });
  });

  // Close the page menu when clicking elsewhere.
  document.addEventListener("click", function (e) {
    $$(".page-menu[open]").forEach(function (d) { if (!d.contains(e.target)) d.removeAttribute("open"); });
  });
})();
