// Firefox lee user.js al arrancar y copia estas preferencias a prefs.js.
// (dotfiles/firefox — perfil skxgxs8p.default-release)
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // activa chrome/userChrome.css y userContent.css
user_pref("layout.css.prefers-color-scheme.content-override", 0);       // las webs en modo oscuro cuando lo soporten
user_pref("browser.theme.content-theme", 0);
user_pref("browser.theme.toolbar-theme", 0);
