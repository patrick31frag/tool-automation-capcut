; ==================================================================================================
;  MODULE 25 — Logger
;  Source lines (original scale.ahk): 11722 – 12202
; ==================================================================================================
AL_F4_RunFast(doClick := true) {
    global AL_FAST_MODE, CAP_FAST_MODE, RUN_HIDE_GUI, CAP_HIDE_GUI, g

    ; F4 FAST MODE: ROI-only (no full parent capture)
    AL_FAST_MODE := true
    CAP_FAST_MODE := true
    CAP_HIDE_GUI := false


    ; F4 press: reset debug-save throttle để MỖI LẦN BẤM F4 đều có ảnh mới theo thứ tự (không ghi đè)
    global g_F4_Index, g_F4_IsBusy, DBG_LAST_TPL_PATH, DBG_SAVE_CNT
    if (g_F4_IsBusy)
        return 0
    g_F4_IsBusy := true
    try {
        UI_UpdateStateBadge()
        UI_ApplyEnablePolicy(true)
    } catch {
    }

    try {
        F4__InitIndexOnce()
    } catch {
    }
    g_F4_Index += 1
    DBG_SAVE_CNT := 0
    DBG_LAST_TPL_PATH := ""
    ; GUI policy: KHÔNG hide. Nếu cần tránh đè chuột → dùng GUI_MODE="RUN" (click-through).
    if (CAP_HIDE_GUI) {
        try {
            if (IsObject(g))
                g.Hide()
        } catch {
        }
    }

    try {
        ret := AL_F4_AutoLearn(doClick)
    } catch {
        ; restore flags/UI
        if (CAP_HIDE_GUI) {
            try {
                if (IsObject(g))
                    g.Show()
            } catch {
            }
        }
        CAP_HIDE_GUI := false
        CAP_FAST_MODE := false
        AL_FAST_MODE := false
        throw
    }

    ; restore flags/UI
    if (CAP_HIDE_GUI) {
        try {
            if (IsObject(g))
                g.Show()
        } catch {
        }
    }
    CAP_HIDE_GUI := false
    CAP_FAST_MODE := false
    AL_FAST_MODE := false
    return ret
}


; =========================================================
; F4 QUEUE (SetTimer one-shot) – YIELD UI thread before heavy work
; - Tránh cảm giác "GUI đứng hình" ngay lúc bấm F4
; - Không đổi thuật toán AL/CAP, chỉ đổi cách gọi (scheduler)
; =========================================================
F4_Queue(doClick := true) {
    global busy, running, F4_QUEUED
    ; tránh chồng chéo với RUN mode (F1 ToggleRun)
    if (running)
        return
    if (busy)
        return
    if (F4_QUEUED)
        return

    F4_QUEUED := true
    try {
        UI_UpdateStateBadge()
        UI_ApplyEnablePolicy(true)
    } catch {
    }

    try {
        ; đổi trạng thái sớm để GUI kịp repaint trước khi chạy nặng
        SetStatus("F4 queued...")
    } catch {
    }

    ; one-shot timer: chạy sau khi message loop có cơ hội repaint
    ; NOTE: Lỗi "Missing )" thường xảy ra khi bạn vô tình viết kiểu: SetTimer(() => Func(){...}) (nhét { } vào trong SetTimer).
    ;       ĐÚNG: dùng Bind() hoặc closure gọn, ví dụ: SetTimer(F4__Do.Bind(true), -1)
    SetTimer(F4__Do.Bind(true), -1)
}

; ---------------------------------------------------------
; F4 one-shot runner (tách ra để tránh lỗi ngoặc/brace)
; ---------------------------------------------------------
F4__Do(doClick := true) {
    global F4_QUEUED, g_F4_IsBusy
    F4_QUEUED := false
    try {
        UI_UpdateStateBadge()
        UI_ApplyEnablePolicy(true)
    } catch {
    }

    ; gọi lại logic cũ
    try {
        AL_F4_RunFast(doClick)
    } finally {
        ; đảm bảo không kẹt busy flag nếu có lỗi
        try {
            g_F4_IsBusy := false
            try {
                UI_UpdateStateBadge()
                UI_ApplyEnablePolicy(true)
            } catch {
            }

        } catch {
        }
    }
}




;
; =========================================================
; PIPE STATE (F4 / MATCH):
;   INPUT_ACQUIRE(FAST: SCREEN ROI-only) → SEGMENTING → FILTERING → MATCHING → DECISION → ACTION
; Ghi chú:
; - F4 là "chạy kịch bản": chỉ so khớp ROI đã định nghĩa theo thứ tự.
; - FAST MODE: tránh PrintWindow/DXGI, tránh full rect; ưu tiên ROI pixel thật.
; =========================================================
AL_F4_AutoLearn(doClick := true) {
    global busy, parentL, parentT, parentR, parentB, parentHwnd, g, AL_LAST, AL_FAST_MODE
    if (busy) {
        try {
            SetStatus("AutoLearn: busy.")
        } catch {
        }
        return
    }

    busy := true
    try {
        if (!(parentR > parentL && parentB > parentT)) {
            SetStatus("AutoLearn: Set parent region first (F3).")
            return
        }

        ; Build ParentContext from current parent rect (screen coords)
        pRect := Rect(parentL, parentT, parentR, parentB)
        pCtx  := ParentContext(pRect, "", Map("hwnd", parentHwnd))


        try {
            Log("AL START | rect=" pRect.L "," pRect.T "," pRect.R "," pRect.B, "DEBUG", "AL")
        } catch {
        }
        opts := AL_DefaultOpts()

        ; ===============================
        ; MULTI-ICON (F3 parent has 2+ icons → save 2+ templates)
        ; ===============================
        ; Khuyên nhủ: Nếu bạn thấy "có 2 icon mà chỉ ra 1 ảnh", 90% là do:
        ;   - minCells/minW/minH quá cao → drop icon nhỏ
        ;   - dilate > 0 → 2 icon dính thành 1 blob
        ;   - NMS IoU quá thấp → loại ROI overlap
        global F3_MULTI_ICON, AL_MULTI_MIN_W, AL_MULTI_MIN_H, AL_MULTI_MIN_CELLS, AL_MULTI_DILATE, AL_MULTI_DISABLE_NMS, AL_MULTI_RELAX_L3, AL_MULTI_H_TRANS_MAX, AL_MULTI_ALLOW_TEXTSTRIP
        multiIcon := false
        try {
            multiIcon := (F3_MULTI_ICON ? true : false)
        } catch {
            multiIcon := false
        }

        if (multiIcon) {
            try {
                opts["minW"] := Min(opts["minW"], AL_MULTI_MIN_W)
                opts["minH"] := Min(opts["minH"], AL_MULTI_MIN_H)
                opts["minCells"] := Min(opts["minCells"], AL_MULTI_MIN_CELLS)
                opts["dilate"] := AL_MULTI_DILATE
                if (AL_MULTI_DISABLE_NMS)
                    opts["nmsIou"] := 0.99
                ; L3 relax for multi-icon:
                ; Nếu log báo "REJECT hTrans" hoặc "REJECT textstrip" → bật relax để không rớt hết candidates.
                if (AL_MULTI_RELAX_L3) {
                    opts["textTransHigh"] := Max(opts["textTransHigh"], AL_MULTI_H_TRANS_MAX)
                    opts["allowTextStrip"] := (AL_MULTI_ALLOW_TEXTSTRIP ? true : false)
                }
                Log("AL | MULTI-ICON ON | minCells<=" opts["minCells"] " minW<=" opts["minW"] " minH<=" opts["minH"] " dilate=" opts["dilate"] " nmsIou=" opts["nmsIou"], "DEBUG", "AL")
            } catch {
            }
        }

        if (AL_FAST_MODE) {
            ; FAST MODE (F4): reduce scan cost (no full pixel scan).
            ; Lưu ý: Multi-icon mode KHÔNG ép minCells>=6, vì sẽ drop icon nhỏ.
            opts["stride"] := Max(opts["stride"], 2)
            if (!multiIcon)
                opts["minCells"] := Max(opts["minCells"], 6)
            try {
                Log("AL | FAST MODE | stride>=" opts["stride"] " minCells>=" opts["minCells"] " (ROI-only)", "DEBUG", "AL")
            } catch {
            }
        }

        ; Dynamic stride to cap sampling cost on large parents
        w := pRect.W
        h := pRect.H
        maxSamples := 15000
        stride := opts["stride"]
        try {
            area := w*h
            if (area > 0) {
                s := Ceil(Sqrt(area / maxSamples))
                if (s < stride)
                    s := stride
                if (s > 18)
                    s := 18
                opts["stride"] := s
            }
        } catch {
        }

        try {
            Log("AL OPTS | stride=" opts["stride"] " edgeThr=" opts["edgeThresh"] " varThr=" opts["varThresh"]
                " minCells=" opts["minCells"] " minW=" opts["minW"] " minH=" opts["minH"] " dilate=" opts["dilate"]
                " ratio=" opts["ratioMin"] "-" opts["ratioMax"]
                " bgContrastMin=" opts["bgContrastMin"] " minScore=" opts["minScore"], "DEBUG", "AL")
        } catch {
        }


        SetStatus("AutoLearn: segmenting...")
        cands := AL_L2_Segment(pCtx, opts)


        try {
            Log("AL L2 | cands=" (IsObject(cands) ? cands.Length : -1), "DEBUG", "AL")
        } catch {
        }
        SetStatus("AutoLearn: filtering...")
        filt  := AL_L3_Filter(pCtx, cands, opts)

        ; Apply ROI order + push list to GUI (multi-icon)
        try {
            filt := F3__ApplyOrderFromF4(pRect, filt)
            Log("AL | ORDER | mode=" F3_SORT_MODE " final=" (IsObject(filt) ? filt.Length : -1), "DEBUG", "AL")
        } catch {
        }


        try {
            Log("AL RESULT | final=" (IsObject(filt) ? filt.Length : -1), "DEBUG", "AL")
        } catch {
        }

        if (!IsObject(filt) || filt.Length = 0) {
            SetStatus("AutoLearn: no candidates.")
            try {
                Log("AL END | NO CANDIDATES | cands=" (IsObject(cands) ? cands.Length : -1), "WARN", "AL")
            } catch {
            }
            return
        }

        chosen := 1
        bestMetrics := 0

        if (doClick) {
            topK := opts.Has("behTryTopK") ? opts["behTryTopK"] : 1
            if (topK < 1)
                topK := 1
            if (topK > filt.Length)
                topK := filt.Length

            bestScore := -1.0

            Loop topK {
                idx := A_Index
                rRel := filt[idx].rectRel

                SetStatus("AutoLearn: behavior test " idx "/" topK " (click)...")
                m := 0
                try {
                    m := AL_L5_TestBehavior(pCtx, rRel, opts, true)
                } catch {
                    m := 0
                }

                if (!IsObject(m))
                    continue

                behScore := m["deltaPct"] + (m["borderDeltaPct"] * 0.80)
                if (behScore > bestScore) {
                    bestScore := behScore
                    chosen := idx
                    bestMetrics := m
                }

                ; early exit if obviously interactive
                if (behScore >= 0.12)
                    break
            }
        }

        ; Final: extract template + anchors ONLY for chosen candidate

        try {
            Log("AL END | CHOOSE WINNER idx=" chosen " score=" Round(filt[chosen].score, 3), "INFO", "AL")
        } catch {
        }

        SetStatus("AutoLearn: extracting model...")
        
; Multi-icon export: pass winner first + the rest so AL_L4_Extract can save tpl_elem_2, tpl_elem_3...
extractList := [filt[chosen]]
global F3_MULTI_ICON
if (F3_MULTI_ICON && IsObject(filt) && filt.Length > 1) {
    for i, c in filt {
        if (i != chosen)
            extractList.Push(c)
    }
}

model := AL_L4_Extract(pCtx, extractList, 0, opts)
        if (!IsObject(model)) {
            SetStatus("AutoLearn: extract failed.")
            return
        }

        sig := 0
        if (doClick) {
            if (IsObject(bestMetrics))
                sig := AL_SigFromMetrics(bestMetrics, opts)
            else
                sig := AL_L5_LearnBehavior(pCtx, model, 0, opts)
        } else {
            sig := BehaviorSignature()
        }

        ; Save last result
        AL_LAST := Map(
            "model", model,
            "sig", sig,
            "candCount", IsObject(cands) ? cands.Length : 0,
            "filteredCount", filt.Length,
            "chosenIndex", chosen,
            "bestScore", model.meta.Has("score") ? model.meta["score"] : 0
        )

        if (IsObject(sig) && IsObject(sig.meta)) {
            AL_LAST["deltaPct"] := sig.meta.Has("deltaPct") ? sig.meta["deltaPct"] : 0
            AL_LAST["borderDeltaPct"] := sig.meta.Has("borderDeltaPct") ? sig.meta["borderDeltaPct"] : 0
        }

        try {
            Log("AL OK: cand=" AL_LAST["candCount"] " filt=" AL_LAST["filteredCount"]
                " chosen=" chosen
                " rectRel=" model.normRect.L "," model.normRect.T "," model.normRect.R "," model.normRect.B
                " anchors=" (IsObject(model.anchors) ? model.anchors.Length : 0)
                " behValid=" (sig.valid ? 1 : 0), "DEBUG", "AL")
        } catch {
        }

        ; Visual: overlay the learned rect (relative -> screen)
        try {
            screenRect := AL_RelToScreen(pRect, model.normRect)
            ShowRectOverlay(screenRect.L, screenRect.T, screenRect.R, screenRect.B, 1200)
        } catch {
        }

        if (doClick && IsObject(sig) && !sig.valid)
            SetStatus("AutoLearn: OK (but behavior=NO CHANGE). Saved to AL_LAST.")
        else
            SetStatus("AutoLearn: OK. Saved to AL_LAST.")
    } finally {
        try {
            g.Show()
        } catch {
        }
        busy := false
    }
}


; ----------------------------
; Hook: parent pick (Layer1)
; ----------------------------
AL_PickRegionDrag() {
    ; Reuse ScaleCycle PickRegionDrag() (screen coords)
    r := 0
    try {
        r := PickRegionDrag(false)
    } catch {
        return Map("ok", false, "reason", "exception")
    }

    if (!IsObject(r) || Type(r) != "Map")
        return Map("ok", false, "reason", "nonmap")

    if (r.Has("ok") && r["ok"])
        return Map("ok", true, "L", r["L"], "T", r["T"], "R", r["R"], "B", r["B"])

    reason := r.Has("reason") ? r["reason"] : "cancel"
    return Map("ok", false, "reason", reason)
}


; ----------------------------
; Hook: click center (Layer5)
; ----------------------------
AL_ClickCenterRect(screenRect) {
    if (!IsObject(screenRect))
        return
    L := screenRect.HasProp("L") ? screenRect.L : screenRect["L"]
    T := screenRect.HasProp("T") ? screenRect.T : screenRect["T"]
    R := screenRect.HasProp("R") ? screenRect.R : screenRect["R"]
    B := screenRect.HasProp("B") ? screenRect.B : screenRect["B"]
    x := Floor((L + R) / 2)
    y := Floor((T + B) / 2)
    try {
        Click(x, y)
    } catch {
        ; fallback
        MouseMove(x, y, 0)
        Sleep 10
        Click
    }
}


; =========================
; STABLE ENTRY
; =========================
; =========================================================
; GUI MODE (mờ/click-through) + HOTSPOT TOGGLE
; =========================================================
InitGuiHotspot() {
    global gHot, GUI_HOT_X, GUI_HOT_Y, GUI_HOT_W, GUI_HOT_H, g
    try {
        if (IsObject(gHot) && gHot.Hwnd)
            return
    } catch {
    }

    ; Tạo hotspot 1 ô nhỏ để bật/tắt GUI_MODE
    opt := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
    try {
        if (IsObject(g) && g.Hwnd)
            opt .= " +Owner" g.Hwnd
    } catch {
    }

    gHot := Gui(opt, "")
    gHot.MarginX := 0
    gHot.MarginY := 0
    btn := gHot.AddButton("x0 y0 w" GUI_HOT_W " h" GUI_HOT_H, T("BTN_TXT_01"))
    btn.OnEvent("Click", (*) => ToggleGuiMode())
    gHot.Show("NA x" GUI_HOT_X " y" GUI_HOT_Y " w" GUI_HOT_W " h" GUI_HOT_H)
}

ToggleGuiMode() {
    global GUI_MODE
    if (GUI_MODE = "RUN")
        SetGuiMode("EDIT")
    else
        SetGuiMode("RUN")
}

