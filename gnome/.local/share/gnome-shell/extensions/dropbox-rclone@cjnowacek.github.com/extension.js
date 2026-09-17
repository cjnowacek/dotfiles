/* Dropbox (rclone) top-bar indicator for GNOME Shell 40-44 (legacy imports).
 *
 * Mirrors waybar/.config/waybar/scripts/dropbox-status.sh + the
 * custom/dropbox module: Nerd Font dropbox glyph + "Dropbox", blue when
 * ~/Dropbox is an rclone FUSE mount, red ("Dropbox down") otherwise.
 * Left-click: mount if needed, then open ~/Dropbox in yazi inside kitty.
 * Right-click: menu with Open / Mount|Unmount / Restart.
 * Polls /proc/mounts every 10 s; no subprocess for status.
 */
const { Clutter, GLib, GObject, St } = imports.gi;
const Main = imports.ui.main;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;
const Util = imports.misc.util;

const SERVICE = 'rclone-dropbox.service';
const MOUNT = GLib.get_home_dir() + '/Dropbox';
const GLYPH = '\u{F01E5}';   // nf-md-dropbox, same code point waybar uses
const POLL_SECONDS = 10;

function isMounted() {
    try {
        const [ok, bytes] = GLib.file_get_contents('/proc/mounts');
        if (!ok)
            return false;
        const text = imports.byteArray.toString(bytes);
        return text.split('\n').some(line => {
            const f = line.split(' ');
            return f[1] === MOUNT && f[2].startsWith('fuse');
        });
    } catch (e) {
        return false;
    }
}

function systemctl(verb) {
    Util.spawn(['systemctl', '--user', verb, SERVICE]);
}

const Indicator = GObject.registerClass(
class DropboxRcloneIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'Dropbox (rclone)', false);

        this._label = new St.Label({
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'dropbox-rclone-label',
        });
        this.add_child(this._label);

        this._statusItem = new PopupMenu.PopupMenuItem('', { reactive: false });
        this.menu.addMenuItem(this._statusItem);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.menu.addAction('Open Dropbox', () => this._open());
        this._toggleItem = this.menu.addAction('Mount', () => this._toggle());
        this.menu.addAction('Restart mount', () => {
            systemctl('restart');
            this._scheduleRefresh(2);
        });

        this._mounted = null;
        this._refresh();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, POLL_SECONDS, () => {
            this._refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    // Left button = open (like waybar on-click); everything else = menu.
    vfunc_event(event) {
        if (event.type() === Clutter.EventType.BUTTON_PRESS && event.get_button() === 1) {
            this._open();
            return Clutter.EVENT_STOP;
        }
        return super.vfunc_event(event);
    }

    _open() {
        if (!isMounted()) {
            systemctl('start');
            this._scheduleRefresh(2);
            // give the FUSE mount a moment before yazi cds into it
            GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
                Util.spawn(['kitty', '-e', 'yazi', MOUNT]);
                return GLib.SOURCE_REMOVE;
            });
        } else {
            Util.spawn(['kitty', '-e', 'yazi', MOUNT]);
        }
    }

    _toggle() {
        systemctl(isMounted() ? 'stop' : 'start');
        this._scheduleRefresh(2);
    }

    _scheduleRefresh(seconds) {
        GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, seconds, () => {
            this._refresh();
            return GLib.SOURCE_REMOVE;
        });
    }

    _refresh() {
        const mounted = isMounted();
        if (mounted === this._mounted)
            return;
        this._mounted = mounted;
        this._label.text = mounted ? `${GLYPH}  Dropbox` : `${GLYPH}  Dropbox down`;
        this._label.remove_style_class_name(mounted ? 'dropbox-rclone-unmounted' : 'dropbox-rclone-mounted');
        this._label.add_style_class_name(mounted ? 'dropbox-rclone-mounted' : 'dropbox-rclone-unmounted');
        this._statusItem.label.text = mounted
            ? 'Dropbox mounted (rclone on-demand)'
            : 'Dropbox NOT mounted';
        this._toggleItem.label.text = mounted ? 'Unmount' : 'Mount';
    }

    destroy() {
        if (this._timer) {
            GLib.source_remove(this._timer);
            this._timer = null;
        }
        super.destroy();
    }
});

let indicator = null;

function init() {}

function enable() {
    indicator = new Indicator();
    // Leftmost of the right box, like waybar's modules-right order.
    Main.panel.addToStatusArea('dropbox-rclone', indicator, 0, 'right');
}

function disable() {
    if (indicator) {
        indicator.destroy();
        indicator = null;
    }
}
