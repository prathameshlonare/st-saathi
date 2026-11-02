(function () {
  var toggle = document.getElementById('lang-toggle');
  var html = document.documentElement;

  if (!toggle) return;

  function setLang(lang) {
    html.dataset.lang = lang;
    html.lang = lang === 'mr' ? 'mr' : 'en';
    toggle.setAttribute('aria-pressed', lang === 'mr');
    toggle.textContent = lang === 'mr' ? 'मराठी | English' : 'EN | MR';
  }

  toggle.addEventListener('click', function () {
    var next = html.dataset.lang === 'mr' ? 'en' : 'mr';
    setLang(next);
    try { localStorage.setItem('stsaathi-lang', next); } catch (e) {}
  });

  try {
    var saved = localStorage.getItem('stsaathi-lang');
    if (saved === 'mr' || saved === 'en') setLang(saved);
  } catch (e) {}
})();
