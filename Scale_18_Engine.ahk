; ==================================================================================================
;  MODULE 18 — Engine
;  Source lines (original scale.ahk): 8323 – 8770
; ==================================================================================================



ToggleRun() {
    global running
    global IS_RUNNING, IS_STOP_REQUEST
    global PIPE_MODE, PIPE_STATE
    global FAST_CHECK_CNT, STEP_RETRY
    global EVT_LAST_ACTION_TICK, EVT_WAIT_DONE
    global ROI_STATE
    if (running) {
        StopRun()
        return
    }
    if !PreflightOK()
        return
    running := true
    IS_RUNNING := true
    IS_STOP_REQUEST := false

    ; reset điều phối
    PIPE_MODE := "F4"
    PIPE_STATE := "WAIT"
    FAST_CHECK_CNT := 0
    STEP_RETRY := 0
    ROI_STATE := "UNKNOWN"
    EVT_LAST_ACTION_TICK := 0
    EVT_WAIT_DONE := true
    ; GUI policy: khi RUN thì chuyển sang overlay mờ + click-through
    try {
        SetGuiMode("RUN")
    } catch {
    }
    SetStatus("RUNNING... (F1 stop)")
    try {
        UI_UpdateStateBadge()
    } catch {
    }
    try {
        UI_ApplyEnablePolicy(true)
    } catch {
    }

    try {
        UI_SyncState()
    } catch {
    }

    try {
        UI_OnRunStart()
    } catch {
    }

    SetTimer(RunStep, 55)
}


StopRun() {
    global running, busy
    global IS_RUNNING, IS_STOP_REQUEST
    global PIPE_STATE
    running := false
    IS_RUNNING := false
    IS_STOP_REQUEST := false
    PIPE_STATE := "WAIT"
    ; GUI policy: khi STOP thì chuyển về EDIT (rõ nét, nhận chuột)
    try {
        SetGuiMode("EDIT")
    } catch {
    }
    SetTimer(RunStep, 0)
    busy := false
    SetStatus("Stopped.")
    try {
        UI_UpdateStateBadge()
    } catch {
    }
    try {
        UI_ApplyEnablePolicy(true)
    } catch {
    }

    try {
        UI_SyncState()
    } catch {
    }

    try {
        UI_OnRunStop()
    } catch {
    }

}


RunOnce() {
    global busy, stepIndex
    global PIPE_MODE, PIPE_STATE
    global FAST_CHECK_CNT, STEP_RETRY
    if (busy)
        return
    busy := true
    try {
        SaveAllToIni()
        if !PreflightOK()
            return

        PIPE_MODE := "F4"
        PIPE_STATE := "CHECK"
        ok := DoOne(stepIndex)
        if (ok) {
            FAST_CHECK_CNT := 0
            STEP_RETRY := 0
            EVT__MarkAction("cycle", "ANIM")
            stepIndex := NextCycleIndex(stepIndex)
            SetStatus("OK. Next=" GetCycleValue(stepIndex))
        } else {
            FAST_CHECK_CNT += 1
            STEP_RETRY += 1
        }
    } finally {
        busy := false
    }
}


RunStep() {
    global busy, running, stepIndex
    global GLUE_LOCK, IS_STOP_REQUEST
    global PIPE_MODE, PIPE_STATE
    global FAST_MAX_CHECK, FAST_CHECK_CNT
    global STEP_RETRY_MAX, STEP_RETRY
    global ROI_STATE

    if (!running)
        return

    if (IS_STOP_REQUEST) {
        StopRun()
        return
    }

    ; GUI state: sync theo runtime (không block GUI)
    try {
        UI_SyncState()
    } catch {
    }

    ; EVENT-DRIVEN: đang chờ animation/load thì không check
    if (!EVT__ReadyForNextCheck())
        return

    ; chống chạy chồng
    if (busy || GLUE_LOCK)
        return

    GLUE_LOCK := true
    busy := true
    try {
        PIPE_MODE := "F4"
        PIPE_STATE := "CHECK"

        ok := DoOne(stepIndex)
        if (!ok) {
            PIPE_STATE := "DECIDE"
            FAST_CHECK_CNT += 1
            STEP_RETRY += 1
            ROI_STATE := "ERROR"

            ; Chặn loop mù
            if (FAST_CHECK_CNT >= FAST_MAX_CHECK || STEP_RETRY > STEP_RETRY_MAX) {
                StopRun()
                return
            }

            ; retry có chờ (event-driven)
            EVT__MarkAction("retry", "BASE")
            return
        }

        ; OK -> reset retry + chờ UI settle rồi mới vòng tiếp
        FAST_CHECK_CNT := 0
        STEP_RETRY := 0
        ROI_STATE := "READY"
        PIPE_STATE := "ACTION"
        EVT__MarkAction("cycle", "ANIM")
        stepIndex := NextCycleIndex(stepIndex)
        PIPE_STATE := "WAIT"
    } finally {
        busy := false
        GLUE_LOCK := false
    }
}


; =========================================================
; EVENT-DRIVEN WAIT (anti-poll)
; - Sau ACTION → chờ đúng thời lượng rồi mới CHECK tiếp
; - Không loop mù (kết hợp FAST_MAX_CHECK/STEP_RETRY_MAX)
; =========================================================
EVT__MarkAction(actionName := "", waitKind := "BASE") {
    global EVT_LAST_ACTION_TICK, EVT_WAIT_DONE
    global PIPE_LAST_ACTION, PIPE_LAST_TICK
    global ACTION_LAST, ACTION_PENDING, ACTION_DONE
    global ROI_STATE

    global HAS_ACTION_SINCE_PICK
    EVT_LAST_ACTION_TICK := A_TickCount
    EVT_WAIT_DONE := false

    PIPE_LAST_ACTION := actionName
    PIPE_LAST_TICK := EVT_LAST_ACTION_TICK

    ACTION_LAST := actionName
    ACTION_PENDING := false
    ACTION_DONE := true

    ; ACTION gate: chỉ tính là "có action" khi không phải retry/wait thuần
    if (actionName != "" && actionName != "retry")
        HAS_ACTION_SINCE_PICK := true

    ; Auto-learning window: chỉ bật learning sau ACTION thật (chống học vô hạn khi F4 idle)
    global LEARN_ACTIVE, LEARN_START_TICK, LEARN_MAX_MS
    global LEARN_LOOP_CNT, LEARN_LOOP_MAX
    global LEARN_BEH_VALID, LEARN_LOCKED, LEARN_ABORT
    global LEARN_TRIGGER_ACTION, LEARN_LAST_ACTION_TICK

    LEARN_ACTIVE := true
    LEARN_START_TICK := A_TickCount
    LEARN_LOOP_CNT := 0
    LEARN_ABORT := false
    LEARN_BEH_VALID := false
    LEARN_LOCKED := false
    LEARN_TRIGGER_ACTION := actionName
    LEARN_LAST_ACTION_TICK := LEARN_START_TICK


    ; Khi vừa ACTION → UI thường đang đổi trạng thái
    if (ROI_STATE != "ERROR")
        ROI_STATE := "LOADING"
}


EVT__ReadyForNextCheck() {
    global EVT_LAST_ACTION_TICK, EVT_WAIT_DONE
    global EVT_WAIT_BASE_MS, EVT_WAIT_ANIM_MS
    global PIPE_LAST_ACTION, PIPE_STATE
    global ROI_STATE

    if (EVT_WAIT_DONE)
        return true

    ; nếu chưa từng đánh dấu action, coi như ready
    if (EVT_LAST_ACTION_TICK = 0) {
        EVT_WAIT_DONE := true
        return true
    }

    need := EVT_WAIT_BASE_MS
    if (PIPE_LAST_ACTION = "cycle")
        need := EVT_WAIT_ANIM_MS

    elapsed := A_TickCount - EVT_LAST_ACTION_TICK
    if (elapsed >= need) {
        EVT_WAIT_DONE := true
        if (ROI_STATE != "ERROR")
            ROI_STATE := "READY"
        return true
    }

    PIPE_STATE := "WAIT"
    if (ROI_STATE != "ERROR")
        ROI_STATE := "LOADING"
    return false
}


PreflightOK() {
    global runnerL, runnerT, runnerR, runnerB
    global parentL, parentT, parentR, parentB
    global DBG_F3_DIM_TOOLTIP

    ; DECIDE TRACE (state + regions)
    try {
        hasRunner := (runnerR > runnerL) && (runnerB > runnerT)
        hasParent := (parentR > parentL) && (parentB > parentT)
        __DECIDE_Log("PreflightOK", "hasRunner=" (hasRunner?1:0) " hasParent=" (hasParent?1:0) " targetExe=" targetExe " targetTitle=" targetTitle)
    } catch {
    }


    hwnd := 0
    if !PreflightStateOK(&hwnd) {
        SetStatus("ERROR: Target window not active / wrong state.")
        return false
    }
    ; invalidate caches if window changed
    UpdateWinCacheAndInvalidate(hwnd)
    __DECIDE_Log("PreflightOK.window", Map("hwnd", hwnd))

    ; DO NOT hard-require [runner]. If missing, we can search in Parent (F3) or active window.
    hasRunner := (runnerR > runnerL) && (runnerB > runnerT)
    hasParent := (parentR > parentL) && (parentB > parentT)
    __DECIDE_Log("PreflightOK.regions", Map("hasRunner", hasRunner?1:0, "hasParent", hasParent?1:0))
    if (!hasRunner && !hasParent) {
        ; Soft warning only.
        SetStatus("WARN: No child region ([runner]) and no Parent (F3). Will search inside active window (slower).")
    }
    return true
}


; =========================================================
; State-aware preflight (optional)
; =========================================================
PreflightStateOK(&outHwnd) {
    global targetExe, targetTitle
    outHwnd := 0

    if (targetExe != "") {
        h := WinActive("ahk_exe " targetExe)
        if (!h)
            return false
        outHwnd := h
        return true
    }

    if (targetTitle != "") {
        h := WinActive(targetTitle)
        if (!h)
            return false
        outHwnd := h
        return true
    }

    ; default: any active window
    h := WinActive("A")
    if (!h)
        return false
    outHwnd := h
    return true
}


UpdateWinCacheAndInvalidate(hwnd) {
    global winCache, lastDia, lastSca, diaPack, scaPack, baseWinW, baseWinH, CFG_FILE
    x := 0
    y := 0
    w := 0
    h := 0
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch {
        return
    }

    changed := false
    if (winCache["hwnd"] != hwnd)
        changed := true
    if (Abs(x - winCache["x"]) > 2 || Abs(y - winCache["y"]) > 2)
        changed := true
    if (Abs(w - winCache["w"]) > 2 || Abs(h - winCache["h"]) > 2)
        changed := true

    ; set base window size once (for relative offsets)
    if (baseWinW <= 0 || baseWinH <= 0) {
        baseWinW := w
        baseWinH := h
        IniWriteSafe(baseWinW, CFG_FILE, "auto", "baseWinW")
        IniWriteSafe(baseWinH, CFG_FILE, "auto", "baseWinH")
    }

    if (changed) {
        lastDia["x"] := ""
        lastDia["y"] := ""
        lastSca["x"] := ""
        lastSca["y"] := ""
        diaPack := MakeEmptyAnchorPack()
        scaPack := MakeEmptyAnchorPack()
    }

    winCache["hwnd"] := hwnd
    winCache["x"] := x
    winCache["y"] := y
    winCache["w"] := w
    winCache["h"] := h
}


ClipRegionToWin(region, winRect) {
    L := Max(region["L"], winRect["L"])
    T := Max(region["T"], winRect["T"])
    R := Min(region["R"], winRect["R"])
    B := Min(region["B"], winRect["B"])
    if (R <= L || B <= T)
        return Map("L", region["L"], "T", region["T"], "R", region["R"], "B", region["B"])
    return Map("L", L, "T", T, "R", R, "B", B)
}



; =========================================================
; Region helpers (inflate + diamond outline fallback)
; =========================================================
InflateRegion(region, pad := 6) {
    ; Accept Map or Rect-like object with L/T/R/B
    try {
        L := region.HasProp("L") ? region.L : region["L"]
        T := region.HasProp("T") ? region.T : region["T"]
        R := region.HasProp("R") ? region.R : region["R"]
        B := region.HasProp("B") ? region.B : region["B"]
    } catch {
        ; last-resort: assume Map keys exist
        L := region["L"], T := region["T"], R := region["R"], B := region["B"]
    }
    return Map("L", L - pad, "T", T - pad, "R", R + pad, "B", B + pad)
}

AL__IsBrightRGB(col, thr := 210) {
    local r, g, b
    r := (col >> 16) & 0xFF
    g := (col >> 8) & 0xFF
    b := col & 0xFF
    return (r >= thr && g >= thr && b >= thr)
}

AL__HasBrightNear(rgb, wCells, hCells, x0, y0, thr := 210, radius := 1) {
    Loop (radius*2 + 1) {
        dy := A_Index - (radius + 1)
        ny := y0 + dy
        if (ny < 0 || ny >= hCells)
            continue
        Loop (radius*2 + 1) {
            dx := A_Index - (radius + 1)
            nx := x0 + dx
            if (nx < 0 || nx >= wCells)
                continue
            idx := ny*wCells + nx + 1
            try {
                if (AL__IsBrightRGB(rgb[idx], thr))
                    return true
            } catch {
            }
        }
    }
    return false
}

