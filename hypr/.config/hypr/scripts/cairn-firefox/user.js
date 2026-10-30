// Cairn's own Firefox profile (cairn-launch.sh): one window, the page and
// nothing else, like the page's "pop out" window.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("browser.tabs.inTitlebar", 0);
user_pref("browser.sessionstore.resume_from_crash", false);
// A link out of Cairn opens a window of its own, never a hidden tab.
user_pref("browser.link.open_newwindow", 2);
user_pref("browser.link.open_newwindow.restriction", 0);
