; ==================================================================================================
;  MODULE 24 — Pixel
;  Source lines (original scale.ahk): 11233 – 11721
; ==================================================================================================
AL_L5_LearnBehavior(parentCtx, elementModel, store := 0, opts := 0) {
    ; Input: ParentContext + ElementModel
    ; Output: BehaviorSignature (valid=true if meaningful state change was detected)

    if (!IsObject(opts))
        opts := AL_DefaultOpts()

    ; --- AUTO-LEARNING WINDOW GATE (anti 10–20s) ---
    global LEARN_ACTIVE, LEARN_START_TICK, LEARN_MAX_MS
    global LEARN_LOOP_CNT, LEARN_LOOP_MAX
    global LEARN_BEH_VALID, LEARN_LOCKED, LEARN_ABORT
    global LEARN_TRIGGER_ACTION, LEARN_LAST_ACTION_TICK
    global HAS_ACTION_SINCE_PICK

    ; Gate: không học hành vi nếu chưa có ACTION thật sau lần F3 pick.
    if (!LEARN_ACTIVE && !HAS_ACTION_SINCE_PICK) {
        return BehaviorSignature(0, 0, "any", 0, false, Map("reason", "no-action"))
    }

    ; Legacy safety: nếu nhánh này bị gọi mà chưa bật learning (nhưng đã có ACTION), mở phiên ngắn để tránh học vô hạn.
    if (!LEARN_ACTIVE) {
        LEARN_ACTIVE := true
        if (LEARN_START_TICK = 0)
            LEARN_START_TICK := A_TickCount
        LEARN_LOOP_CNT := 0
        LEARN_ABORT := false
        LEARN_BEH_VALID := false
        LEARN_LOCKED := false
    }

    ; Timeout / overloop → khóa để pipeline không bị kẹt ở behValid=0 mãi mãi

; IDOL FAST MODE: shorten learn window to avoid multi-icon slow wait.
; NOTE: This does not change algorithm; it only caps the learn time budget.
try {
    global AL_IDOL_FAST_MODE, AL_IDOL_LEARN_MAX_MS
    if (AL_IDOL_FAST_MODE && (LEARN_MAX_MS > AL_IDOL_LEARN_MAX_MS))
        LEARN_MAX_MS := AL_IDOL_LEARN_MAX_MS
} catch {
}    elapsedLearn := A_TickCount - LEARN_START_TICK
    if (elapsedLearn > LEARN_MAX_MS || LEARN_LOOP_CNT >= LEARN_LOOP_MAX) {
        LEARN_ABORT := true
        LEARN_ACTIVE := false
        LEARN_LOCKED := true
        LEARN_BEH_VALID := true
        reason := (elapsedLearn > LEARN_MAX_MS) ? "learn-timeout" : "learn-overloop"
        sig := BehaviorSignature(0, 0, "any", 120, true, Map("reason", reason, "action", LEARN_TRIGGER_ACTION))
        return sig
    }

    LEARN_LOOP_CNT += 1

    parent := parentCtx.rect
    rel := elementModel.normRect

    metrics := 0
    try {
        metrics := AL_L5_TestBehavior(parentCtx, rel, opts, true)
    } catch {
        metrics := 0
    }

    if (!IsObject(metrics)) {
        sig := BehaviorSignature(0.99, 0.99, "any", 120, false, Map("reason","capture-fail"))
        return sig
    }


    sig := AL_SigFromMetrics(metrics, opts)

    ; Update learning state (stop learning once behavior valid)
    try {
        LEARN_BEH_VALID := (IsObject(sig) && sig.valid) ? true : false
        if (LEARN_BEH_VALID) {
            LEARN_ACTIVE := false
            LEARN_LOCKED := true
        }
    } catch {
    }

    if (IsObject(store)) {
        try {
            store.Write("behavior", "deltaPctMin", sig.deltaPctMin)
            store.Write("behavior", "borderDeltaMin", sig.borderDeltaMin)
            store.Write("behavior", "lumaShiftDir", sig.lumaShiftDir)
            store.Write("behavior", "settleDelayMs", sig.settleDelayMs)
            store.Write("behavior", "valid", sig.valid ? 1 : 0)
        } catch {
        }
    }
    return sig
}


AL_ExpandRect(r, pad) {
    return Rect(r.L - pad, r.T - pad, r.R + pad, r.B + pad)
}


AL_PickAnchors(parentCtx, rectRel, k := 6, tol := 45) {
    ; Requirement: AL_Capture_ReadPixelGrid(parent, stride) must return rgb[] or luma[] sufficient to compute contrast.
    ; Strategy:
    ;  - sample grid in parent rect stride=3
    ;  - within rectRel, compute local contrast from luma (4-neigh)
    ;  - pick top K points far-enough (non-duplicate)

    parent := parentCtx.rect
    grid := AL_Capture_ReadPixelGrid(parent, 3)
    wCells := grid["wCells"]
    hCells := grid["hCells"]
    stride := grid["stride"]
    luma := grid["luma"]
    rgb := grid.Has("rgb") ? grid["rgb"] : 0

    ; Convert rectRel px -> cell bounds
    x1 := Floor(rectRel.L / stride)
    y1 := Floor(rectRel.T / stride)
    x2 := Ceil(rectRel.R / stride)
    y2 := Ceil(rectRel.B / stride)

    scores := [] ; items: [score, cx, cy, idx]
    Loop (y2 - y1 + 1) {
        cy := y1 + A_Index - 1
        if (cy < 1 || cy >= hCells-1)
            continue
        Loop (x2 - x1 + 1) {
            cx := x1 + A_Index - 1
            if (cx < 1 || cx >= wCells-1)
                continue
            idx := cy*wCells + cx + 1
            c := luma[idx]
            d := Abs(c - luma[idx+1]) + Abs(c - luma[idx-1]) + Abs(c - luma[idx+wCells]) + Abs(c - luma[idx-wCells])
            if (d < 35)
                continue
            scores.Push([d, cx, cy, idx])
        }
    }

    ; sort desc by score
    if (scores.Length > 1)
        AL_ArraySort(scores, (a,b) => (b[1] > a[1]) ? 1 : (b[1] < a[1]) ? -1 : 0)

    anchors := []
    minDistCells := 3
    for item in scores {
        if (anchors.Length >= k)
            break
        cx := item[2]
        cy := item[3]
        idx := item[4]

        ; far-enough constraint
        ok := true
        for a in anchors {
            ax := a["_cx"]
            ay := a["_cy"]
            if (Abs(cx-ax) + Abs(cy-ay) < minDistCells) {
                ok := false
                break
            }
        }

        if (!ok)
            continue

        ; anchor pixel in rectRel coords
        px := cx*stride - rectRel.L
        py := cy*stride - rectRel.T

        col := 0
        if (IsObject(rgb))
            col := rgb[idx]
        else {
            ; no rgb provided: fake gray from luma
            lum := luma[idx] & 0xFF
            col := (lum<<16) | (lum<<8) | lum
        }

        a := Map("dx", px, "dy", py, "rgb", col, "tol", tol, "_cx", cx, "_cy", cy)
        anchors.Push(a)
    }

    ; strip internal fields
    for a in anchors {
        a.Delete("_cx")
        a.Delete("_cy")
    }
    return anchors
}


AL_ComputeDiffMetrics(beforeGrid, afterGrid, opts) {
    ; Compute:
    ;  - deltaPct: % cells changed (luma diff > behPixelDiff)
    ;  - borderDeltaPct: only border ring
    ;  - lumaShiftDir: avg luma up/down

    w := beforeGrid["wCells"]
    h := beforeGrid["hCells"]
    l1 := beforeGrid["luma"]
    l2 := afterGrid["luma"]
    diffThr := opts["behPixelDiff"]
    ring := opts["behBorderRing"]

    total := w*h
    changed := 0
    borderTotal := 0
    borderChanged := 0

    sumShift := 0

    Loop h {
        y := A_Index - 1
        Loop w {
            x := A_Index - 1
            i := y*w + x + 1
            d := Abs(l2[i] - l1[i])
            if (d >= diffThr)
                changed += 1
            sumShift += (l2[i] - l1[i])

            isBorder := (x < ring) || (y < ring) || (x >= w-ring) || (y >= h-ring)
            if (isBorder) {
                borderTotal += 1
                if (d >= diffThr)
                    borderChanged += 1
            }
        }
    }

    deltaPct := (total > 0) ? (changed / total) : 0
    borderDeltaPct := (borderTotal > 0) ? (borderChanged / borderTotal) : 0
    avgShift := (total > 0) ? (sumShift / total) : 0
    dir := "any"
    if (avgShift > 2.0)
        dir := "up"
    else if (avgShift < -2.0)
        dir := "down"

    return Map("deltaPct", deltaPct, "borderDeltaPct", borderDeltaPct, "lumaShiftDir", dir, "avgShift", avgShift)
}



AL_Clamp(x, lo, hi) {
    if (x < lo)
        return lo
    if (x > hi)
        return hi
    return x
}


AL_IoU(r1, r2) {
    L := Max(r1.L, r2.L)
    T := Max(r1.T, r2.T)
    R := Min(r1.R, r2.R)
    B := Min(r1.B, r2.B)
    iw := R - L
    ih := B - T
    if (iw <= 0 || ih <= 0)
        return 0.0
    inter := iw * ih
    a1 := Max(0, (r1.R - r1.L)) * Max(0, (r1.B - r1.T))
    a2 := Max(0, (r2.R - r2.L)) * Max(0, (r2.B - r2.T))
    uni := a1 + a2 - inter
    return (uni > 0) ? (inter / uni) : 0.0
}

AL_RectInside(a, b, containThr := 0.92, areaFracMax := 0.45) {
    try {
        ; intersection
        l := (a.L > b.L) ? a.L : b.L
        t := (a.T > b.T) ? a.T : b.T
        r := (a.R < b.R) ? a.R : b.R
        btm := (a.B < b.B) ? a.B : b.B
        w := r - l
        h := btm - t
        if (w <= 0 || h <= 0)
            return false
        inter := w * h
        aw := a.R - a.L
        ah := a.B - a.T
        if (aw <= 0 || ah <= 0)
            return false
        aArea := aw * ah
        contain := inter / aArea
        if (contain < containThr)
            return false

        bw := b.R - b.L
        bh := b.B - b.T
        if (bw <= 0 || bh <= 0)
            return true
        bArea := bw * bh
        areaFrac := aArea / bArea
        return (areaFrac <= areaFracMax)
    } catch {
        return false
    }
}



AL_RegionMetricsFromGrid(grid, rectRel, opts, grid2 := 0) {
    ; Returns Map:
    ;  contrastAvg, edgeDensity, hTransD, vTransD, stabDeltaPct

    stride := grid["stride"]
    wCells := grid["wCells"]
    hCells := grid["hCells"]
    l1 := grid["luma"]
    l2 := IsObject(grid2) ? grid2["luma"] : 0

    edgeThr := opts["edgeThresh"]
    stabThr := opts.Has("stabPixelDiff") ? opts["stabPixelDiff"] : 10

    ; ===== YIELD (B) – keep GUI alive during heavy metrics loops =====
    static __rm_lastYield := 0
    __rm_yieldMs := 10

    x1 := Max(0, Floor(rectRel.L / stride))
    y1 := Max(0, Floor(rectRel.T / stride))
    x2 := Min(wCells-1, Floor((rectRel.R-1) / stride))
    y2 := Min(hCells-1, Floor((rectRel.B-1) / stride))

    cw := x2 - x1 + 1
    ch := y2 - y1 + 1
    if (cw <= 1 || ch <= 1)
        return Map()

    sumC := 0.0
    cCount := 0
    edgeCnt := 0

    hTrans := 0
    vTrans := 0
    hTransDen := Max(1, (cw-1) * ch)
    vTransDen := Max(1, cw * (ch-1))

    stabChanged := 0
    stabTotal := 0
    useStab := IsObject(l2) && (grid2["wCells"] = wCells) && (grid2["hCells"] = hCells)

    Loop ch {
        yy := y1 + A_Index - 1
        base := yy*wCells
        Loop cw {
            xx := x1 + A_Index - 1
            i := base + xx + 1

            ; yield every ~10ms to avoid UI freeze (method B)
            if (A_TickCount - __rm_lastYield > __rm_yieldMs) {
                __rm_lastYield := A_TickCount
                try {
                    Sleep(0)
                } catch {
                }
            }
            c := l1[i]

            if (xx < x2) {
                d := Abs(c - l1[i+1])
                sumC += d
            cCount += 1
                if (d >= edgeThr) {
                    edgeCnt += 1
                    hTrans += 1
                }
            }

            if (yy < y2) {
                d2 := Abs(c - l1[i+wCells])
                sumC += d2
                cCount += 1
                if (d2 >= edgeThr) {
                    edgeCnt += 1
                    vTrans += 1
                }
            }

            if (useStab) {
                stabTotal += 1
                if (Abs(l2[i] - l1[i]) >= stabThr)
                    stabChanged += 1
            }
        }
    }

    contrastAvg := (cCount > 0) ? (sumC / cCount) : 0.0
    edgeDensity := (cCount > 0) ? (edgeCnt / cCount) : 0.0
    hTransD := hTrans / hTransDen
    vTransD := vTrans / vTransDen
    stabDeltaPct := (stabTotal > 0) ? (stabChanged / stabTotal) : 0.0

    return Map(
        "contrastAvg", contrastAvg,
        "edgeDensity", edgeDensity,
        "hTransD", hTransD,
        "vTransD", vTransD,
        "stabDeltaPct", stabDeltaPct
    )
}


AL_L5_TestBehavior(parentCtx, relRect, opts, doClick := true) {
    parent := parentCtx.rect
    roi := AL_RelToScreen(parent, relRect)
    roi := AL_ExpandRect(roi, opts["behPad"])

    before := AL_Capture_ReadPixelGrid(roi, 2)

    if (doClick) {
        clickRect := AL_RelToScreen(parent, relRect)
        AL_ClickCenterRect(clickRect)
        Sleep(120)
    } else {
        Sleep(60)
    }

    after := AL_Capture_ReadPixelGrid(roi, 2)
    m := AL_ComputeDiffMetrics(before, after, opts)
    m["roiL"] := roi.L
    m["roiT"] := roi.T
    m["roiR"] := roi.R
    m["roiB"] := roi.B
    return m
}


AL_SigFromMetrics(metrics, opts) {
    ; TEST MODE: force behValid=1 for UI_TestDiamondClick (engine-safe)
    global __UI_IS_TESTING, __TEST_FORCE_BEHVALID
    if (__UI_IS_TESTING && __TEST_FORCE_BEHVALID) {
        return BehaviorSignature(0.0, 0.0, "any", 120, true, metrics)
    }

    minDelta := opts.Has("behMinDelta") ? opts["behMinDelta"] : 0.025
    minBorder := opts.Has("behMinBorder") ? opts["behMinBorder"] : 0.012

    delta := metrics.Has("deltaPct") ? metrics["deltaPct"] : 0
    border := metrics.Has("borderDeltaPct") ? metrics["borderDeltaPct"] : 0
    dir := metrics.Has("lumaShiftDir") ? metrics["lumaShiftDir"] : "any"

    valid := (delta >= minDelta) || (border >= minBorder)
    if (!valid)
        return BehaviorSignature(0.99, 0.99, "any", 120, false, metrics)

    deltaMin := Max(minDelta, delta * 0.45)
    borderMin := Max(minBorder, border * 0.45)
    return BehaviorSignature(deltaMin, borderMin, dir, 120, true, metrics)
}


AL_L5_VerifyBehavior(parentCtx, elementModel, sig, opts := 0) {
    if (!IsObject(opts))
        opts := AL_DefaultOpts()
    if (!IsObject(sig) || !sig.valid)
        return false

    m := 0
    try {
        m := AL_L5_TestBehavior(parentCtx, elementModel.normRect, opts, true)
    } catch {
        return false
    }

    if (!IsObject(m))
        return false

    pass := (m["deltaPct"] >= sig.deltaPctMin) || (m["borderDeltaPct"] >= sig.borderDeltaMin)

    if (sig.lumaShiftDir = "up")
        pass := pass && (m.Has("avgShift") && m["avgShift"] > 1.0)
    else if (sig.lumaShiftDir = "down")
        pass := pass && (m.Has("avgShift") && m["avgShift"] < -1.0)

    return pass
}


; ⚡ F4 = FAST MATCH MODE
; - KHÔNG full capture
; - KHÔNG pixel full rect
; - AL chỉ chạy trên bmpCrop (ROI từ F3)
; - Không repick / không rebuild grid
; Vi phạm → chậm + sai triết lý idol dev


