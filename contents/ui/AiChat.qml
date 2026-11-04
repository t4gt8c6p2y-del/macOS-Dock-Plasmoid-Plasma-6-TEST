import QtQuick

// Assistant IA du Spotlight et de l'application « Siri IA » : historique des
// conversations (enregistré hors du dépôt, dans ~/.local/share/macosdock/) et
// envoi des questions au fournisseur choisi :
//   0 = Gemini (API Google AI Studio, clé gratuite),
//   1 = GLM (modèle gratuit d'OpenCode par le CLI « opencode », ou API),
//   2 = un fournisseur personnalisé compatible OpenAI (OpenRouter, Groq,
//       Mistral, Ollama local...).
// Les clés viennent des réglages du Dock (onglet « Identifiants ») ; elles ne
// sont jamais écrites dans l'historique ni dans le dépôt.
Item {
    id: chat

    visible: false
    width: 0
    height: 0

    // Services natifs (SpotlightBackend).
    property var backend: null

    // --- Réglages (liés aux réglages du Dock) -------------------------------
    property int defaultProvider: 0
    property string geminiKey: ""
    property string geminiModel: "gemini-3.8-flash"
    // 0 = CLI OpenCode (modèles gratuits), 1 = API HTTP avec clé.
    property int glmBackend: 0
    property string glmModel: "glm-5.3-flash-free"
    property string glmKey: ""
    property string glmBaseUrl: "https://opencode.ai/inference/openai/v1"
    property string customName: ""
    property string customUrl: ""
    property string customKey: ""
    property string customModel: ""
    property string systemPrompt:
        "You are the assistant built into a desktop search bar, similar to Siri in macOS. "
        + "Answer concisely and accurately, in the same language as the user's last message. "
        + "Use Markdown only when it helps (lists, code)."

    // Fournisseur utilisé pour la prochaine question (choisi dans l'interface).
    property int activeProvider: defaultProvider
    onDefaultProviderChanged: activeProvider = defaultProvider
    signal providerChosen(int index)
    signal answered(string conversationId)

    // --- État ------------------------------------------------------------------
    property var conversations: []
    property string currentId: ""
    property bool busy: false
    property string busyConversationId: ""

    readonly property var current: conversationById(currentId)
    readonly property var currentMessages: {
        var conversation = conversationById(currentId);
        return conversation ? conversation.messages.slice() : [];
    }
    readonly property bool currentBusy: busy && busyConversationId === currentId
        && currentId.length > 0

    property int requestToken: 0
    property int processId: -1
    property var activeRequest: null

    readonly property int providerCount: 3

    function providerName(index) {
        if (index === 0) {
            return "Gemini";
        }
        if (index === 1) {
            return "GLM";
        }
        return String(customName).trim().length > 0 ? String(customName).trim() : i18n("Custom AI");
    }

    function setActiveProvider(index) {
        activeProvider = index;
        providerChosen(index);
    }

    // Texte d'erreur si le fournisseur n'est pas utilisable, sinon "".
    function providerProblem(index) {
        if (index === 0) {
            if (String(geminiKey).trim().length === 0) {
                return i18n("No Gemini API key. Add it in the Dock settings, tab “Credentials”.");
            }
            return "";
        }
        if (index === 1) {
            if (glmBackend === 0) {
                if (!backend || backend.findExecutable("opencode").length === 0) {
                    return i18n("The OpenCode command-line tool was not found. Install it from opencode.ai, or switch GLM to “API key” mode in the Dock settings, tab “Credentials”.");
                }
                return "";
            }
            if (String(glmKey).trim().length === 0) {
                return i18n("No OpenCode API key. Add it in the Dock settings, tab “Credentials”.");
            }
            return "";
        }
        if (String(customUrl).trim().length === 0 || String(customModel).trim().length === 0) {
            return i18n("The custom AI is not configured. Fill in its address and model in the Dock settings, tab “Credentials”.");
        }
        return "";
    }

    function providerReady(index) {
        return providerProblem(index).length === 0;
    }

    // --- Conversations ---------------------------------------------------------
    function newId() {
        return Date.now().toString(36) + Math.floor(Math.random() * 46656).toString(36);
    }

    function shorten(text) {
        var line = String(text).split("\n")[0].trim();
        return line.length > 60 ? line.substring(0, 57) + "…" : line;
    }

    function conversationById(id) {
        if (!id) {
            return null;
        }
        for (var i = 0; i < conversations.length; ++i) {
            if (conversations[i].id === id) {
                return conversations[i];
            }
        }
        return null;
    }

    function startNew() {
        currentId = "";
    }

    function select(id) {
        currentId = id;
    }

    // Conversations triées (épinglées d'abord, puis récentes), filtrées par texte.
    function sortedConversations(filter) {
        var needle = String(filter || "").trim().toLowerCase();
        var list = conversations.filter(function (conversation) {
            if (needle.length === 0) {
                return true;
            }
            if (String(conversation.title).toLowerCase().indexOf(needle) >= 0) {
                return true;
            }
            for (var i = 0; i < conversation.messages.length; ++i) {
                if (String(conversation.messages[i].text).toLowerCase().indexOf(needle) >= 0) {
                    return true;
                }
            }
            return false;
        });
        list.sort(function (a, b) {
            if (Boolean(a.pinned) !== Boolean(b.pinned)) {
                return a.pinned ? -1 : 1;
            }
            return b.updated - a.updated;
        });
        return list;
    }

    function deleteConversation(id) {
        if (busy && busyConversationId === id) {
            cancel();
        }
        conversations = conversations.filter(function (conversation) {
            return conversation.id !== id;
        });
        if (currentId === id) {
            currentId = "";
        }
        scheduleSave();
    }

    function togglePin(id) {
        var conversation = conversationById(id);
        if (conversation) {
            conversation.pinned = !conversation.pinned;
            touch();
        }
    }

    function renameConversation(id, title) {
        var conversation = conversationById(id);
        var name = String(title).trim();
        if (conversation && name.length > 0) {
            conversation.title = name;
            touch();
        }
    }

    function clearAll() {
        cancel();
        conversations = [];
        currentId = "";
        scheduleSave();
    }

    function touch() {
        conversations = conversations.slice();
        scheduleSave();
    }

    // --- Enregistrement ----------------------------------------------------------
    function load() {
        if (!backend) {
            return;
        }
        var raw = backend.loadText("siri-history.json");
        if (!raw) {
            return;
        }
        try {
            var data = JSON.parse(raw);
            if (data && Array.isArray(data.conversations)) {
                conversations = data.conversations.filter(function (conversation) {
                    return conversation && conversation.id && Array.isArray(conversation.messages);
                });
            }
        } catch (error) {
            console.warn("macOS Dock: unreadable Siri AI history:", error);
        }
    }

    function scheduleSave() {
        saveTimer.restart();
    }

    function saveNow() {
        if (!backend) {
            return;
        }
        var list = conversations.slice(0, 300);
        backend.saveText("siri-history.json",
            JSON.stringify({ "version": 1, "conversations": list }));
    }

    onBackendChanged: load()

    Timer {
        id: saveTimer

        interval: 500
        repeat: false
        onTriggered: chat.saveNow()
    }

    Component.onDestruction: saveNow()

    // --- Questions ----------------------------------------------------------------
    function ask(text, provider) {
        var question = String(text).trim();
        if (question.length === 0 || busy) {
            return false;
        }
        var providerIndex = provider === undefined ? activeProvider : provider;
        var conversation = conversationById(currentId);
        if (!conversation) {
            conversation = {
                "id": newId(),
                "title": shorten(question),
                "created": Date.now(),
                "updated": Date.now(),
                "pinned": false,
                "messages": []
            };
            conversations = [conversation].concat(conversations);
            currentId = conversation.id;
        }
        conversation.messages.push({
            "role": "user",
            "text": question,
            "time": Date.now(),
            "provider": providerIndex
        });
        conversation.updated = Date.now();
        touch();

        busy = true;
        busyConversationId = conversation.id;

        var problem = providerProblem(providerIndex);
        if (problem.length > 0) {
            finishAnswer(conversation.id, providerIndex, false, problem);
            return true;
        }
        send(requestMessages(conversation), providerIndex, function (ok, answer) {
            chat.finishAnswer(conversation.id, providerIndex, ok, answer);
        });
        return true;
    }

    function cancel() {
        ++requestToken;
        if (activeRequest) {
            try {
                activeRequest.abort();
            } catch (error) {
                // La requête est déjà terminée.
            }
            activeRequest = null;
        }
        if (processId >= 0 && backend) {
            backend.abortProcess(processId);
        }
        processId = -1;
        httpTimeout.stop();
        busy = false;
        busyConversationId = "";
    }

    function finishAnswer(conversationId, providerIndex, ok, answer) {
        busy = false;
        busyConversationId = "";
        var conversation = conversationById(conversationId);
        if (!conversation) {
            return;
        }
        conversation.messages.push({
            "role": "assistant",
            "text": String(answer),
            "time": Date.now(),
            "provider": providerIndex,
            "error": !ok
        });
        conversation.updated = Date.now();
        touch();
        answered(conversationId);
    }

    // Messages envoyés au modèle : les 30 derniers, sans les erreurs, et sans
    // deux messages consécutifs du même rôle (certaines API les refusent).
    function requestMessages(conversation) {
        var result = [];
        var source = conversation.messages.filter(function (message) {
            return !message.error;
        }).slice(-30);
        for (var i = 0; i < source.length; ++i) {
            var message = source[i];
            if (result.length > 0 && result[result.length - 1].role === message.role) {
                result[result.length - 1].text += "\n\n" + message.text;
            } else {
                result.push({ "role": message.role, "text": message.text });
            }
        }
        while (result.length > 0 && result[0].role !== "user") {
            result.shift();
        }
        return result;
    }

    function send(messages, provider, done) {
        var token = ++requestToken;
        var finish = function (ok, text) {
            if (token !== chat.requestToken) {
                return;
            }
            chat.activeRequest = null;
            chat.processId = -1;
            httpTimeout.stop();
            done(ok, text);
        };
        if (provider === 0) {
            sendGemini(messages, finish);
        } else if (provider === 1 && glmBackend === 0) {
            sendOpenCode(messages, finish);
        } else if (provider === 1) {
            sendOpenAi(glmBaseUrl, glmKey, glmModel, "GLM", messages, finish);
        } else {
            sendOpenAi(customUrl, customKey, customModel, providerName(2), messages, finish);
        }
    }

    function errorMessage(name, status, body) {
        var detail = "";
        try {
            var parsed = JSON.parse(body);
            if (parsed && parsed.error) {
                detail = String(parsed.error.message || parsed.error);
            }
        } catch (error) {
            detail = String(body).substring(0, 200);
        }
        if (status === 0) {
            return i18n("Network error: %1 could not be reached.", name);
        }
        var base;
        if (status === 400 || status === 401 || status === 403) {
            base = i18n("%1 refused the request (HTTP %2). Check the API key and the model name.", name, status);
        } else if (status === 404) {
            base = i18n("%1 did not find this model or address (HTTP 404). Check the model name.", name);
        } else if (status === 429) {
            base = i18n("%1 quota reached (HTTP 429). Wait a moment or pick another model.", name);
        } else {
            base = i18n("%1 returned an error (HTTP %2).", name, status);
        }
        return detail.length > 0 ? base + "\n\n" + detail : base;
    }

    function postJson(url, headers, body, name, callback) {
        var request = new XMLHttpRequest();
        activeRequest = request;
        request.open("POST", url);
        request.setRequestHeader("Content-Type", "application/json");
        for (var key in headers) {
            request.setRequestHeader(key, headers[key]);
        }
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (request.status >= 200 && request.status < 300) {
                var parsed = null;
                try {
                    parsed = JSON.parse(request.responseText);
                } catch (error) {
                    callback(false, i18n("%1 returned an unreadable answer.", name));
                    return;
                }
                callback(true, parsed);
            } else {
                callback(false, chat.errorMessage(name, request.status, request.responseText));
            }
        };
        httpTimeout.restart();
        request.send(JSON.stringify(body));
    }

    function sendGemini(messages, finish) {
        var model = String(geminiModel).trim().length > 0 ? String(geminiModel).trim()
            : "gemini-3.8-flash";
        var url = "https://generativelanguage.googleapis.com/v1beta/models/"
            + encodeURIComponent(model) + ":generateContent";
        var contents = messages.map(function (message) {
            return {
                "role": message.role === "user" ? "user" : "model",
                "parts": [{ "text": message.text }]
            };
        });
        postJson(url, { "x-goog-api-key": String(geminiKey).trim() }, {
            "systemInstruction": { "parts": [{ "text": systemPrompt }] },
            "contents": contents
        }, "Gemini", function (ok, payload) {
            if (!ok) {
                finish(false, payload);
                return;
            }
            var text = "";
            var candidate = payload.candidates && payload.candidates.length > 0
                ? payload.candidates[0] : null;
            if (candidate && candidate.content && candidate.content.parts) {
                for (var i = 0; i < candidate.content.parts.length; ++i) {
                    if (candidate.content.parts[i].text) {
                        text += candidate.content.parts[i].text;
                    }
                }
            }
            if (text.trim().length === 0) {
                var reason = payload.promptFeedback && payload.promptFeedback.blockReason
                    ? payload.promptFeedback.blockReason : "";
                finish(false, reason.length > 0
                    ? i18n("Gemini blocked this request (%1).", reason)
                    : i18n("Gemini returned an empty answer."));
                return;
            }
            finish(true, text.trim());
        });
    }

    function sendOpenAi(baseUrl, key, model, name, messages, finish) {
        var url = String(baseUrl).trim().replace(/\/+$/, "");
        if (!/\/chat\/completions$/.test(url)) {
            url += "/chat/completions";
        }
        var headers = {};
        if (String(key).trim().length > 0) {
            headers["Authorization"] = "Bearer " + String(key).trim();
        }
        var list = [{ "role": "system", "content": systemPrompt }];
        for (var i = 0; i < messages.length; ++i) {
            list.push({ "role": messages[i].role, "content": messages[i].text });
        }
        postJson(url, headers, {
            "model": String(model).trim(),
            "messages": list,
            "stream": false
        }, name, function (ok, payload) {
            if (!ok) {
                finish(false, payload);
                return;
            }
            var content = "";
            if (payload.choices && payload.choices.length > 0 && payload.choices[0].message) {
                content = payload.choices[0].message.content;
            }
            if (Array.isArray(content)) {
                content = content.map(function (part) {
                    return part.text || "";
                }).join("");
            }
            content = String(content || "").trim();
            if (content.length === 0) {
                finish(false, i18n("%1 returned an empty answer.", name));
                return;
            }
            finish(true, content);
        });
    }

    // GLM gratuit : OpenCode ne laisse ses modèles « free » à d'autres clients
    // que lui-même ; on passe donc par son CLI, en agent « plan » (lecture
    // seule) dans un dossier vide propre au Dock.
    function sendOpenCode(messages, finish) {
        var executable = backend ? backend.findExecutable("opencode") : "";
        if (executable.length === 0) {
            finish(false, providerProblem(1));
            return;
        }
        var model = String(glmModel).trim().length > 0 ? String(glmModel).trim()
            : "glm-5.3-flash-free";
        if (model.indexOf("/") < 0) {
            model = "opencode/" + model;
        }
        var prompt = systemPrompt + "\n\n";
        if (messages.length === 1) {
            prompt += messages[0].text;
        } else {
            for (var i = 0; i < messages.length; ++i) {
                prompt += (messages[i].role === "user" ? "User: " : "Assistant: ")
                    + messages[i].text + "\n\n";
            }
            prompt += "Assistant:";
        }
        pendingCli = finish;
        processId = backend.runProcess(executable,
            ["run", "--agent", "plan", "--model", model, prompt], 120000);
    }

    property var pendingCli: null

    function cleanCliOutput(text) {
        var cleaned = String(text).replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "").replace(/\r/g, "");
        var lines = cleaned.split("\n");
        while (lines.length > 0 && (lines[0].trim().length === 0
                || /^\s*[>▌]\s*(plan|build)\b/i.test(lines[0]))) {
            lines.shift();
        }
        return lines.join("\n").trim();
    }

    Connections {
        target: chat.backend

        function onProcessFinished(id, exitCode, standardOutput, standardError, timedOut) {
            if (id !== chat.processId || !chat.pendingCli) {
                return;
            }
            var finish = chat.pendingCli;
            chat.pendingCli = null;
            if (timedOut) {
                finish(false, i18n("OpenCode took too long to answer."));
                return;
            }
            var output = chat.cleanCliOutput(standardOutput);
            if (exitCode !== 0 && output.length === 0) {
                var detail = chat.cleanCliOutput(standardError);
                finish(false, i18n("OpenCode could not answer (exit code %1).", exitCode)
                    + (detail.length > 0 ? "\n\n" + detail.slice(-500) : ""));
                return;
            }
            if (output.length === 0) {
                finish(false, i18n("OpenCode returned an empty answer."));
                return;
            }
            finish(true, output);
        }
    }

    Timer {
        id: httpTimeout

        interval: 90000
        repeat: false
        onTriggered: {
            if (!chat.busy) {
                return;
            }
            var conversationId = chat.busyConversationId;
            var provider = chat.activeProvider;
            // cancel() interrompt la requête sans rappeler son gestionnaire.
            chat.cancel();
            chat.finishAnswer(conversationId, provider, false,
                i18n("The assistant took too long to answer."));
        }
    }
}
