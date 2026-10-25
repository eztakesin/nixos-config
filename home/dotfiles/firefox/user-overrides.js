/***********************************************************
 * user-overrides.js — applied after the pinned arkenfox user.js
 * (home/modules/firefox.nix concatenates both at build time; Firefox
 * applies user_pref in file order, so the last assignment wins).
 *
 * Priorities: RFP + letterboxing, WebRTC off, WebGL off, push off;
 * JS JIT / WASM / Service Workers on. DNS is delegated to the system
 * (mihomo / resolved). Verify in about:config: _my_overrides.parrot
 ***********************************************************/

user_pref("_my_overrides.parrot", "START: user-overrides.js loaded");

/*** 0100 Startup ***/
user_pref("browser.startup.page", 3);

/*** Passwords / autofill: all off (managed outside the browser) ***/
user_pref("signon.rememberSignons", false);
user_pref("signon.generation.enabled", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("signon.firefoxRelay.feature", "disabled");

/*** GPC — legally binding in some jurisdictions, worth the fingerprint bit ***/
user_pref("privacy.globalprivacycontrol.enabled", true);

/*** Telemetry channels newer than arkenfox 144 ***/
user_pref("datareporting.usage.uploadEnabled", false);
user_pref("browser.ping-centre.telemetry", false);

/*** Built-in VPN off (mihomo handles routing) ***/
user_pref("browser.ipProtection.enabled", false);

/*** AI features off ***/
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("browser.ml.chat.enabled", false);

/*** Local translation ***/
user_pref("browser.translations.alwaysTranslateLanguages", "th,vi,de,es,fr,da,sv,nb,fi,is");
user_pref("browser.translations.neverTranslateLanguages", "zh-Hans,zh-Hant,ja,en");

/*** Links / motion / density ***/
user_pref("layout.css.always_underline_links", true);
user_pref("general.smoothScroll", true);
user_pref("browser.uidensity", 1);

/*** userChrome.css is only read when this is true ***/
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

/*** Theme (installed from AMO; the selection is pinned here) ***/
user_pref("extensions.activeThemeID", "{cc29223b-6794-43bb-9dfb-54487bef733a}");

/*** 0700 DNS: delegate to the system resolver (mihomo when up) ***/
user_pref("network.trr.mode", 5);
user_pref("network.trr.uri", "");
user_pref("network.trr.custom_uri", "");

/*** 0700 Proxy bypass ***/
user_pref("network.proxy.allow_bypass", false);

/*** 1200 HTTPS-Only & local dev ***/
user_pref("dom.security.https_only_mode.upgrade_local", false);
user_pref("security.mixed_content.block_display_content", true);

/*** 1700 Container tabs ***/
user_pref("privacy.userContext.newTabContainerOnLeftClick.enabled", true);

/*** 2700 Anti-tracking (strict) ***/
user_pref("privacy.antitracking.enableWebcompat", false);

/*** 4500 RFP ***/
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);
user_pref("privacy.spoof_english", 2);
user_pref("privacy.resistFingerprinting.exemptedDomains", "");

/*** 2000 WebRTC off ***/
user_pref("media.peerconnection.enabled", false);

/*** 4520 WebGL off ***/
user_pref("webgl.disabled", true);

/*** 7000 Modern web ***/
user_pref("dom.serviceWorkers.enabled", true);
user_pref("dom.push.enabled", false);
user_pref("dom.webnotifications.enabled", false);

/*** Performance ***/
user_pref("gfx.webrender.all", true);
user_pref("fission.autostart", true);
user_pref("javascript.options.ion", true);
user_pref("javascript.options.baselinejit", true);
user_pref("javascript.options.wasm", true);

/*** 2800 Clear on shutdown ***/
user_pref("privacy.clearOnShutdown_v2.historyFormDataAndDownloads", true);
user_pref("privacy.clearOnShutdown_v2.browsingHistoryAndDownloads", true);
user_pref("privacy.clearOnShutdown_v2.downloads", true);
user_pref("privacy.clearOnShutdown_v2.formdata", true);
user_pref("privacy.sanitize.timeSpan", 0);

/*** 0800 URL bar ***/
user_pref("browser.urlbar.clipboard.featureGate", false);
user_pref("browser.urlbar.recentsearches.featureGate", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.maxRichResults", 0);
user_pref("browser.urlbar.autoFill", false);
user_pref("keyword.enabled", false);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("sidebar.revamp", false);

/*** Fonts: fontconfig chooses. The generic names below hand every page to the per-language rules in
 *   modules/nixos/locale-fonts.nix (Noto CJK SC/TC/HK/JP/KR, Sarasa Mono); text without a language
 *   tag is treated as Simplified Chinese, so ambiguous Han characters get SC forms. Pattern from oxalica's
 *   nixos-config (home/modules/firefox.nix, "Let our font-config choose final fonts"). ***/
user_pref("font.language.group", "zh-CN");
user_pref("font.name.monospace.zh-CN", "monospace");
user_pref("font.name.sans-serif.zh-CN", "sans-serif");
user_pref("font.name.serif.zh-CN", "serif");
user_pref("font.cjk_pref_fallback_order", "zh-cn,zh-hk,zh-tw,ja");

user_pref("_my_overrides.parrot", "END: user-overrides.js loaded");
