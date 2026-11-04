#!/usr/bin/env bash
#
# Intégration du Spotlight du Dock au bureau Plasma / Fedora KDE.
#
#   spotlight-integration.sh enable   La touche Windows (Super) ouvre le Spotlight
#                                     du Dock au lieu du lanceur de Plasma, et
#                                     KRunner (barre Alt+Espace / Alt+F2 / frappe
#                                     sur le bureau) est neutralisé : c'est le
#                                     Spotlight du Dock qui répond à sa place.
#   spotlight-integration.sh disable  Remet les réglages d'origine.
#   spotlight-integration.sh status   Affiche l'état actuel.
#
# Rien n'est écrit en dehors de votre dossier personnel et tout est réversible.
# Les anciennes valeurs sont conservées dans
# ~/.local/share/macosdock/launcher-backup.conf.

set -u

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/macosdock"
BACKUP="$DATA_DIR/launcher-backup.conf"
OWN_SHORTCUT="org.macosdock.Spotlight,/Spotlight,org.macosdock.Spotlight,toggle"
KRUNNER_UNIT="plasma-krunner.service"

action="${1:-status}"

have() {
    command -v "$1" >/dev/null 2>&1
}

if have kwriteconfig6 && have kreadconfig6; then
    KWRITE=kwriteconfig6
    KREAD=kreadconfig6
else
    printf 'spotlight-integration: kwriteconfig6 est introuvable, rien n’a été modifié.\n' >&2
    exit 1
fi

reconfigure_kwin() {
    if have qdbus6; then
        qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 && return 0
    fi
    if have dbus-send; then
        dbus-send --session --type=method_call --dest=org.kde.KWin /KWin \
            org.kde.KWin.reconfigure >/dev/null 2>&1 && return 0
    fi
    return 1
}

current_meta() {
    "$KREAD" --file kwinrc --group ModifierOnlyShortcuts --key Meta 2>/dev/null
}

backup_value() {
    # backup_value clé : valeur stockée, vide si absente.
    "$KREAD" --file "$BACKUP" --group backup --key "$1" 2>/dev/null
}

case "$action" in
    enable)
        mkdir -p "$DATA_DIR"
        meta="$(current_meta)"
        if [ "$meta" != "$OWN_SHORTCUT" ]; then
            # Première activation : on mémorise la valeur d'origine.
            if [ -z "$("$KREAD" --file "$BACKUP" --group backup --key saved 2>/dev/null)" ]; then
                if [ -n "$meta" ]; then
                    "$KWRITE" --file "$BACKUP" --group backup --key meta "$meta"
                    "$KWRITE" --file "$BACKUP" --group backup --key metaWasSet true
                else
                    "$KWRITE" --file "$BACKUP" --group backup --key metaWasSet false
                fi
                typing="$("$KREAD" --file krunnerrc --group General --key ActivateWhenTypingOnDesktop 2>/dev/null)"
                "$KWRITE" --file "$BACKUP" --group backup --key typing "$typing"
                "$KWRITE" --file "$BACKUP" --group backup --key saved true
            fi
            "$KWRITE" --file kwinrc --group ModifierOnlyShortcuts --key Meta "$OWN_SHORTCUT"
            reconfigure_kwin || printf 'spotlight-integration: déconnectez-vous puis reconnectez-vous pour activer la touche Windows.\n' >&2
        fi

        # Frappe sur le bureau : Plasma appelle KRunner par D-Bus, le Spotlight
        # du Dock répond à ce nom.
        "$KWRITE" --file krunnerrc --group General --key ActivateWhenTypingOnDesktop true

        # KRunner ne doit pas redémarrer et reprendre le nom D-Bus.
        if have systemctl; then
            systemctl --user stop "$KRUNNER_UNIT" >/dev/null 2>&1 || true
            systemctl --user mask "$KRUNNER_UNIT" >/dev/null 2>&1 || true
        fi
        printf 'Spotlight : intégration activée (touche Windows, KRunner neutralisé).\n'
        ;;

    disable)
        if [ "$(backup_value metaWasSet)" = "true" ]; then
            "$KWRITE" --file kwinrc --group ModifierOnlyShortcuts --key Meta "$(backup_value meta)"
        elif [ "$(current_meta)" = "$OWN_SHORTCUT" ]; then
            "$KWRITE" --file kwinrc --group ModifierOnlyShortcuts --key Meta --delete
        fi
        old_typing="$(backup_value typing)"
        if [ -n "$old_typing" ]; then
            "$KWRITE" --file krunnerrc --group General --key ActivateWhenTypingOnDesktop "$old_typing"
        fi
        reconfigure_kwin || true
        if have systemctl; then
            systemctl --user unmask "$KRUNNER_UNIT" >/dev/null 2>&1 || true
        fi
        rm -f -- "$BACKUP"
        printf 'Spotlight : réglages d’origine rétablis (touche Windows, KRunner).\n'
        ;;

    status)
        printf 'Meta (kwinrc)      : %s\n' "$(current_meta)"
        printf 'Frappe sur bureau  : %s\n' "$("$KREAD" --file krunnerrc --group General --key ActivateWhenTypingOnDesktop 2>/dev/null)"
        if have systemctl; then
            printf 'plasma-krunner     : %s\n' "$(systemctl --user is-enabled "$KRUNNER_UNIT" 2>/dev/null || echo inconnu)"
        fi
        ;;

    *)
        printf 'Usage : %s enable|disable|status\n' "$0" >&2
        exit 2
        ;;
esac
