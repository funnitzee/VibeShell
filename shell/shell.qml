import Quickshell
import qs.bar
import qs.dashboard
import qs.lock
import qs.notify
import qs.osd
import qs.palette
import qs.quick
import qs.services
import qs.greeter
import qs.keys
import qs.settings

ShellRoot {
    // Headless services, kept alive for the whole session (idle locking, app
    // theme generation on palette change, the saved wallpaper, night light and
    // power profiles).
    readonly property var idle: Idle
    readonly property var theming: AppTheming
    readonly property var wallpaper: Wallpaper
    readonly property var clipboard: Clipboard
    readonly property var screenshot: Screenshot
    readonly property var nightLight: NightLight
    readonly property var powerProfiles: PowerProfiles

    Bar {}
    Palette {}
    Dashboard {}
    Osd {}
    QuickSettings {}
    SettingsWindow {}
    Keys {}
    Notify {}
    LockScreen {}
    Greeter {}
}
