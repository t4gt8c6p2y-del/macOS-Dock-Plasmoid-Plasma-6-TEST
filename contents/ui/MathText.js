.pragma library

// Mise en forme des formules des réponses de l'IA. Les modèles écrivent
// volontiers du LaTeX (\frac{a}{b}, x^{2}, \sqrt{x}, $...$) que le texte de
// Siri IA n'affiche pas : on le convertit en vrais symboles (½, x², √x, ×, π,
// ∑ᵢ₌₁ⁿ…). Les blocs et morceaux de code (``` et `) ne sont jamais touchés.
//
// prettify(texte) -> texte (Markdown) prêt à afficher.

var SUPERSCRIPTS = {
    "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷",
    "8": "⁸", "9": "⁹", "+": "⁺", "-": "⁻", "−": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
    "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ", "f": "ᶠ", "g": "ᵍ", "h": "ʰ",
    "i": "ⁱ", "j": "ʲ", "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ", "p": "ᵖ",
    "r": "ʳ", "s": "ˢ", "t": "ᵗ", "u": "ᵘ", "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ",
    "z": "ᶻ", "A": "ᴬ", "B": "ᴮ", "D": "ᴰ", "E": "ᴱ", "G": "ᴳ", "H": "ᴴ", "I": "ᴵ",
    "J": "ᴶ", "K": "ᴷ", "L": "ᴸ", "M": "ᴹ", "N": "ᴺ", "O": "ᴼ", "P": "ᴾ", "R": "ᴿ",
    "T": "ᵀ", "U": "ᵁ", "V": "ⱽ", "W": "ᵂ", "θ": "ᶿ", "β": "ᵝ", "γ": "ᵞ", "δ": "ᵟ",
    "φ": "ᵠ", "χ": "ᵡ", "∘": "°", "°": "°"
};

var SUBSCRIPTS = {
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇",
    "8": "₈", "9": "₉", "+": "₊", "-": "₋", "−": "₋", "=": "₌", "(": "₍", ")": "₎",
    "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ",
    "n": "ₙ", "o": "ₒ", "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ",
    "x": "ₓ", "β": "ᵦ", "γ": "ᵧ", "ρ": "ᵨ", "φ": "ᵩ", "χ": "ᵪ"
};

var SYMBOLS = {
    "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε",
    "varepsilon": "ε", "zeta": "ζ", "eta": "η", "theta": "θ", "vartheta": "ϑ",
    "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ",
    "pi": "π", "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ", "sigma": "σ", "varsigma": "ς",
    "tau": "τ", "upsilon": "υ", "phi": "φ", "varphi": "φ", "chi": "χ", "psi": "ψ",
    "omega": "ω", "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ",
    "Pi": "Π", "Sigma": "Σ", "Upsilon": "Υ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
    "times": "×", "cdot": "·", "cdots": "⋯", "ldots": "…", "dots": "…", "vdots": "⋮",
    "ddots": "⋱", "div": "÷", "pm": "±", "mp": "∓", "ast": "∗", "star": "⋆",
    "circ": "∘", "bullet": "•", "oplus": "⊕", "otimes": "⊗", "degree": "°",
    "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠",
    "approx": "≈", "sim": "∼", "simeq": "≃", "cong": "≅", "equiv": "≡", "propto": "∝",
    "ll": "≪", "gg": "≫", "infty": "∞", "partial": "∂", "nabla": "∇", "forall": "∀",
    "exists": "∃", "nexists": "∄", "emptyset": "∅", "varnothing": "∅", "in": "∈",
    "notin": "∉", "ni": "∋", "subset": "⊂", "supset": "⊃", "subseteq": "⊆",
    "supseteq": "⊇", "cup": "∪", "cap": "∩", "setminus": "∖", "land": "∧", "wedge": "∧",
    "lor": "∨", "vee": "∨", "lnot": "¬", "neg": "¬", "to": "→", "rightarrow": "→",
    "leftarrow": "←", "gets": "←", "leftrightarrow": "↔", "Rightarrow": "⇒",
    "Leftarrow": "⇐", "Leftrightarrow": "⇔", "implies": "⇒", "iff": "⇔",
    "mapsto": "↦", "uparrow": "↑", "downarrow": "↓", "longrightarrow": "⟶",
    "longleftarrow": "⟵", "sum": "∑", "prod": "∏", "coprod": "∐", "int": "∫",
    "iint": "∬", "iiint": "∭", "oint": "∮", "sqcup": "⊔", "perp": "⊥",
    "parallel": "∥", "angle": "∠", "triangle": "△", "hbar": "ℏ", "ell": "ℓ",
    "Re": "ℜ", "Im": "ℑ", "aleph": "ℵ", "prime": "′", "langle": "⟨", "rangle": "⟩",
    "lfloor": "⌊", "rfloor": "⌋", "lceil": "⌈", "rceil": "⌉", "lbrace": "{",
    "rbrace": "}", "vert": "|", "lvert": "|", "rvert": "|", "Vert": "‖", "mid": "|",
    "backslash": "\\", "therefore": "∴", "because": "∵", "square": "□", "checkmark": "✓",
    "quad": "  ", "qquad": "    ", "enspace": " ", "thinspace": " "
};

var OPERATORS = ["lim", "limsup", "liminf", "sin", "cos", "tan", "cot", "sec", "csc",
    "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "log", "ln", "lg", "exp",
    "max", "min", "sup", "inf", "det", "gcd", "arg", "deg", "dim", "ker", "mod",
    "Pr", "tr", "rank"];

var ACCENTS = {
    "vec": "⃗", "hat": "̂", "widehat": "̂", "bar": "̄",
    "overline": "̄", "tilde": "̃", "widetilde": "̃", "dot": "̇",
    "ddot": "̈", "check": "̌", "acute": "́", "grave": "̀"
};

// Commandes qui ne font que contenir du texte : on garde le contenu.
var TEXT_COMMANDS = ["text", "textrm", "textbf", "textit", "textsf", "texttt", "mathrm",
    "mathbf", "mathit", "mathsf", "mathtt", "mathcal", "mathscr", "mathfrak",
    "operatorname", "boldsymbol", "bm", "mbox", "hbox", "emph", "underline"];

// Commandes sans effet à l'affichage.
var IGNORED = ["left", "right", "big", "Big", "bigg", "Bigg", "bigl", "bigr", "Bigl",
    "Bigr", "displaystyle", "textstyle", "scriptstyle", "limits", "nolimits", "nonumber",
    "notag", "label", "hline", "centering"];

var DOUBLE_STRUCK = { "R": "ℝ", "N": "ℕ", "Z": "ℤ", "Q": "ℚ", "C": "ℂ", "P": "ℙ", "H": "ℍ" };

var VULGAR = {
    "1/2": "½", "1/3": "⅓", "2/3": "⅔", "1/4": "¼", "3/4": "¾", "1/5": "⅕", "2/5": "⅖",
    "3/5": "⅗", "4/5": "⅘", "1/6": "⅙", "5/6": "⅚", "1/7": "⅐", "1/8": "⅛",
    "3/8": "⅜", "5/8": "⅝", "7/8": "⅞", "1/9": "⅑", "1/10": "⅒"
};

// Contenu du groupe {…} qui commence en s[start] : { content, end } ou null.
function readGroup(s, start) {
    var depth = 0;
    for (var j = start; j < s.length; ++j) {
        var c = s[j];
        if (c === "\\") {
            ++j;
        } else if (c === "{") {
            ++depth;
        } else if (c === "}") {
            if (--depth === 0) {
                return { "content": s.substring(start + 1, j), "end": j + 1 };
            }
        }
    }
    return null;
}

function skipSpaces(s, i) {
    while (i < s.length && (s[i] === " " || s[i] === "\n" || s[i] === "\t")) {
        ++i;
    }
    return i;
}

// Argument d'une commande : un groupe {…} ou un seul caractère (\frac12).
function readArgument(s, i, inMath) {
    i = skipSpaces(s, i);
    if (i >= s.length) {
        return null;
    }
    if (s[i] === "{") {
        var group = readGroup(s, i);
        return group ? { "text": convert(group.content, inMath), "end": group.end } : null;
    }
    if (s[i] === "\\") {
        var match = /^\\[a-zA-Z]+/.exec(s.substring(i));
        if (match) {
            return { "text": convert(match[0], inMath), "end": i + match[0].length };
        }
        return { "text": s.substr(i, 2), "end": i + 2 };
    }
    return { "text": s[i], "end": i + 1 };
}

function isWrapped(t) {
    if (t.length < 2 || t[0] !== "(" || t[t.length - 1] !== ")") {
        return false;
    }
    var depth = 0;
    for (var i = 0; i < t.length; ++i) {
        if (t[i] === "(") {
            ++depth;
        } else if (t[i] === ")") {
            --depth;
            if (depth === 0 && i < t.length - 1) {
                return false;
            }
        }
    }
    return true;
}

// Entoure de parenthèses ce qui n'est pas un seul bloc (a+b → (a+b)).
function wrap(t) {
    t = String(t).trim();
    if (isWrapped(t) || /^[−-]?[^\s+\-−±∓×·\/=<>,;:]+$/.test(t)) {
        return t;
    }
    return "(" + t + ")";
}

function fraction(a, b) {
    a = String(a).trim();
    b = String(b).trim();
    var key = a + "/" + b;
    if (VULGAR[key] !== undefined) {
        return VULGAR[key];
    }
    return wrap(a) + "/" + wrap(b);
}

function script(arg, up) {
    arg = String(arg).trim();
    var table = up ? SUPERSCRIPTS : SUBSCRIPTS;
    var out = "";
    for (var i = 0; i < arg.length; ++i) {
        var mapped = table[arg[i]];
        if (mapped === undefined) {
            out = "";
            break;
        }
        out += mapped;
    }
    if (out.length > 0) {
        return out;
    }
    if (arg.length === 0) {
        return "";
    }
    var inner = arg.length === 1 ? arg : "(" + arg + ")";
    return up ? "^" + inner : "\\_" + inner;
}

function applyAccent(text, accent) {
    var chars = Array.from(String(text));
    return chars.length === 1 ? chars[0] + accent : String(text);
}

// Convertit un morceau de LaTeX. inMath : on est entre $…$, \(…\) ou $$…$$
// (^x et _x sans accolades sont alors des exposants / indices) ; sinon on ne
// transforme que les commandes connues, pour ne pas abîmer du texte normal.
function convert(s, inMath) {
    var out = "";
    var i = 0;
    while (i < s.length) {
        var c = s[i];

        if (c === "\\") {
            var rest = s.substring(i + 1);
            var named = /^[a-zA-Z]+/.exec(rest);
            if (!named) {
                var next = s[i + 1];
                if (next === undefined) {
                    out += "\\";
                    i += 1;
                } else if (next === "\\") {
                    out += inMath ? "  \n" : "\\\\";
                    i += 2;
                } else if (inMath && ",;:!> ".indexOf(next) >= 0) {
                    out += next === "!" ? "" : (next === " " ? " " : " ");
                    i += 2;
                } else if (inMath && "{}%$&#_".indexOf(next) >= 0) {
                    out += next === "_" ? "\\_" : next;
                    i += 2;
                } else {
                    out += "\\" + next;
                    i += 2;
                }
                continue;
            }

            var name = named[0];
            var after = i + 1 + name.length;
            var arg;

            if (name === "frac" || name === "dfrac" || name === "tfrac" || name === "cfrac") {
                var numerator = readArgument(s, after, inMath);
                var denominator = numerator ? readArgument(s, numerator.end, inMath) : null;
                if (numerator && denominator) {
                    out += fraction(numerator.text, denominator.text);
                    i = denominator.end;
                    continue;
                }
            } else if (name === "binom") {
                var top = readArgument(s, after, inMath);
                var bottom = top ? readArgument(s, top.end, inMath) : null;
                if (top && bottom) {
                    out += "C(" + top.text + ", " + bottom.text + ")";
                    i = bottom.end;
                    continue;
                }
            } else if (name === "sqrt") {
                var index = "";
                var position = skipSpaces(s, after);
                if (s[position] === "[") {
                    var close = s.indexOf("]", position);
                    if (close > position) {
                        index = script(convert(s.substring(position + 1, close), inMath), true);
                        after = close + 1;
                    }
                }
                arg = readArgument(s, after, inMath);
                if (arg) {
                    out += index + "√" + wrap(arg.text);
                    i = arg.end;
                    continue;
                }
            } else if (name === "mathbb") {
                arg = readArgument(s, after, inMath);
                if (arg) {
                    out += DOUBLE_STRUCK[arg.text] !== undefined ? DOUBLE_STRUCK[arg.text] : arg.text;
                    i = arg.end;
                    continue;
                }
            } else if (TEXT_COMMANDS.indexOf(name) >= 0) {
                arg = readArgument(s, after, inMath);
                if (arg) {
                    out += arg.text;
                    i = arg.end;
                    continue;
                }
            } else if (ACCENTS[name] !== undefined) {
                arg = readArgument(s, after, inMath);
                if (arg) {
                    out += applyAccent(arg.text, ACCENTS[name]);
                    i = arg.end;
                    continue;
                }
            } else if (name === "begin" || name === "end") {
                arg = readArgument(s, after, inMath);
                if (arg) {
                    // \begin{pmatrix}, \begin{aligned}… : seules les lignes comptent.
                    i = arg.end;
                    if (name === "begin" && s[i] === "{") {
                        var options = readGroup(s, i);
                        if (options && name === "begin" && /^(array|tabular)$/.test(arg.text)) {
                            i = options.end;
                        }
                    }
                    if (name === "end") {
                        out += "\n";
                    }
                    continue;
                }
            } else if (IGNORED.indexOf(name) >= 0) {
                i = after;
                if (name === "left" || name === "right") {
                    if (s[i] === ".") {
                        ++i;
                    }
                } else if (name === "label") {
                    var labelGroup = skipSpaces(s, i) < s.length && s[skipSpaces(s, i)] === "{"
                        ? readGroup(s, skipSpaces(s, i)) : null;
                    if (labelGroup) {
                        i = labelGroup.end;
                    }
                }
                continue;
            } else if (SYMBOLS[name] !== undefined) {
                out += SYMBOLS[name];
                i = after;
                continue;
            } else if (OPERATORS.indexOf(name) >= 0) {
                out += name;
                i = after;
                continue;
            }

            // Commande inconnue : laissée telle quelle.
            out += "\\" + name;
            i = after;
            continue;
        }

        if ((c === "^" || c === "_") && (inMath || s[i + 1] === "{")) {
            var scriptArgument = readArgument(s, i + 1, inMath);
            if (scriptArgument) {
                out += script(scriptArgument.text, c === "^");
                i = scriptArgument.end;
                continue;
            }
        }

        if (inMath) {
            if (c === "{" || c === "}" || c === "~") {
                out += c === "~" ? " " : "";
            } else if (c === "&") {
                out += " ";
            } else if (c === "*") {
                out += "\\*";
            } else if (c === "-") {
                out += "−";
            } else {
                out += c;
            }
        } else {
            out += c;
        }
        ++i;
    }
    return out;
}

// $…$ : un « $ » ouvrant suivi d'un caractère non blanc, un « $ » fermant
// précédé d'un non blanc et non suivi d'un chiffre (« 5 $ et 6 $ » reste du texte).
function convertInlineDollars(t) {
    var out = "";
    var i = 0;
    while (i < t.length) {
        var c = t[i];
        if (c === "\\") {
            out += c + (i + 1 < t.length ? t[i + 1] : "");
            i += 2;
            continue;
        }
        if (c === "$") {
            var j = i + 1;
            var found = -1;
            while (j < t.length && t[j] !== "\n") {
                if (t[j] === "\\") {
                    j += 2;
                    continue;
                }
                if (t[j] === "$") {
                    found = j;
                    break;
                }
                ++j;
            }
            if (found > i + 1) {
                var inner = t.substring(i + 1, found);
                var following = found + 1 < t.length ? t[found + 1] : "";
                if (!/^\s/.test(inner) && !/\s$/.test(inner) && !/\d/.test(following)) {
                    out += convert(inner, true);
                    i = found + 1;
                    continue;
                }
            }
        }
        out += c;
        ++i;
    }
    return out;
}

function prettifyText(t) {
    // Formules « d'affichage » : sur leur propre ligne.
    t = t.replace(/\$\$([\s\S]+?)\$\$/g, function (all, inner) {
        return "\n\n" + convert(inner.trim(), true) + "\n\n";
    });
    t = t.replace(/\\\[([\s\S]+?)\\\]/g, function (all, inner) {
        return "\n\n" + convert(inner.trim(), true) + "\n\n";
    });
    t = t.replace(/\\\(([\s\S]+?)\\\)/g, function (all, inner) {
        return convert(inner.trim(), true);
    });
    t = convertInlineDollars(t);
    // Commandes restantes hors des délimiteurs ($ oublié) : \frac{1}{2}, x^{2}…
    return convert(t, false);
}

function prettify(text) {
    var s = String(text);
    if (s.indexOf("\\") < 0 && s.indexOf("$") < 0 && s.indexOf("^{") < 0 && s.indexOf("_{") < 0) {
        return s;
    }
    // Les blocs et morceaux de code restent intacts (indices impairs).
    var parts = s.split(/(```[\s\S]*?```|`[^`\n]*`)/);
    for (var i = 0; i < parts.length; i += 2) {
        parts[i] = prettifyText(parts[i]);
    }
    return parts.join("");
}
