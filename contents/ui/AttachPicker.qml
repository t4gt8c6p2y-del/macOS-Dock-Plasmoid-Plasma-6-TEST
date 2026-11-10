import QtQuick
import QtQuick.Dialogs

// Boîtes de dialogue « joindre un dossier / des fichiers » de Siri IA. Elles
// sont dans un fichier à part, chargé à la demande : si le module
// QtQuick.Dialogs manque, seule cette fonction est touchée (Siri IA se sert
// alors de kdialog), pas toute la fenêtre.
Item {
    id: picker

    // location : adresse file:// ; isDir : vrai pour un dossier.
    signal picked(string location, bool isDir)

    function openFolder() {
        folderDialog.open();
    }

    function openFiles() {
        fileDialog.open();
    }

    FolderDialog {
        id: folderDialog

        title: i18n("Choose a folder for the AI")
        onAccepted: picker.picked(String(selectedFolder), true)
    }

    FileDialog {
        id: fileDialog

        title: i18n("Choose files for the AI")
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            for (var i = 0; i < selectedFiles.length; ++i) {
                picker.picked(String(selectedFiles[i]), false);
            }
        }
    }
}
