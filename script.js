(function () {
  'use strict';

  // DOM Elements
  var html = document.documentElement;
  var langToggle = document.getElementById('langToggle');
  var navToggle = document.getElementById('navToggle');
  var navLinks = document.querySelector('.nav-links');
  var downloadBtn = document.getElementById('downloadBtn');
  var navDownloadBtn = document.getElementById('navDownloadBtn');
  var versionBadge = document.getElementById('versionBadge');
  var mockSwapBtn = document.getElementById('mockSwapBtn');
  var originStation = document.getElementById('originStation');
  var destStation = document.getElementById('destStation');

  var DEFAULT_RELEASE_URL = 'https://github.com/prathameshlonare/st-saathi/releases/latest';

  // 1. Language Management
  function setLanguage(lang) {
    var validLang = (lang === 'mr') ? 'mr' : 'en';
    html.dataset.lang = validLang;
    html.lang = validLang;

    if (langToggle) {
      langToggle.setAttribute('aria-label', validLang === 'mr' ? 'Switch to English' : 'मराठीमध्ये बदला');
      var langLabel = langToggle.querySelector('.lang-btn-text');
      if (langLabel) {
        langLabel.textContent = validLang === 'mr' ? 'English' : 'मराठी';
      }
    }

    try {
      localStorage.setItem('stsaathi-lang', validLang);
    } catch (e) {
      // LocalStorage unavailable in strict privacy contexts
    }
  }

  // Initialize Language from preference, storage, or browser locale
  var initialLang = 'en';
  try {
    var stored = localStorage.getItem('stsaathi-lang');
    if (stored === 'mr' || stored === 'en') {
      initialLang = stored;
    } else if (navigator.language && navigator.language.toLowerCase().startsWith('mr')) {
      initialLang = 'mr';
    }
  } catch (e) {}
  setLanguage(initialLang);

  if (langToggle) {
    langToggle.addEventListener('click', function () {
      var current = html.dataset.lang || 'en';
      var next = (current === 'mr') ? 'en' : 'mr';
      setLanguage(next);
    });
  }

  // Mobile Navigation Drawer Toggle
  if (navToggle && navLinks) {
    function closeNav(returnFocus) {
      if (navToggle.getAttribute('aria-expanded') === 'true') {
        navToggle.setAttribute('aria-expanded', 'false');
        navLinks.classList.remove('is-open');
        if (returnFocus) {
          navToggle.focus();
        }
      }
    }

    navToggle.addEventListener('click', function () {
      var isExpanded = navToggle.getAttribute('aria-expanded') === 'true';
      navToggle.setAttribute('aria-expanded', isExpanded ? 'false' : 'true');
      navLinks.classList.toggle('is-open');
    });

    var navAnchors = navLinks.querySelectorAll('a');
    for (var i = 0; i < navAnchors.length; i++) {
      navAnchors[i].addEventListener('click', function () {
        closeNav(false);
      });
    }

    document.addEventListener('click', function (e) {
      if (!navToggle.contains(e.target) && !navLinks.contains(e.target)) {
        closeNav(false);
      }
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' || e.key === 'Esc') {
        closeNav(true);
      }
    });
  }

  // 2. Dynamic Release Metadata Fetcher
  function applyReleaseData(version, downloadUrl) {
    if (version && versionBadge) {
      versionBadge.textContent = version;
    }
    var targetUrl = downloadUrl || DEFAULT_RELEASE_URL;
    if (downloadBtn) downloadBtn.href = targetUrl;
    if (navDownloadBtn) navDownloadBtn.href = targetUrl;
  }

  function loadReleaseMetadata() {
    // 1. First attempt: Query live GitHub Releases API for real-time tag and APK URL
    fetch('https://api.github.com/repos/prathameshlonare/st-saathi/releases/latest', {
      headers: { 'Accept': 'application/vnd.github.v3+json' }
    })
      .then(function (res) {
        if (!res.ok) throw new Error('GitHub API response status: ' + res.status);
        return res.json();
      })
      .then(function (release) {
        var version = release.tag_name || release.name;
        var apkAsset = release.assets && release.assets.find(function (a) {
          return a.name && a.name.toLowerCase().endsWith('.apk');
        });
        var directUrl = (apkAsset && apkAsset.browser_download_url) || release.html_url || DEFAULT_RELEASE_URL;
        applyReleaseData(version, directUrl);
      })
      .catch(function () {
        // 2. Second attempt: Fall back to repository release-metadata.json
        return fetch('release-metadata.json')
          .then(function (res) {
            if (!res.ok) throw new Error('Local metadata not found');
            return res.json();
          })
          .then(function (data) {
            applyReleaseData(data.versionName, data.downloadUrl);
          })
          .catch(function () {
            // 3. Graceful degradation: buttons point to releases page, badge retains clean label
            applyReleaseData(null, DEFAULT_RELEASE_URL);
          });
      });
  }
  loadReleaseMetadata();

  // 3. Interactive Phone Simulation (Swap Stations)
  if (mockSwapBtn && originStation && destStation) {
    mockSwapBtn.addEventListener('click', function () {
      var origEn = originStation.querySelector('.lang-en');
      var origMr = originStation.querySelector('.lang-mr');
      var destEn = destStation.querySelector('.lang-en');
      var destMr = destStation.querySelector('.lang-mr');

      if (origEn && origMr && destEn && destMr) {
        var tempEn = origEn.textContent;
        var tempMr = origMr.textContent;

        origEn.textContent = destEn.textContent;
        origMr.textContent = destMr.textContent;

        destEn.textContent = tempEn;
        destMr.textContent = tempMr;
      }
    });
  }
})();
