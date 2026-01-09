; ==========================================================
; 00_TEMPLATE_AHKv2_STRICT_v2__CapCut_Automation_Engine.ahk
; STRICT TEMPLATE v2 (AHK v2.x) — Engine-safe scaffold
; ==========================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut
SetWorkingDir(A_ScriptDir)

; ==========================================================
; TEMPLATE CONTRACT (DO NOT REMOVE)
; ==========================================================
; Goal: reduce AHK v2 syntax footguns so patchers don't break builds.
;
; RULES:
; 1) Avoid try/catch in patches. Use .Has() + wrappers.
;    - AHK v2 requires catch blocks with braces:
;      ✅ try { ... } catch { ... }
;      ❌ catch x := 0   (INVALID SYNTAX)
; 2) Prefer wrappers for Map access (MapGet/MapSet/MapDel).
; 3) Use braces for control flow:
;      ✅ if (x) { ... }   ❌ if (x) return
; 4) Patch ONLY inside PATCH ZONE below.
;
; IMPORTANT LIMIT:
; - No template can prevent *unparsable* syntax errors (the script won't start).
;   This template minimizes the need for risky constructs and fails fast for
;   dangerous-but-parsable patterns.
; ==========================================================

; =========================
; STRICT FLAGS
; =========================
global __T_STRICT := true
global __T_LINT_ON_START := true
global __T_LINT_FAIL_FAST := true

; =========================
; BASIC LOGGER (StdOut-friendly)
; =========================
Log(tag, msg := "", kv*) {
    ; kv is optional key/value pairs: Log("TAG", "msg", "k1", v1, "k2", v2)
    s := Format("{1:} | {2:} | {3:}", A_Now, tag, msg)
    if (kv.Length) {
        i := 1
        while (i <= kv.Length) {
            k := kv[i]
            v := (i+1 <= kv.Length) ? kv[i+1] : ""
            s .= Format(" | {1:}={2:}", k, v)
            i += 2
        }
    }
    FileAppend(s "`n", "*")
}

; =========================
; SAFE MAP WRAPPERS (preferred)
; =========================
MapGet(m, key, default := 0) {
    if !IsObject(m) {
        throw Error("MapGet: target is not an object")
    }
    if m.Has(key) {
        return m[key]
    }
    return default
}

MapSet(m, key, value) {
    if !IsObject(m) {
        throw Error("MapSet: target is not an object")
    }
    m[key] := value
    return value
}

MapDel(m, key) {
    if !IsObject(m) {
        throw Error("MapDel: target is not an object")
    }
    if m.Has(key) {
        m.Delete(key)
        return true
    }
    return false
}

; =========================
; STRICT LINTER (parsable pattern checks)
; =========================
TemplateLint_Strict() {
    if !__T_LINT_ON_START {
        return
    }

    if !FileExist(A_ScriptFullPath) {
        Log("LINT", "WARN Script file missing; skipping lint")
        return
    }

    ; FileRead can still throw in rare cases, but avoiding try/catch is part of strict mode.
    src := FileRead(A_ScriptFullPath, "UTF-8")

    ; 1) catch without braces (common AHK v1 habit). This is parsable when written as "catch e".
    if RegExMatch(src, "im)^\s*catch\s+(?!\{)") {
        __T_LintFail("Found 'catch' without braces. Use: catch { ... }")
        return
    }

    ; 2) try usage (discouraged in strict patches).
    if RegExMatch(src, "im)^\s*try\b") {
        __T_LintFail("Found 'try'. Prefer .Has() + MapGet/MapSet instead of try/catch.")
        return
    }

    ; 3) Inline if without braces: if (...) return / if (...) x:=y
    if RegExMatch(src, "im)^\s*if\s*\([^\)]*\)\s*[^\{\s]") {
        __T_LintFail("Inline 'if (...) <stmt>' detected. Use braces: if (...) { ... }")
        return
    }

    ; 4) Soft-warning for direct indexing '[ ]' (heuristic).
    if RegExMatch(src, "im)\b\w+\s*\[[^\]]+\]") {
        Log("LINT", "WARN Direct indexing '[ ]' detected. Prefer MapGet/MapSet for Maps.")
    }

    Log("LINT", "OK")
}

__T_LintFail(reason) {
    Log("LINT", "FAIL", "reason", reason)
    if __T_LINT_FAIL_FAST {
        MsgBox("STRICT TEMPLATE LINT FAIL:`n`n" reason, "Template v2", 0x10)
        ExitApp
    }
}

; ==========================================================
; ================= PATCH ZONE BEGIN ========================
; Add your patches / features here (engine-safe).
; ================= PATCH ZONE END ==========================
; ==========================================================

; =========================
; AUTO-EXEC
; =========================
TemplateLint_Strict()

; Example entry point:
; Main()
; return
;
; Main() {
;     Log("MAIN", "start")
; }
