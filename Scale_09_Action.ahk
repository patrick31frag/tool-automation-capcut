; ==================================================================================================
;  MODULE 09 — Action
;  Source lines (original scale.ahk): 3904 – 4354
; ==================================================================================================
UI_UpdateGui(force := false) {
    global stStatus
    global UI_STATE, UI_STATE_REASON, UI_STATE_SINCE_TICK, UI_STATE_TIMEOUT_MS, UI_RUN_SINCE_TICK
    global UI_LAST_GUI_STATE, UI_LAST_GUI_REASON, UI_LAST_GUI_TICK

    now := A_TickCount

    ; throttle repaint để GUI không lag (trừ khi force)
    if (!force) {
        if (UI_LAST_GUI_STATE = UI_STATE && UI_LAST_GUI_REASON = UI_STATE_REASON) {
            if (now - UI_LAST_GUI_TICK < 120)
                return
        }
    }

    elapsedSec := 0.0
    if (UI_STATE_SINCE_TICK > 0)
        elapsedSec := (now - UI_STATE_SINCE_TICK) / 1000.0

    runSec := 0.0
    if (UI_RUN_SINCE_TICK > 0)
        runSec := (now - UI_RUN_SINCE_TICK) / 1000.0

    msg := UI_STATE
    if (UI_STATE_REASON != "")
        msg .= " | " UI_STATE_REASON

    if (UI_STATE != "IDLE") {
        if (UI_STATE_TIMEOUT_MS > 0) {
            msg .= " | " Format("{:.2f}s/{:.2f}s", elapsedSec, UI_STATE_TIMEOUT_MS/1000.0)
        } else {
            msg .= " | " Format("{:.2f}s", elapsedSec)
        }
        if (UI_RUN_SINCE_TICK > 0)
            msg .= " | run=" Format("{:.2f}s", runSec)
    }

    try {
        stStatus.Text := "Status: " msg
    } catch {
    }

    UI_LAST_GUI_STATE := UI_STATE
    UI_LAST_GUI_REASON := UI_STATE_REASON
    UI_LAST_GUI_TICK := now

    try {
        UI_UpdateStateBadge()
    } catch {
    }
    try {
        UI_ApplyEnablePolicy(false)
    } catch {
    }
}

; ==================================================================================================
; PATCHABLE_ZONE_UI_HELPERS_BEGIN
; UI-only helpers for module switching + state badge + enable/disable policy.
; Engine logic remains unchanged.
; ==================================================================================================

UI_OnModuleChange(*) {
    global lbModules, UI_ACTIVE_MODULE, running

    ; Lock navigation while running
    if (running) {
        try {
            lbModules.Value := UI_ModuleNameToIndex(UI_ACTIVE_MODULE)
        } catch {
        }
        return
    }

    name := ""
    try {
        name := lbModules.Text
    } catch {
        name := ""
    }
    if (name = "")
        return

    UI_ShowModule(name)
}

UI_ModuleNameToIndex(name) {
    items := ["Scale", "ROIs", "Anchors", "History", "Settings"]
    for i, t in items {
        if (t = name)
            return i
    }
    return 1
}

UI_ShowModule(name) {
    global UI_MODULES, UI_ACTIVE_MODULE, lbModules

    for k, arr in UI_MODULES {
        show := (k = name)
        for _, ctrl in arr {
            try {
                ctrl.Visible := show
            } catch {
            }
        }
    }

    UI_ACTIVE_MODULE := name

    try {
        lbModules.Value := UI_ModuleNameToIndex(name)
    } catch {
    }
}

UI_OnMainGuiSize(guiObj, minMax, width, height) {
    global UI_PAD, UI_HEADER_H, UI_LEFT_W, UI_ACTION_H
    global stTitle, stSub, lbModules
    global gbScale, gbRois, gbAnchors, gbHistory, gbSettings
    global gbActions, btnRunMain, btnStopMain, btnResetMain, stStateDot, stStateText, stStatus

    if (minMax = -1) ; minimized
        return

    pad := UI_PAD

    ; Header
    try stTitle.Move(pad, pad, width - 2*pad, 24)
    try stSub.Move(pad, pad + 26, width - 2*pad, 20)

    leftX := pad
    leftY := UI_HEADER_H

    actionY := height - UI_ACTION_H - pad
    leftH := actionY - leftY - pad
    if (leftH < 120)
        leftH := 120

    try lbModules.Move(leftX, leftY, UI_LEFT_W, leftH)

    rightX := leftX + UI_LEFT_W + pad
    rightY := leftY
    rightW := width - rightX - pad
    rightH := leftH
    if (rightW < 420)
        rightW := 420

    ; Resize module containers (children remain at fixed positions for safety)
    for _, gb in [gbScale, gbRois, gbAnchors, gbHistory, gbSettings] {
        try gb.Move(rightX, rightY, rightW, rightH)
    }

    ; Action bar
    try gbActions.Move(pad, actionY, width - 2*pad, UI_ACTION_H)

    bx := pad + 18
    by := actionY + 30

    try btnRunMain.Move(bx, by, 120, 36)
    try btnStopMain.Move(bx + 130, by, 120, 36)
    try btnResetMain.Move(bx + 260, by, 120, 36)
    try stStateDot.Move(bx + 410, by, 18, 28)
    try stStateText.Move(bx + 434, by + 2, 140, 28)
    try stStatus.Move(pad + 18, by + 40, width - (pad + 18) * 2, 22)
}

UI_UpdateStateBadge() {
    global stStateDot, stStateText
    global running, g_F4_IsBusy, F4_QUEUED
    global parentL, parentT, parentR, parentB

    mode := "READY"

    if (running) {
        mode := "RUN"
    } else if (g_F4_IsBusy || F4_QUEUED) {
        mode := "LEARN"
    } else {
        hwnd := 0
        if !PreflightStateOK(&hwnd) {
        __DECIDE_Log("PreflightStateOK", Map("ok", 0))
            mode := "IDLE"
        } else {
            hasParent := (parentR > parentL) && (parentB > parentT)
            mode := hasParent ? "READY" : "READY*"
        }
    }

    try {
        stStateText.Text := mode
    } catch {
    }

    ; Simple color mapping (UI-only)
    try {
        if (mode = "RUN") {
            stStateDot.SetFont("cDAA520") ; goldenrod
        } else if (mode = "LEARN") {
            stStateDot.SetFont("c1E90FF") ; dodgerblue
        } else if (InStr(mode, "READY")) {
            stStateDot.SetFont("c2E8B57") ; seagreen
        } else {
            stStateDot.SetFont("c808080") ; gray
        }
    } catch {
    }
}


UI_ApplyEnablePolicy(force := false) {
    global running, busy, g_F4_IsBusy, F4_QUEUED
    global lbModules, btnRunMain, btnStopMain, btnResetMain
    global UI_MODULES
    global parentL, parentT, parentR, parentB
    global F3_ROI_LIST, DIA_LIST, SCA_LIST

    ; Optional UI controls (only exist in this GUI build)
    global btnParentShow
    global cbF3Rois, btnF3Preview, btnF3Run, btnF3Borders
    global btnDiaUpd, btnDiaDel, btnScaUpd, btnScaDel

    ; ------------------------------------------------------------------
    ; Compute app mode (UI-only)
    ; ------------------------------------------------------------------
    learnBusy := false
    try {
        learnBusy := (g_F4_IsBusy || F4_QUEUED || busy)
    } catch {
        learnBusy := (busy ? true : false)
    }

    canEdit := !(running || learnBusy)

    hasParent := false
    try {
        hasParent := (parentR > parentL) && (parentB > parentT)
    } catch {
        hasParent := false
    }

    hasRois := false
    try {
        hasRois := (IsObject(F3_ROI_LIST) && F3_ROI_LIST.Length > 0)
    } catch {
        hasRois := false
    }

    diaHas := false
    try {
        diaHas := (IsObject(DIA_LIST) && DIA_LIST.Length > 0)
    } catch {
        diaHas := false
    }

    scaHas := false
    try {
        scaHas := (IsObject(SCA_LIST) && SCA_LIST.Length > 0)
    } catch {
        scaHas := false
    }

    canRun := false
    try {
        hwnd := 0
        canRun := (canEdit && PreflightStateOK(&hwnd))
    } catch {
        canRun := canEdit
    }

    ; ------------------------------------------------------------------
    ; Throttle: only repaint enable-state when key changes (UI-only)
    ; ------------------------------------------------------------------
    global UI_LAST_POLICY_KEY
    key := (running ? "1" : "0") "|" (learnBusy ? "1" : "0") "|" (canRun ? "1" : "0") "|" (hasParent ? "1" : "0") "|" (hasRois ? "1" : "0") "|" (diaHas ? "1" : "0") "|" (scaHas ? "1" : "0")

    if (!force) {
        try {
            if (UI_LAST_POLICY_KEY = key)
                return
        } catch {
        }
    }
    UI_LAST_POLICY_KEY := key

    ; ------------------------------------------------------------------
    ; Global enable policy
    ; ------------------------------------------------------------------
    try {
        lbModules.Enabled := canEdit
    } catch {
    }

    try {
        btnRunMain.Enabled := canRun
    } catch {
    }
    try {
        btnStopMain.Enabled := running
    } catch {
    }
    try {
        btnResetMain.Enabled := canEdit
    } catch {
    }

    ; Disable all module controls while RUN/LEARN/busy (prevents accidental edits)
    for _, arr in UI_MODULES {
        for _, c in arr {
            try c.Enabled := canEdit
        }
    }

    ; ------------------------------------------------------------------
    ; Fine-grained gating (only when editable)
    ; ------------------------------------------------------------------
    if (canEdit) {
        ; Parent-dependent
        try btnParentShow.Enabled := hasParent

        ; ROIs-dependent
        try cbF3Rois.Enabled := hasRois
        try btnF3Preview.Enabled := hasRois
        try btnF3Run.Enabled := hasRois
        try btnF3Borders.Enabled := hasRois

        ; Anchors-dependent
        try btnDiaUpd.Enabled := diaHas
        try btnDiaDel.Enabled := diaHas
        try btnScaUpd.Enabled := scaHas
        try btnScaDel.Enabled := scaHas
    }
}



; ----------------------------------------------------------------------------------
; SIMPLE/ADVANCED VIEW TOGGLE (UI-only)
; ----------------------------------------------------------------------------------
UI_OnAutoHideToggle(*) {
    global UI_AUTOHIDE_WHEN_RUN, chkAutoHide
    v := 1
    try v := chkAutoHide.Value
    UI_AUTOHIDE_WHEN_RUN := (v = 1)
    try {
        SetStatus(UI_AUTOHIDE_WHEN_RUN ? "Auto-hide while RUN: ON" : "Auto-hide while RUN: OFF")
    } catch {
    }
}

; ----------------------------------------------------------------------------------
; TEST: Click DIAMOND once (debug helper)
; - Does NOT send "/" and does NOT type A/B
; - Uses the same diamond search pipeline (PRIMARY -> FALLBACK list order)
; ----------------------------------------------------------------------------------
UI_TestDiamondClick(*) {
    
    global __UI_IS_TESTING
    __ENTRY_Log("UI_TestDiamondClick", "BEGIN IsTesting=" __UI_IS_TESTING)
    if (__UI_IS_TESTING) {
        try SetStatus("TEST: Already running.")
        return
    }
global IS_RUNNING, busy
    if (IS_RUNNING) {
        try SetStatus("TEST: Stop RUN first (F1).")
        return
    }
    if (busy) {
        try SetStatus("TEST: Busy, try again.")
        return
    }
    __UI_IS_TESTING := 1
    busy := true
    ; TEST MODE: force behValid=1 (engine-safe)
    global __TEST_FORCE_BEHVALID
    global LEARN_ACTIVE, LEARN_BEH_VALID, LEARN_LOCKED
    old__force := __TEST_FORCE_BEHVALID
    old__learnActive := LEARN_ACTIVE
    old__learnValid := LEARN_BEH_VALID
    old__learnLocked := LEARN_LOCKED
    __TEST_FORCE_BEHVALID := true
    LEARN_BEH_VALID := true
    LEARN_ACTIVE := false
    LEARN_LOCKED := true
    try {
        SaveAllToIni()
        if !PreflightOK() {
            try SetStatus("TEST: Preflight failed (focus CapCut + set parent if needed).")
            return
        }

        ; Bring target window to front so click lands in CapCut.
        try {
            global winCache
            hwnd := winCache.Has("hwnd") ? winCache["hwnd"] : 0
            if (hwnd)
                WinActivate("ahk_id " hwnd)
        } catch {
        }
        Sleep 30

        ok := TestDiamondClickOnce()
        if (ok) {
            try {
                Log("TEST | DIAMOND | click OK", "INFO", "UI")
            } catch {
            }
            try SetStatus("TEST OK: Clicked diamond.")
        } else {
            try {
                Log("TEST | DIAMOND | click FAIL", "WARN", "UI")
            } catch {
            }
            try SetStatus("TEST FAIL: Diamond not found.")
        }
    } finally {
        ; restore forced behavior gate
        try {
            __TEST_FORCE_BEHVALID := old__force
            LEARN_ACTIVE := old__learnActive
            LEARN_BEH_VALID := old__learnValid
            LEARN_LOCKED := old__learnLocked
        } catch {
        }
        busy := false
        __UI_IS_TESTING := 0
        __ENTRY_Log("UI_TestDiamondClick", "END")
    }
}

; Build a list where the selected image (diaSel) is tried first.
BuildPriorityList(imgList, selIdx, &primaryPath) {
    primaryPath := ""
    try {
        if (selIdx >= 1 && selIdx <= imgList.Length) {
            primaryPath := imgList[selIdx]
            out := []
            out.Push(primaryPath)
            for i, p in imgList {
                if (i != selIdx)
                    out.Push(p)
            }
            return out
        }
    } catch {
    }
    return imgList
}

; Internal: find + click diamond once (shared by TEST button)
