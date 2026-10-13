import QtQuick
import QtQuick
import NotepadQtQuick

QtObject {
    id: root

    required property var editor
    property var multi: null
    property string commentToken: "//"

    property var edits: TextSearcher { }

    // Start index of the line containing position p. The old
    // lastIndexOf("\n", p - 1) is wrong at p === 0: a negative fromIndex is
    // clamped to 0, so a doc starting with "\n" gives a false match.
    function lineStartOf(doc, p) {
        if (p <= 0) return 0;
        return doc.lastIndexOf("\n", p - 1) + 1;
    }

    function isWordCh(c) {
        return c !== "" && (/[A-Za-z0-9_]/.test(c) || c.charCodeAt(0) > 127);
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
        // Fast path: keys that none of the editing features care about skip the text copy
        var k = event.key, m = event.modifiers;
        var needsText = ((m === Qt.AltModifier) && (k === Qt.Key_Up || k === Qt.Key_Down))
        || k === Qt.Key_Tab || k === Qt.Key_Backtab
        || ((m === Qt.ControlModifier) && (k === Qt.Key_Slash || k === Qt.Key_D))
        || k === Qt.Key_Return || k === Qt.Key_Enter
        || (event.text.length === 1 && "(){}[]\"'".indexOf(event.text) !== -1);
        if (!needsText) return;

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

                    edits.replaceRange(editor.textDocument, replaceStart, endBound - replaceStart, newChunk);

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

                    edits.replaceRange(editor.textDocument, startBound, replaceEnd - startBound, newChunk2);

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
                edits.replaceRange(editor.textDocument, rStart, rEnd - rStart, newChunkTab);

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

        // 3. Ctrl + / (Comment / Uncomment) for one line or every line of a selection
        if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_Slash) {
            event.accepted = true;
            var tok = root.commentToken;
            if (tok === "") return;

            var hasCSel = editor.selectionStart !== editor.selectionEnd;
            var cFrom = hasCSel ? editor.selectionStart : pos;
            var cTo = hasCSel ? editor.selectionEnd : pos;
            // A selection that ends right at the start of a line doesn't include that line
            if (hasCSel && doc.charAt(cTo - 1) === "\n") cTo -= 1;

            var cStartIdx = lineStartOf(doc, cFrom);
            var cLineEnd = doc.indexOf("\n", cTo);
            var cEndIdx = (cLineEnd === -1) ? doc.length : cLineEnd;
            var cLines = doc.substring(cStartIdx, cEndIdx).split("\n");

            var tokRe = tok.replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&");
            var commentedRe = new RegExp("^(\\s*)" + tokRe + " ?");

            // Blank lines are skipped, unless every line is blank
            var targets = [];
            for (var ci = 0; ci < cLines.length; ci++)
                if (cLines[ci].trim() !== "") targets.push(ci);
            if (targets.length === 0)
                for (ci = 0; ci < cLines.length; ci++) targets.push(ci);

            var allCommented = true;
            for (var ti = 0; ti < targets.length; ti++) {
                if (!commentedRe.test(cLines[targets[ti]])) { allCommented = false; break; }
            }

            var firstIndent = cLines[0].match(/^\s*/)[0].length;
            var minIndent = 0;
            if (allCommented) {
                for (ti = 0; ti < targets.length; ti++)
                    cLines[targets[ti]] = cLines[targets[ti]].replace(commentedRe, "$1");
            } else {
                minIndent = cLines[targets[0]].match(/^\s*/)[0].length;
                for (ti = 1; ti < targets.length; ti++)
                    minIndent = Math.min(minIndent, cLines[targets[ti]].match(/^\s*/)[0].length);
                for (ti = 0; ti < targets.length; ti++) {
                    var tl = cLines[targets[ti]];
                    cLines[targets[ti]] = tl.substring(0, minIndent) + tok + " " + tl.substring(minIndent);
                }
            }

            var newChunkC = cLines.join("\n");
            var cDelta = newChunkC.length - (cEndIdx - cStartIdx);
            edits.replaceRange(editor.textDocument, cStartIdx, cEndIdx - cStartIdx, newChunkC);

            if (hasCSel) {
                editor.select(cStartIdx, cStartIdx + newChunkC.length);   // whole block, so Ctrl+/ again toggles it back
            } else {
                var colNow = pos - cStartIdx;
                var newCol;
                if (allCommented)
                    newCol = (colNow <= firstIndent) ? colNow : Math.max(firstIndent, colNow + cDelta);
                else
                    newCol = (colNow >= minIndent) ? colNow + cDelta : colNow;
                editor.cursorPosition = cStartIdx + newCol;
            }
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
            var hasEnterSel = editor.selectionStart !== editor.selectionEnd;
            var selFromE = hasEnterSel ? editor.selectionStart : pos;
            var selToE = hasEnterSel ? editor.selectionEnd : pos;

            // The text as it will look once the selection is gone
            var base = hasEnterSel ? doc.substring(0, selFromE) + doc.substring(selToE) : doc;
            pos = selFromE;

            var charBefore = (pos > 0) ? base.charAt(pos - 1) : "";
            var charAfter = (pos < base.length) ? base.charAt(pos) : "";

            if (charBefore === "{" && charAfter === "}") {
                var brLine = base.substring(lineStartOf(base, pos - 1), pos - 1);
                var brIndent = (brLine.match(/^(\s*)/) || ["", ""])[1];
                var extra = "    ";

                var braceText = "\n" + brIndent + extra + "\n" + brIndent;
                if (hasEnterSel)
                    edits.replaceRange(editor.textDocument, selFromE, selToE - selFromE, braceText);
                else
                    editor.insert(pos, braceText);
                editor.cursorPosition = pos + 1 + brIndent.length + extra.length;
                event.accepted = true;
                return;
            }

            var curLine = base.substring(lineStartOf(base, pos), pos);
            var matchWs = curLine.match(/^(\s*)/);
            var leadWs = matchWs ? matchWs[1] : "";

            if (leadWs.length > 0 || hasEnterSel) {
                var indentText = "\n" + leadWs;
                if (hasEnterSel)
                    edits.replaceRange(editor.textDocument, selFromE, selToE - selFromE, indentText);
                else
                    editor.insert(pos, indentText);
                editor.cursorPosition = pos + 1 + leadWs.length;
                event.accepted = true;
                return;
            }
        }

        // 6. Brackets and quotes
        var typed = event.text;
        var pairs = {
            "(": ")",
            "{": "}",
            "[": "]",
            "\"": "\"",
            "'": "'"
        };
        var hasSel = editor.selectionStart !== editor.selectionEnd;

        // 6a. Typing an opener over a selection wraps the selection
        if (hasSel && typed.length === 1 && pairs[typed] !== undefined) {
            var wrapFrom = editor.selectionStart;
            var wrapTo = editor.selectionEnd;
            var inner = doc.substring(wrapFrom, wrapTo);
            edits.replaceRange(editor.textDocument, wrapFrom, wrapTo - wrapFrom, typed + inner + pairs[typed]);
            editor.select(wrapFrom + 1, wrapTo + 1);
            event.accepted = true;
            return;
        }

        // 6b. Skip over an already-present closing bracket / quote
        var closers = ")]}\"'";
        if (!hasSel && typed.length === 1 && closers.indexOf(typed) !== -1
            && pos < doc.length && doc.charAt(pos) === typed) {
            editor.cursorPosition = pos + 1;
        event.accepted = true;
        return;
            }

            // 6c. Auto-close
            if (!hasSel && typed.length === 1 && pairs[typed] !== undefined) {
                if (typed === "\"" || typed === "'") {
                    var prevCh = (pos > 0) ? doc.charAt(pos - 1) : "";
                    var nextCh = (pos < doc.length) ? doc.charAt(pos) : "";
                    if (isWordCh(prevCh) || isWordCh(nextCh))
                        return;     // don't, it's, 5' ... let TextEdit type just the one character
                }
                editor.insert(pos, typed + pairs[typed]);
                editor.cursorPosition = pos + 1;
                event.accepted = true;
                return;
                }
            }
        }
