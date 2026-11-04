.pragma library

// Calculatrice du Spotlight : évalue une expression arithmétique saisie dans
// la barre (« 12*(3+4) », « 2^10 », « sqrt(81) »). Aucun eval() : analyseur
// récursif descendant limité aux nombres, + - * / % ^, parenthèses, quelques
// constantes et fonctions.

var constants = { "pi": Math.PI, "e": Math.E };
var functions = {
    "sqrt": Math.sqrt, "abs": Math.abs, "sin": Math.sin, "cos": Math.cos,
    "tan": Math.tan, "ln": Math.log, "log": Math.log10, "exp": Math.exp,
    "round": Math.round, "floor": Math.floor, "ceil": Math.ceil
};

function tokenize(text) {
    var tokens = [];
    var i = 0;
    while (i < text.length) {
        var c = text.charAt(i);
        if (c === " " || c === "\t") {
            ++i;
        } else if ((c >= "0" && c <= "9") || c === ".") {
            var j = i;
            while (j < text.length && ((text.charAt(j) >= "0" && text.charAt(j) <= "9")
                    || text.charAt(j) === ".")) {
                ++j;
            }
            var value = Number(text.substring(i, j));
            if (!isFinite(value)) {
                return null;
            }
            tokens.push({ "type": "num", "value": value });
            i = j;
        } else if (c >= "a" && c <= "z") {
            var k = i;
            while (k < text.length && text.charAt(k) >= "a" && text.charAt(k) <= "z") {
                ++k;
            }
            tokens.push({ "type": "id", "value": text.substring(i, k) });
            i = k;
        } else if ("+-*/%^()".indexOf(c) >= 0) {
            tokens.push({ "type": "op", "value": c });
            ++i;
        } else {
            return null;
        }
    }
    return tokens;
}

function evaluate(input) {
    var text = String(input).trim().toLowerCase();
    if (text.length === 0 || text.length > 120) {
        return null;
    }
    text = text.replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-");
    // Virgule décimale (« 2,5 ») : seulement si elle est entre deux chiffres.
    text = text.replace(/(\d),(\d)/g, "$1.$2");
    if (!/^[0-9a-z\s+\-*\/^%().]+$/.test(text)) {
        return null;
    }
    var tokens = tokenize(text);
    if (tokens === null || tokens.length === 0) {
        return null;
    }

    var position = 0;
    var usedOperator = false;
    var failed = false;

    function peek() {
        return position < tokens.length ? tokens[position] : null;
    }
    function isOp(token, value) {
        return token !== null && token.type === "op" && token.value === value;
    }

    function parseExpression() {
        var left = parseTerm();
        while (!failed && (isOp(peek(), "+") || isOp(peek(), "-"))) {
            var op = tokens[position++].value;
            var right = parseTerm();
            usedOperator = true;
            left = op === "+" ? left + right : left - right;
        }
        return left;
    }

    function parseTerm() {
        var left = parseUnary();
        while (!failed && (isOp(peek(), "*") || isOp(peek(), "/") || isOp(peek(), "%"))) {
            var op = tokens[position++].value;
            var right = parseUnary();
            usedOperator = true;
            if (op === "*") {
                left = left * right;
            } else if (op === "/") {
                left = left / right;
            } else {
                left = left % right;
            }
        }
        return left;
    }

    function parseUnary() {
        if (isOp(peek(), "-")) {
            ++position;
            usedOperator = true;
            return -parseUnary();
        }
        if (isOp(peek(), "+")) {
            ++position;
            return parseUnary();
        }
        return parsePower();
    }

    function parsePower() {
        var base = parsePrimary();
        if (!failed && isOp(peek(), "^")) {
            ++position;
            usedOperator = true;
            var exponent = parseUnary();
            return Math.pow(base, exponent);
        }
        return base;
    }

    function parsePrimary() {
        var token = peek();
        if (token === null) {
            failed = true;
            return 0;
        }
        if (token.type === "num") {
            ++position;
            return token.value;
        }
        if (token.type === "id") {
            ++position;
            if (constants[token.value] !== undefined) {
                return constants[token.value];
            }
            if (functions[token.value] !== undefined && isOp(peek(), "(")) {
                ++position;
                var argument = parseExpression();
                if (!isOp(peek(), ")")) {
                    failed = true;
                    return 0;
                }
                ++position;
                usedOperator = true;
                return functions[token.value](argument);
            }
            failed = true;
            return 0;
        }
        if (isOp(token, "(")) {
            ++position;
            var inner = parseExpression();
            if (!isOp(peek(), ")")) {
                failed = true;
                return 0;
            }
            ++position;
            return inner;
        }
        failed = true;
        return 0;
    }

    var result = parseExpression();
    if (failed || position !== tokens.length || !usedOperator || !isFinite(result)) {
        return null;
    }
    return {
        "value": result,
        "text": String(Number(result.toPrecision(12)))
    };
}
