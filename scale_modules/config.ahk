; ==================================================================================================
; CONFIG MODULE
; --------------------------------------------------------------------------------------------------
; INI helpers (IniReadSafe, IniWriteSafe), text map T(), global defaults, debug flags
; ==================================================================================================

; ============================================================
; PATCHABLE_ZONE__BOOT_LINT_BEGIN
; Self-lint / runtime error guard / GUI text-lock (template-aligned)
; RULE: Do NOT hardcode GUI text in Add*(). Use T("KEY") + __TXT map below.
; ============================================================

global __TXT_READY := false
global __TXT := Map()

global __UI_IS_TESTING := 0
global __DBG_ENTRYPOINT := 1
global __TEST_FORCE_BEHVALID := false

__ENTRY_Log(where, msg := "") {
    global __DBG_ENTRYPOINT
    if (!__DBG_ENTRYPOINT) {
        return
    }
    if (msg != "") {
        Log(where " | " msg, "DEBUG", "ENTRY")
    } else {
        Log(where, "DEBUG", "ENTRY")
    }
}



; --- Decision Trace + Click Policy Debug (A3) ---
; Engine-safe: logs only (no behavior changes)
global __DBG_DECIDE := 1
global __DBG_CLICKPOLICY := 1

global __TEST_LAST := Map()
global __TEST_LAST_READY := false

__STR_Join(arr, sep := " ") {
    ; STRICT (NO try/catch): safe join for Array-like objects.
    if (!IsObject(arr)) {
        return "" arr
    }
    out := ""
    first := true
    for _, v in arr {
        if (first) {
            out := "" v
            first := false
        } else {
            out := out sep "" v
        }
    }
    return out
}


__DECIDE__ToStr(v := "") {
    ; STRICT (NO try/catch): keep stringify safe by pre-filtering objects.
    if IsObject(v) {
        return "<obj>"
    }
    return "" v
}

__DECIDE__KV(fields := "") {
    if (!IsObject(fields))
        return __DECIDE__ToStr(fields)
    parts := []
    for k, v in fields {
        parts.Push(k "=" __DECIDE__ToStr(v))
    }
    return parts.Length ? __STR_Join(parts, " ") : ""
}

__DECIDE_Log(step := "", fields := "") {
    global __DBG_DECIDE
    if (!__DBG_DECIDE) {
        return
    }
    msg := step
    kv := __DECIDE__KV(fields)
    if (kv != "") {
        msg := msg " | " kv
    }
    ; Log() is part of the engine; do not swallow errors here in STRICT mode.
    Log(msg, "DEBUG", "DECIDE")
}

__TEST_DiagReset() {
    global __TEST_LAST, __TEST_LAST_READY
    __TEST_LAST := Map()
    __TEST_LAST_READY := true
}

__TEST_DiagSet(reason := "", fields := "") {
    global __TEST_LAST, __TEST_LAST_READY
    if (!__TEST_LAST_READY)
        __TEST_DiagReset()
    __TEST_LAST["reason"] := reason
    if (IsObject(fields)) {
        for k, v in fields
            __TEST_LAST[k] := v
    }
    __DECIDE_Log("TEST_DIAG", __TEST_LAST)
}

ClickPolicy_Explain(context := "") {
    global __UI_IS_TESTING, IS_RUNNING, busy
    out := Map()
    out["ctx"] := context
    out["isTesting"] := __UI_IS_TESTING
    out["IS_RUNNING"] := IS_RUNNING
    out["busy"] := busy

    reasons := []
    allow := true

    ; In TEST mode, allow click regardless of busy flag.
    if (!__UI_IS_TESTING) {
        if (IS_RUNNING) {
            allow := false
            reasons.Push("IS_RUNNING")
        }
        if (busy) {
            allow := false
            reasons.Push("busy")
        }
    }

    out["allow"] := allow ? 1 : 0
    out["reasons"] := reasons.Length ? __STR_Join(reasons, ",") : ""
    return out
}

; --- NO_WARN defaults (lint-silencer, engine-safe) ---
; These globals are referenced in UI helpers / F3 overlay but may be created dynamically later.
; Providing safe defaults prevents AHK v2 static warnings without changing runtime logic.
global lbModules   := 0
global UI_PAD      := 12
global UI_HEADER_H := 60
global UI_ACTION_H := 110
global UI_LEFT_W   := 260
global gbScale     := 0
global gbRois      := 0
global gbAnchors   := 0
global gbHistory   := 0
global gbSettings  := 0
global F3_ROI_ORDER := Map()
global busy := false


__BuildTXT() {
    global __TXT, __TXT_READY
    if __TXT_READY
        return
    __TXT["BTN_ADD"] := "Add"
    __TXT["BTN_ADVANCED"] := "Advanced ▼"
    __TXT["BTN_PREVIEW"] := "Preview"
    __TXT["BTN_REMOVE"] := "Remove"
    __TXT["BTN_RESET_UI"] := "Reset UI"
    __TXT["BTN_RUN"] := "Run"
    __TXT["BTN_SAVE_INI"] := "Save INI"
    __TXT["BTN_SET_PARENT_F3"] := "Set Parent (F3)"
    __TXT["BTN_SHOW"] := "Show"
    __TXT["BTN_SHOW_BORDERS"] := "Show Borders"
    __TXT["BTN_START_F1"] := "Start (F1)"
    __TXT["BTN_STOP"] := "Stop"
    __TXT["BTN_LEARN_DIAMOND_F4"] := "Learn Diamond (F4)"
    __TXT["BTN_TEST_CLICK"] := "Test Click"
    __TXT["BTN_TXT_01"] := "⚙"
    __TXT["BTN_UPDATE"] := "Update"
    __TXT["CHK_AUTO_HIDE_WHILE_RUN"] := "Auto-hide while RUN"
    __TXT["CHK_F2_SCAN"] := "F2 Scan"
    __TXT["EDT_HOW_TO_USE_N"] := "How to use:`n"
    __TXT["EDT_QUICK_START_N"] := "Quick start:`n"
    __TXT["GRP_ACTIONS"] := "Actions"
    __TXT["GRP_ADVANCED"] := "Advanced"
    __TXT["GRP_AUTO_KEYFRAME_CYCLE_A_B"] := "Auto Keyframe Cycle (A ↔ B)"
    __TXT["TXT_A"] := "A"
    __TXT["TXT_B"] := "B"
    __TXT["TXT_CAPCUT_AUTO_KEYFRAME_TOOL"] := "CapCut Auto Keyframe Tool"
    __TXT["TXT_DIAMOND_ANCHORS"] := "Diamond anchors:"
    __TXT["TXT_F3_ROIS"] := "F3 ROIs:"
    __TXT["TXT_FOCUS_A_NUMERIC_FIELD_IN_CAPCUT_F4_L"] := "Focus a numeric field in CapCut → F4 Learn Diamond → F1 Start/Stop (ESC = Emergency Stop)"
    __TXT["TXT_HISTORY_RECORDS_LAST_CAPTURES_AND_CO"] := "History records last captures and coordinates. Useful for debugging when UI changes."
    __TXT["TXT_ITEMS_0"] := "Items: 0"
    __TXT["TXT_PARENT_HISTORY"] := "Parent history:"
    __TXT["TXT_PARENT_REGION"] := "Parent region:"
    __TXT["TXT_READY"] := "READY"
    __TXT["TXT_ROIS_0"] := "ROIs: 0"
    __TXT["TXT_SCALE_ANCHORS"] := "Scale anchors:"
    __TXT["TXT_SCAN_HISTORY_NEWEST_FIRST"] := "Scan history (newest first):"
    __TXT["TXT_STATUS_READY"] := "Status: Ready."
    __TXT["TXT_TXT_01"] := "●"
    __TXT_READY := true
}

T(key) {
    global __TXT, __TXT_READY
    if !__TXT_READY
        __BuildTXT()
    if __TXT.Has(key)
        return __TXT[key]
    throw Error("Missing TXT key: " key, -1)
}

Opt(parts*) {
    out := ""
    for _, p in parts {
        if (p = "")
            continue
        out .= (out = "" ? p : " " p)
    }
    return out
}

__SelfLint_Boot() {
    if !InStr(A_AhkVersion, "2.") {
        MsgBox "❌ Script requires AutoHotkey v2.x", "Version Error", 16
        ExitApp
    }
    __BuildTXT()
}

__ErrProp(err, name, default := "") {
    try {
        return err.%name%
    } catch {
        return default
    }
}

__Fatal(err) {
    line := __ErrProp(err, "Line", "?")
    what := __ErrProp(err, "What", "")
    msg  := __ErrProp(err, "Message", "")
    extra := (what != "" ? "`nWhat: " what : "")
    extra .= (msg != "" ? "`nMessage: " msg : "")
    MsgBox(
        "❌ AHK v2 ERROR (guarded)`n`n"
        . "Line: " line
        . extra
        . "`n`nScript stopped to prevent undefined automation state.",
        "CapCut Tool — Self-Lint",
        16
    )
    ExitApp
}

__OnError(err, mode) {
    __Fatal(err)
    return 1
}

; -------- INI fault surfacing (WRITE only, once) --------
NotifyIniWriteFaultOnce(file, section, key) {
    global iniFaultNotified
    if (iniFaultNotified)
        return
    iniFaultNotified := true
    try {
        MsgBox "INI WRITE FAILED!`n`nFile: " file "`nSection: [" section "]`nKey: " key "`n`nClose any editor/permission lock, then try again.", "ScaleCycle", "Iconx"
    } catch {
    }
    ; (Layer7) Core must not depend on UI. Status surfacing handled by UI/Behavior.
    Log("INI WRITE FAILED file=" file " section=" section " key=" key, "WARN", "INI")
}


EnsureIniFile() {
    global CFG_FILE, iniFaulted
    try {
        if !FileExist(CFG_FILE) {
            FileAppend("", CFG_FILE, "UTF-8")
        }
    } catch {
        iniFaulted := true
    }
}


IniReadSafe(file, section, key, default := "") {
    global iniFaulted
    try {
        return IniRead(file, section, key, default)
    } catch {
        iniFaulted := true
        return default
    }
}


IniWriteSafe(value, file, section, key) {
    global iniFaulted
    try {
        IniWrite(value, file, section, key)
        return true
    } catch {
        iniFaulted := true
        NotifyIniWriteFaultOnce(file, section, key)
        return false
    }
}

; -------- Global defaults --------
global LOG_FILE := A_ScriptDir "\error.log"

; ---- Capture debug master toggles ----
global CAP_DEBUG := true
global CAP_DEBUG_DEEP := false

; Use DXGI Desktop Duplication exe (dxgi_cap.exe) before GDI capture.
global CAP_USE_DXGI := true

global GdipToken := 0

; Per-state flags (giúp đọc log nhanh)
global ST_INPUT_OK := false
global ST_SEGMENT_OK := false
global ST_FILTER_OK := false
global ST_BEHAVIOR_OK := false
global ST_MODEL_OK := false
global ST_MATCH_OK := false
global ST_DECISION := ""               ; "PASS" | "FAIL" | ""
global ST_ACTION_DONE := false

; Last-known context/metrics (optional – phục vụ debug)
global ST_RECT_ABS := ""               ; "L,T,R,B"
global ST_RECT_REL := ""               ; "l,t,r,b"
global ST_BMP_ROI := 0                 ; bitmap ROI hiện tại (pBitmap)
global ST_MODEL_ID := ""               ; tên/khóa model

global SEG_WCELLS := 0
global SEG_HCELLS := 0
global SEG_TOTAL_CELLS := 0

global FILT_MASK_ON := 0
global FILT_MASK_TOTAL := 0
global FILT_MASK_RATIO := 0.0
global FILT_DILATE_LEVEL := 0
global FILT_MASK_AFTER := 0

global BEH_W := 0
global BEH_H := 0
global BEH_RATIO := 0.0
global BEH_CONTRAST := 0.0
global BEH_EDGE_D := 0.0
global BEH_SCORE := 0.0

global MODEL_BLOB_COUNT := 0
global MODEL_CANDS := 0
global MODEL_KEPT := 0

global MATCH_SCORE := 0.0
global MATCH_SCORE_MIN := 0.30

; -------- GUI EDITOR --------
global GUI_EDIT_MODE := false
global GUI_ACTIVE_ROI := 0

; Debug toggles for template saving
global __DBG_SAVE_TPL := 1

DBG__ShouldSaveTpl(pipeMode := "", force := false) {
    global __DBG_SAVE_TPL
    if (!__DBG_SAVE_TPL && !force)
        return false
    return true
}

DBG__MakeUniqueBmpPath(prefix := "tpl") {
    t := A_Now
    name := Format("{}_{}.bmp", prefix, t)
    path := A_ScriptDir "\" name
    idx := 1
    while (FileExist(path)) {
        name := Format("{}_{}_{}.bmp", prefix, t, idx)
        path := A_ScriptDir "\" name
        idx += 1
    }
    return path
}
