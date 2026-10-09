import QtQuick

QtObject {
    id: root

    required property var editor
    property var multi: null

    // Start index of the line containing position p. The old
    // lastIndexOf("\n", p - 1) is wrong at p === 0: a negative fromIndex is
    // clamped to 0, so a doc starting with "\n" gives a false match.
    function lineStartOf(doc, p) {
        if (p <= 0) return 0;
        return doc.lastIndexOf("\n", p - 1) + 1;
    }

    function handleMultiCursorKey(event) {
        var pos = editor.cursorPosition;
        var mods = event.modifiers;
        var blocked = Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier;

        if (event.key === Qt.Key_Escape) {
            multi.clear();
            event.accepted = true;
            return true;
        }

        // Movement: extra carets move here, the main caret moves natively afterwards
        if (!(mods & Qt.AltModifier)) {
            var dir = "";
            if (event.key === Qt.Key_Left) dir = "left";
            else if (event.key === Qt.Key_Right) dir = "right";
            else if (event.key === Qt.Key_Up) dir = "up";
            else if (event.key === Qt.Key_Down) dir = "down";
            else if (event.key === Qt.Key_Home) dir = "home";
            else if (event.key === Qt.Key_End) dir = "end";
            if (dir !== "") {
                if (mods & Qt.ShiftModifier) {
                    multi.clear();   // selections aren't supported with several carets
                    return true;
                }
                multi.move(dir, (mods & Qt.ControlModifier) !== 0);
                return true;         // left unaccepted so TextEdit moves the main caret
            }
        }

        if (event.key === Qt.Key_Backspace && !(mods & blocked)) {
            editor.cursorPosition = multi.deleteBackward(pos);
            event.accepted = true;
            return true;
        }
        if (event.key === Qt.Key_Delete && !(mods & blocked)) {
            editor.cursorPosition = multi.deleteForward(pos);
            event.accepted = true;
            return true;
        }
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(mods & blocked)) {
            editor.cursorPosition = multi.insertNewline(pos);
            event.accepted = true;
            return true;
        }
        if (event.key === Qt.Key_Tab && !(mods & blocked)) {
            editor.cursorPosition = multi.insertText("    ", pos);
            event.accepted = true;
            return true;
        }
        if (event.key === Qt.Key_Backtab) {
            event.accepted = true;
            return true;
        }
        if (!(mods & blocked) && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
            editor.cursorPosition = multi.insertText(event.text, pos);
            event.accepted = true;
            return true;
        }
        return false;
    }

    function handleKeyPress(event) {
        if (multi && multi.active && handleMultiCursorKey(event)) return;

        var pos = editor.cursorPosition;
        var doc = editor.text;

        // 1. Move Lines Up / Down: Alt + Up / Alt + Down
        if (event.modifiers === Qt.AltModifier && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            var isUp = (event.key === Qt.Key_Up);
            var sStart = (editor.selectionStart !== editor.selectionEnd) ? editor.selectionStart : pos;
            var sEnd = (editor.selectionStart !== editor.selectionEnd) ? editor.selectionEnd : pos;

            var startBound = lineStartOf(doc, sStart);

            var blockEnd = doc.indexOf("\n", sEnd);
            var endBound = (blockEnd === -1) ? doc.length : blockEnd;

            var lines = doc.split("\n");
            var startLine = doc.substring(0, startBound).split("\n").length - 1;
            var endLine = doc.substring(0, endBound).split("\n").length - 1;

            if (isUp) {
                if (startLine > 0) {
                    var aboveLine = lines[startLine - 1];
                    lines.splice(startLine - 1, 1);
                    lines.splice(endLine, 0, aboveLine);
                    var replaceStart = lineStartOf(doc, startBound - 1);
                    var newChunk = lines.slice(startLine - 1, endLine + 1).join("\n");

                    editor.remove(replaceStart, endBound);
                    editor.insert(replaceStart, newChunk);
                    var shiftedStart = lines.slice(0, startLine - 1).join("\n").length + (startLine - 1 > 0 ? 1 : 0);
                    var shiftedEnd = lines.slice(0, endLine).join("\n").length;
                    editor.select(shiftedStart, shiftedEnd);
                }
            } else {
                if (endLine < lines.length - 1) {
                    var belowLine = lines[endLine + 1];
                    lines.splice(endLine + 1, 1);
                    lines.splice(startLine, 0, belowLine);
                    var nextLineEnd = doc.indexOf("\n", endBound + 1);
                    var replaceEnd = (nextLineEnd === -1) ? doc.length : nextLineEnd;
                    var newChunk2 = lines.slice(startLine, endLine + 2).join("\n");

                    editor.remove(startBound, replaceEnd);
                    editor.insert(startBound, newChunk2);
                    var shiftedStart2 = lines.slice(0, startLine + 1).join("\n").length + 1;
                    var shiftedEnd2 = lines.slice(0, endLine + 2).join("\n").length;
                    editor.select(shiftedStart2, shiftedEnd2);
                }
            }
            event.accepted = true;
            return;
        }

        // 2. Tab & Shift+Tab Indentation
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            var isShift = (event.key === Qt.Key_Backtab) || (event.modifiers & Qt.ShiftModifier);

            if (editor.selectionStart !== editor.selectionEnd) {
                var selStart = editor.selectionStart;
                var selEnd = editor.selectionEnd;

                var rStart = lineStartOf(doc, selStart);
                var bEnd = doc.indexOf("\n", selEnd);
                var rEnd = (bEnd === -1) ? doc.length : bEnd;

                var selectedChunk = doc.substring(rStart, rEnd);
                var chunkLines = selectedChunk.split("\n");
                var modifiedLines = [];
                var netOffsetChange = 0;

                for (var i = 0; i < chunkLines.length; i++) {
                    var line = chunkLines[i];
                    if (isShift) {
                        var unindented = line.replace(/^( {1,4}|\t)/, "");
                        netOffsetChange -= (line.length - unindented.length);
                        modifiedLines.push(unindented);
                    } else {
                        modifiedLines.push("    " + line);
                        netOffsetChange += 4;
                    }
                }

                var newChunkTab = modifiedLines.join("\n");
                editor.remove(rStart, rEnd);
                editor.insert(rStart, newChunkTab);
                editor.select(rStart, rEnd + netOffsetChange);
            } else {
                if (isShift) {
                    var sIdx = lineStartOf(doc, pos);
                    var linePrefix = doc.substring(sIdx, pos);
                    var spacesToRemove = linePrefix.match(/( {1,4}|\t)$/);
                    if (spacesToRemove) {
                        editor.remove(pos - spacesToRemove[0].length, pos);
                    }
                } else {
                    editor.insert(pos, "    ");
                    editor.cursorPosition = pos + 4;
                }
            }
            event.accepted = true;
            return;
        }

        // 3. Ctrl + / (Comment / Uncomment)
        if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_Slash) {
            var cStartIdx = lineStartOf(doc, pos);
            var cLineEnd = doc.indexOf("\n", pos);
            var cEndIdx = (cLineEnd === -1) ? doc.length : cLineEnd;
            var currentLine = doc.substring(cStartIdx, cEndIdx);

            var commentMatch = currentLine.match(/^(\s*)(\/\/ ?)/);
            if (commentMatch) {
                var stripped = currentLine.replace(/^(\s*)\/\/ ?/, "$1");
                editor.remove(cStartIdx, cEndIdx);
                editor.insert(cStartIdx, stripped);
                editor.cursorPosition = Math.max(cStartIdx, pos - commentMatch[2].length);
            } else {
                var indentMatch = currentLine.match(/^(\s*)/);
                var ws = indentMatch ? indentMatch[1] : "";
                var rest = currentLine.substring(ws.length);
                var commented = ws + "// " + rest;
                editor.remove(cStartIdx, cEndIdx);
                editor.insert(cStartIdx, commented);
                editor.cursorPosition = pos + 3;
            }
            event.accepted = true;
            return;
        }

        // 4. Ctrl + D (Duplicate line or selection)
        if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_D) {
            if (editor.selectionStart !== editor.selectionEnd) {
                var sel = editor.selectedText;
                var insertAt = editor.selectionEnd;
                editor.insert(insertAt, sel);
                editor.cursorPosition = insertAt + sel.length;
            } else {
                var dSIdx = lineStartOf(doc, pos);
                var dLineEnd = doc.indexOf("\n", pos);
                var dEIdx = (dLineEnd === -1) ? doc.length : dLineEnd;
                var fullLine = doc.substring(dSIdx, dEIdx);

                editor.insert(dEIdx, "\n" + fullLine);
                editor.cursorPosition = pos + fullLine.length + 1;
            }
            event.accepted = true;
            return;
        }

        // 5. Smart Indent on Enter
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            var charBefore = (pos > 0) ? doc.charAt(pos - 1) : "";
            var charAfter = (pos < doc.length) ? doc.charAt(pos) : "";

            if (charBefore === "{" && charAfter === "}") {
                var brLine = doc.substring(lineStartOf(doc, pos - 1), pos - 1);
                var brIndent = (brLine.match(/^(\s*)/) || ["", ""])[1];
                var extra = "    ";

                editor.insert(pos, "\n" + brIndent + extra + "\n" + brIndent);
                editor.cursorPosition = pos + 1 + brIndent.length + extra.length;
                event.accepted = true;
                return;
            }

            var curLine = doc.substring(lineStartOf(doc, pos), pos);
            var matchWs = curLine.match(/^(\s*)/);
            var leadWs = matchWs ? matchWs[1] : "";

            if (leadWs.length > 0) {
                editor.insert(pos, "\n" + leadWs);
                editor.cursorPosition = pos + 1 + leadWs.length;
                event.accepted = true;
                return;
            }
        }

        // 6a. Skip over an already-present closing bracket / quote
        var closers = ")]}\"'";
        if (event.text.length === 1 && closers.indexOf(event.text) !== -1
            && pos < doc.length && doc.charAt(pos) === event.text) {
            editor.cursorPosition = pos + 1;
            event.accepted = true;
            return;
        }

        // 6b. Bracket / Quote Auto-closing
        var pairs = {
            "(": ")",
            "{": "}",
            "[": "]",
            "\"": "\"",
            "'": "'"
        };

        if (pairs[event.text] !== undefined) {
            var openChar = event.text;
            var closeChar = pairs[openChar];
            editor.insert(pos, openChar + closeChar);
            editor.cursorPosition = pos + 1;
            event.accepted = true;
            return;
        }
    }
}
