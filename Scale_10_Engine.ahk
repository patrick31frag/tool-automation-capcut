; ==================================================================================================
;  MODULE 10 — Engine
;  Source lines (original scale.ahk): 4355 – 4902
; ==================================================================================================
TestDiamondClickOnce() {

    __TEST_DiagReset()
    __DECIDE_Log("TestDiamondClickOnce.begin")
    global DIA_LIST, diaSel
    global runnerL, runnerT, runnerR, runnerB
    global parentL, parentT, parentR, parentB
    global clickOffsetX, clickOffsetY
    global diamondClickMode
    global cacheBox, lastDia, diaPack
    global winCache

    if (DIA_LIST.Length < 1) {
        __TEST_DiagSet("DIA_LIST_EMPTY")
        return false
    }

    hwnd := winCache.Has("hwnd") ? winCache["hwnd"] : 0
    if (!hwnd) {
        __TEST_DiagSet("NO_HWND")
        return false
    }

    winRect := GetWinRect(hwnd)
    if (!IsObject(winRect)) {
        __TEST_DiagSet("WINRECT_FAIL")
        return false
    }

    ; Tier0 parent region (coarse). If not set, use full window.
    hasParent := (parentR > parentL) && (parentB > parentT)
    parentReg := Map("L", parentL, "T", parentT, "R", parentR, "B", parentB)
    if (hasParent) {
        parentReg := ClipRegionToWin(parentReg, winRect)
    } else {
        parentReg := Map("L", winRect["L"], "T", winRect["T"], "R", winRect["R"], "B", winRect["B"])
    }

    ; Tier1 runner region if available, else tier0 parent.
    if ((runnerR > runnerL) && (runnerB > runnerT)) {
        fullRunner := Map("L", runnerL, "T", runnerT, "R", runnerR, "B", runnerB)
        fullRunner := ClipRegionToWin(fullRunner, winRect)
    } else {
        fullRunner := parentReg
    }

    ; Safety margin for thin-outline diamond
    ; DECIDE regions
    __DECIDE_Log("TestDiamondClickOnce", "hasParent=" (hasParent?1:0) " hasRunner=" (((runnerR>runnerL)&&(runnerB>runnerT))?1:0))
    diaPad := 6
    try {
        fullRunner := InflateRegion(fullRunner, diaPad)
        fullRunner := ClipRegionToWin(fullRunner, winRect)
    } catch {
    }

    ; Priority list: selected first (PRIMARY), then the rest as FALLBACK.
    diaListUse := BuildPriorityList(DIA_LIST, diaSel, &primaryDiaPath)

    dx := ""
    dy := ""
    found := false
    foundBy := ""

    __DECIDE_Log("TestDiamondClickOnce.regions", Map("parent", hasParent?1:0, "runner", ((runnerR>runnerL)&&(runnerB>runnerT))?1:0, "fullRunner", fullRunner["L"] "," fullRunner["T"] "," fullRunner["R"] "," fullRunner["B"]))

    ; Cached -> fullRunner
    dReg := MakeCachedRegion(lastDia, fullRunner, cacheBox)
    __DECIDE_Log("TestDiamondClickOnce.find", Map("stage","cache", "L", dReg["L"], "T", dReg["T"], "R", dReg["R"], "B", dReg["B"]))
    found := FindBestMatch(diaListUse, dReg, diaPack, &dx, &dy)
    if (found)
        foundBy := "CACHE"
    if (!found) {
        __DECIDE_Log("TestDiamondClickOnce.find", Map("stage","runner", "L", fullRunner["L"], "T", fullRunner["T"], "R", fullRunner["R"], "B", fullRunner["B"]))
        found := FindBestMatch(diaListUse, fullRunner, diaPack, &dx, &dy)
        if (found)
            foundBy := "RUNNER"
    }

    ; Fallback to parent region if different
    if (!found && hasParent) {
        try {
            if (fullRunner["L"] != parentReg["L"] || fullRunner["T"] != parentReg["T"] || fullRunner["R"] != parentReg["R"] || fullRunner["B"] != parentReg["B"]) {
                dReg2 := MakeCachedRegion(lastDia, parentReg, cacheBox)
                __DECIDE_Log("TestDiamondClickOnce.find", Map("stage","parent_cache", "L", dReg2["L"], "T", dReg2["T"], "R", dReg2["R"], "B", dReg2["B"]))
                found := FindBestMatch(diaListUse, dReg2, diaPack, &dx, &dy)
                if (found)
                    foundBy := "PARENT_CACHE"
                if (!found) {
                    __DECIDE_Log("TestDiamondClickOnce.find", Map("stage","parent", "L", parentReg["L"], "T", parentReg["T"], "R", parentReg["R"], "B", parentReg["B"]))
                    found := FindBestMatch(diaListUse, parentReg, diaPack, &dx, &dy)
                    if (found)
                        foundBy := "PARENT"
                }
            }
        } catch {
        }
    }

    ; Last-resort fallback: bright-outline detector (handles weird scaling)
    if (!found) {
        fbOk := false
        __DECIDE_Log("TestDiamondClickOnce.find", Map("stage","AL_BRIGHT"))
        try fbOk := AL_FindDiamondOutlineBright(fullRunner, winRect, &dx, &dy, 0, 210)
        if (fbOk) {
            found := true
            foundBy := "AL_BRIGHT"
        }
    }

    if (!found) {
        __TEST_DiagSet("NOT_FOUND")
        return false
    }

    try {
        lastDia["x"] := dx
        lastDia["y"] := dy
    } catch {
    }

    __TEST_DiagSet("FOUND", Map("dx", dx, "dy", dy, "by", foundBy, "clickOffsetX", clickOffsetX, "clickOffsetY", clickOffsetY, "mode", diamondClickMode))

    ; Click once
    try {
        pol := ClickPolicy_Explain("TEST_DIAMOND_CLICK")
        __DECIDE_Log("ClickPolicy", pol)
        MoveCursor(dx + clickOffsetX, dy + clickOffsetY)
        Sleep(Random(8, 18))
        MouseClickLeft(diamondClickMode)
    } catch {
        __TEST_DiagSet("CLICK_EXCEPTION")
        return false
    }
    return true
}


UI_ToggleAdvanced(*) {
    global UI_ADV_VISIBLE
    UI_SetAdvancedVisible(!UI_ADV_VISIBLE)
}

UI_SetAdvancedVisible(show) {
    global g
    global UI_ADV_VISIBLE, UI_W_SIMPLE, UI_H_SIMPLE, UI_W_ADV, UI_H_ADV
    global stTitle, stSub, gbMain, stHow, btnSave
    global gbAdv, tabAdv, btnAdvanced
    global gbActions, btnRunMain, btnStopMain, btnResetMain, stStateDot, stStateText, stStatus

    UI_ADV_VISIBLE := show ? true : false

    W := UI_ADV_VISIBLE ? UI_W_ADV : UI_W_SIMPLE
    H := UI_ADV_VISIBLE ? UI_H_ADV : UI_H_SIMPLE

    pad := 12
    mainW := W - 2*pad

    ; Resize main window (no activate)
    try g.Show("w" W " h" H " NA")

    ; Header width
    try stTitle.Move(pad, 10, W - 2*pad, 26)
    try stSub.Move(pad, 38, W - 2*pad, 20)

    ; Main panel width
    try gbMain.Move(pad, 56, mainW, 128)
    try stHow.Move(pad, 196, mainW, stHow.Pos.H)

    ; Save button stays inside main panel region
    try btnSave.Move(28, 150, 120, 30)

    ; Advanced panel
    if (UI_ADV_VISIBLE) {
        try btnAdvanced.Text := "Advanced ▲"
        try btnResetMain.Visible := true

        advX := pad
        advY := 310
        actionH := 76
        statusH := 20
        bottomPad := 10

        actionY := H - actionH - statusH - bottomPad
        if (actionY < advY + 120)
            actionY := advY + 120

        advH := actionY - advY - 8
        if (advH < 220)
            advH := 220

        try gbAdv.Visible := true
        try tabAdv.Visible := true
        try gbAdv.Move(advX, advY, mainW, advH)
        try tabAdv.Move(advX + 12, advY + 26, mainW - 24, advH - 40)
    } else {
        try btnAdvanced.Text := "Advanced ▼"
        try btnResetMain.Visible := false
        try gbAdv.Visible := false
        try tabAdv.Visible := false
    }

    ; Action bar anchored to bottom
    actionH := 76
    gbY := H - actionH - 20 - 10
    if (gbY < 240)
        gbY := 240

    try gbActions.Move(pad, gbY, mainW, actionH)

    bx := 28
    by := gbY + 22
    try btnRunMain.Move(bx, by, 130, 34)
    try btnStopMain.Move(bx + 140, by, 130, 34)
    try btnResetMain.Move(bx + 280, by, 130, 34)

    try stStateDot.Move(bx + 430, by, 18, 28)
    try stStateText.Move(bx + 454, by + 2, 140, 28)

    try stStatus.Move(pad, H - 26, mainW, 20)

    ; Refresh badge/policy after layout changes
    try UI_UpdateStateBadge()
    try UI_ApplyEnablePolicy(true)
}

UI_OnRunStart() {
    global UI_AUTOHIDE_WHEN_RUN, UI_HIDDEN_BY_RUN
    global g
    UI_HIDDEN_BY_RUN := false
    if (!UI_AUTOHIDE_WHEN_RUN)
        return
    try {
        g.Hide()
        UI_HIDDEN_BY_RUN := true
    } catch {
    }
}

UI_OnRunStop() {
    global UI_AUTOHIDE_WHEN_RUN, UI_HIDDEN_BY_RUN
    global g
    if (!UI_AUTOHIDE_WHEN_RUN)
        return
    if (!UI_HIDDEN_BY_RUN)
        return
    try {
        g.Show("NA")
    } catch {
    }
    UI_HIDDEN_BY_RUN := false
}

UI_ResetUiOnly() {
    global running

    if (running) {
        try StopRun()
    }

    ; Reload UI data from INI and repaint lists
    try LoadImageListsFromIni()
    try LoadScansFromIni()
    try LoadParentHistoryFromIni()

    try RefreshDiaCombo()
    try RefreshScaCombo()
    try RefreshF3RoiCombo()
    try RefreshScanCombo()
    try RefreshParentHistCombo()
    try SyncScanChecks()

    try UI_UpdateStateBadge()
    try UI_ApplyEnablePolicy(true)
    try SetStatus("UI reset + INI reloaded.")
}

; ==================================================================================================

; --- NO_WARN: missing helper shims (silence lint + keep behavior) ---
; Some call sites reference these helpers; provide lightweight wrappers here.

F3OverlayMakeKey(it) {
    ; Stable key for ROI item (used by F3_ROI_ORDER map)
    rr := 0
    try {
        rr := it["rectRel"]
    } catch {
        rr := 0
        try {
            if (IsObject(it) && it.Has("cand"))
                rr := it["cand"].rectRel
        } catch {
            rr := 0
        }
    }
    if (!IsObject(rr))
        return ""
    return rr.L "," rr.T "," rr.R "," rr.B
}

F3__RefreshRoiCombo() {
    ; Back-compat shim: some code calls F3__RefreshRoiCombo(), but the real function is RefreshF3RoiCombo().
    global F3_ROI_SELECTED
    try {
        RefreshF3RoiCombo(F3_ROI_SELECTED)
        return
    } catch {
    }
    try {
        RefreshF3RoiCombo(1)
    } catch {
    }
}



; PATCHABLE_ZONE_UI_HELPERS_END
; ==================================================================================================



UI_SetState(state, reason := "", timeoutMs := 0) {
    global UI_STATE, UI_STATE_REASON, UI_STATE_SINCE_TICK, UI_STATE_TIMEOUT_MS
    global UI_HEARTBEAT_ON, UI_HEARTBEAT_MS
    global UI_RUN_SINCE_TICK
    global running
    prev := UI_STATE

    ; nếu đang RUN mà chưa set runStart, set 1 lần
    if (running && UI_RUN_SINCE_TICK = 0)
        UI_RUN_SINCE_TICK := A_TickCount
    if (!running)
        UI_RUN_SINCE_TICK := 0

    ; Nếu state không đổi: chỉ update reason/timeout (không reset since)
    if (state = UI_STATE) {
        if (reason != "" && reason != UI_STATE_REASON)
            UI_STATE_REASON := reason
        if (timeoutMs >= 0 && timeoutMs != UI_STATE_TIMEOUT_MS)
            UI_STATE_TIMEOUT_MS := timeoutMs
        try {
            UI_UpdateGui(false)
        } catch {
        }
        return
    }

    ; Log total time of previous state (để biết state chạy bao lâu)
    if (UI_STATE_SINCE_TICK > 0 && prev != "" && prev != "IDLE") {
        dur := (A_TickCount - UI_STATE_SINCE_TICK)
        try {
            Log("STATE END | " prev " | total=" dur "ms (" Round(dur/1000.0, 2) "s) | reason=" UI_STATE_REASON, "INFO", "UI")
        } catch {
        }
    }

    UI_STATE := state
    UI_STATE_REASON := reason
    UI_STATE_SINCE_TICK := A_TickCount
    UI_STATE_TIMEOUT_MS := timeoutMs

    ; Heartbeat: bật khi WAIT để GUI tự cập nhật elapsed
    wantHb := (UI_STATE = "WAIT")
    if (wantHb && !UI_HEARTBEAT_ON) {
        UI_HEARTBEAT_ON := true
        SetTimer(UI__Heartbeat, UI_HEARTBEAT_MS)
    } else if (!wantHb && UI_HEARTBEAT_ON) {
        UI_HEARTBEAT_ON := false
        SetTimer(UI__Heartbeat, 0)
    }

    try {
        UI_UpdateGui(true)
    } catch {
    }
}

UI_CheckTimeout() {
    global UI_STATE, UI_STATE_SINCE_TICK, UI_STATE_TIMEOUT_MS
    global UI_WAIT_FALLBACK_TIMEOUT_MS
    global IS_STOP_REQUEST

    if (UI_STATE != "WAIT")
        return

    now := A_TickCount
    elapsed := now - UI_STATE_SINCE_TICK

    timeout := UI_STATE_TIMEOUT_MS
    if (timeout <= 0)
        timeout := UI_WAIT_FALLBACK_TIMEOUT_MS

    if (timeout > 0 && elapsed >= timeout) {
        try {
            Log("STATE TIMEOUT | WAIT | elapsed=" elapsed "ms timeout=" timeout "ms", "WARN", "UI")
        } catch {
        }
        IS_STOP_REQUEST := true
        UI_SetState("TIMEOUT", "WAIT timeout", 0)
    }
}

UI_SyncState() {
    global running, IS_STOP_REQUEST
    global PIPE_STATE, ROI_STATE
    global EVT_WAIT_DONE, EVT_LAST_ACTION_TICK, EVT_WAIT_BASE_MS, EVT_WAIT_ANIM_MS
    global PIPE_LAST_ACTION
    global LEARN_ACTIVE, LEARN_BEH_VALID, LEARN_START_TICK, LEARN_MAX_MS

    if (!running) {
        UI_SetState("IDLE", "", 0)
        return
    }

    if (IS_STOP_REQUEST) {
        UI_SetState("STOP", "stop requested", 0)
        return
    }

    ; 1) Event-driven wait (sau action/anim)
    if (!EVT_WAIT_DONE) {
        need := EVT_WAIT_BASE_MS
        if (PIPE_LAST_ACTION = "cycle")
            need := EVT_WAIT_ANIM_MS
        UI_SetState("WAIT", "evtwait", need)
        return
    }

    ; 2) Learning wait (behValid=0)
    if (LEARN_ACTIVE && !LEARN_BEH_VALID) {
        UI_SetState("WAIT", "behValid=0", LEARN_MAX_MS)
        return
    }

    ; 3) Normal states
    reason := ""
    if (ROI_STATE != "")
        reason := "roi=" ROI_STATE

    UI_SetState(PIPE_STATE, reason, 0)
}

SafeCtrlValue(ctrl) {
    v := 0
    try {
        v := ctrl.Value
    } catch {
        v := 0
    }
    return v
}

ClearComboItems(ctrl) {
    ; Robust clear for ComboBox/DropDownList.
    ; We avoid CB_RESETCONTENT here because it can be unreliable for some setups.
    static CB_GETCOUNT := 0x0146
    static CB_DELETESTRING := 0x0144
    static CB_SETCURSEL := 0x014E

    hwnd := 0
    try {
        hwnd := ctrl.Hwnd
    } catch {
        return
    }

    try {
        cnt := SC_DllCall("user32.dll\SendMessageW", "ptr", hwnd, "uint", CB_GETCOUNT, "ptr", 0, "ptr", 0, "ptr")
        if (cnt <= 0)
            return

        ; Delete from end -> start to avoid index shifting.
        Loop cnt {
            idx := cnt - A_Index
            SC_DllCall("user32.dll\SendMessageW", "ptr", hwnd, "uint", CB_DELETESTRING, "ptr", idx, "ptr", 0, "ptr")
        }
        ; Clear selection.
        SC_DllCall("user32.dll\SendMessageW", "ptr", hwnd, "uint", CB_SETCURSEL, "ptr", -1, "ptr", 0, "ptr")
        return
    } catch {
    }

    ; Last-resort fallback.
    try {
        ctrl.Delete()
    } catch {
    }
}


Border_SetTopMost(hwnd) {
    ; Bring a topmost GUI to the front of the TOPMOST stack (no activate).
    ; Fix: border/labels hidden behind main +AlwaysOnTop GUI.
    static SWP_NOSIZE := 0x0001
    static SWP_NOMOVE := 0x0002
    static SWP_NOACTIVATE := 0x0010
    static SWP_SHOWWINDOW := 0x0040
    static HWND_TOPMOST := -1
    try {
        DllCall("user32.dll\SetWindowPos", "ptr", hwnd, "ptr", HWND_TOPMOST
            , "int", 0, "int", 0, "int", 0, "int", 0
            , "uint", SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE|SWP_SHOWWINDOW)
    } catch {
; ---------------- AI_SAFEZONE100:BORDER_MODULE_BEGIN -----------------
; Border/Overlay/OrderInputs. Do NOT destroy OrderInputs except on true Toggle OFF.
; ---------------------------------------------------------------------
    }
}




Border_BringOrderInputsToTop() {
    global BORDER_ORDERINPUTS
    try {
        for _, og in BORDER_ORDERINPUTS {
            try {
                if (IsObject(og) && og.Has("gui") && IsObject(og["gui"]))
                    Border_SetTopMost(og["gui"].Hwnd)
            } catch {
            }
        }
    } catch {
    }
}

MakeLineGui() {
    lineGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
    lineGui.BackColor := "FF0000"
    lineGui.Show("NA x0 y0 w1 h1")
    try {
        Border_SetTopMost(lineGui.Hwnd)
    } catch {
    }
    try {
        WinSetTransparent(180, "ahk_id " lineGui.Hwnd)
    } catch {
    }
    return lineGui
}


ShowRectOverlay(L, T, R, B, ms := 1200) {
    ShowBorderInit()
    UpdateBorderRect(L, T, R, B)
    SetTimer(HideBorder, -Abs(ms))
}
