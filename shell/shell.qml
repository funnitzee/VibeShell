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
import qs.settings

ShellRoot {
    // Headless services, kept alive for the whole session (idle locking and
    // app theme generation on palette change).
    readonly property var idle: Idle
    readonly property var theming: AppTheming

    Bar {}
    Palette {}
    Dashboard {}
    Osd {}
    QuickSettings {}
    SettingsWindow {}
    Notify {}
    LockScreen {}
    Greeter {}
}
