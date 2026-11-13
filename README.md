# omarchy-lock

Omarchy's lock screen (`omarchy.lock`, 4.5.0) with a different face: date and clock on top, avatar and
name, a pill field with animated dots, a breathing glow that turns red and shakes on a wrong password.

`Service.qml` is the stock one except for `idleMs` (13000, stock 5000): how long the screen stays on
after a wake before it blanks again. Auth, PAM service, fingerprint and the `lock` IPC target are untouched.
`poster.sh` is not copied, the service runs the stock one from `$OMARCHY_PATH`.

The avatar comes from `~/.face`, `~/.face.icon` or AccountsService, whichever exists.

## Install

    ln -sfn "$PWD" ~/.config/omarchy/plugins/eduardo.lock
    omarchy-shell shell rescanPlugins
    omarchy plugin enable eduardo.lock

Enabling it turns `omarchy.lock` off (`omarchy.clonedFrom`), and it inherits the stock plugin's
authentication capability.

## Back to stock

    omarchy plugin disable eduardo.lock

Works from a TTY too (Ctrl+Alt+F3) if the lock screen itself is broken: the stock lock takes over a
session that is still locked.

## After an Omarchy update

This is a frozen copy. From this folder, see whether the stock plugin moved:

    (cd /usr/share/omarchy/shell/plugins/lock && sha256sum -c "$OLDPWD/upstream.sha256")

Based on Omarchy (MIT).
