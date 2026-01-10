; ==================================================================================================
;  MODULE 22 — Logger
;  Source lines (original scale.ahk): 10443 – 10719
; ==================================================================================================


; ============================================================
; Layer 3 - Candidate Filtering (icon/button likelihood)
; ============================================================
AL_L3_Filter(parentCtx, candidates, opts := 0) {
    ; Input: ParentContext + Candidates[]
    ; Output: Filtered[] (sorted desc score)

    if (!IsObject(opts))
        opts := AL_DefaultOpts()

    filtered := []
    if (!IsObject(candidates) || candidates.Length = 0)
        return filtered


    try {
        Log("AL L3 START | in=" candidates.Length, "DEBUG", "AL")
    } catch {
    }

    keepLogged := 0
    keepLogCap := 60
    rejSize := 0
    rejRatio := 0
    rejContrast := 0
    rejTextStrip := 0
    rejStab := 0
    rejHTrans := 0
    rejScore := 0
    minW := opts["minW"]
    minH := opts["minH"]
    maxW := opts["maxW"]
    maxH := opts["maxH"]
    ratioMin := opts["ratioMin"]
    ratioMax := opts["ratioMax"]
    minScore := opts["minScore"]

    ; Use cached grid from Layer 2 when possible
    grid := parentCtx.meta.Has("grid") ? parentCtx.meta["grid"] : 0
    if (!IsObject(grid)) {
        try {
            grid := AL_Capture_ReadPixelGrid(parentCtx.rect, opts["stride"])
            parentCtx.meta["grid"] := grid
        } catch {
            grid := 0
        }
    }

    grid2 := 0
    if (opts.Has("stabEnabled") && opts["stabEnabled"] && IsObject(grid)) {
        if (parentCtx.meta.Has("grid2")) {
            grid2 := parentCtx.meta["grid2"]
        } else {
            try {
                Sleep(opts["stabDelayMs"])
            } catch {
            }
            try {
                grid2 := AL_Capture_ReadPixelGrid(parentCtx.rect, grid["stride"])
                parentCtx.meta["grid2"] := grid2
            } catch {
                grid2 := 0
            }
        }
    }

    idx := 0
    for cand in candidates {
        idx += 1
        r := cand.rectRel
        w := r.W
        h := r.H
        if (w < minW || h < minH || w > maxW || h > maxH) {
            rejSize += 1
            try {
                Log("AL REJECT | size idx=" idx " w=" w " h=" h " need>=" minW "," minH " max<=" maxW "," maxH, "DEBUG", "AL")
            } catch {
            }
            continue
        }

        ratio := w / h
        if (ratio < ratioMin || ratio > ratioMax) {
            rejRatio += 1
            try {
                Log("AL REJECT | ratio idx=" idx " ratio=" Round(ratio, 3) " need=" ratioMin "-" ratioMax, "DEBUG", "AL")
            } catch {
            }
            continue
        }

        ; quick text strip (very wide & short)
        if (!(opts.Has("allowTextStrip") && opts["allowTextStrip"]) && (ratio > 3.0 && h <= 26)) {
            rejTextStrip += 1
            try {
                Log("AL REJECT | textstrip idx=" idx " ratio=" Round(ratio, 3) " h=" h, "DEBUG", "AL")
            } catch {
            }
            continue
        }

        m := IsObject(grid) ? AL_RegionMetricsFromGrid(grid, r, opts, grid2) : Map()

        ; reject near-flat background
        if (m.Has("contrastAvg")) {
            if (m["contrastAvg"] < opts["bgContrastMin"] && (m.Has("edgeDensity") ? m["edgeDensity"] : 0) < 0.12) {
                rejContrast += 1
                try {
                    Log("AL REJECT | contrast idx=" idx " contrast=" Round(m["contrastAvg"], 1) " need>=" opts["bgContrastMin"]
                        " edgeD=" Round((m.Has("edgeDensity") ? m["edgeDensity"] : 0), 3), "DEBUG", "AL")
                } catch {
                }
                continue
            }
        }

        ; stability filter (animated/noisy areas)
        if (m.Has("stabDeltaPct")) {
            if (opts["stabEnabled"] && m["stabDeltaPct"] > opts["stabMaxDelta"]) {
                rejStab += 1
                try {
                    Log("AL REJECT | stab idx=" idx " delta=" Round(m["stabDeltaPct"], 4) " max=" opts["stabMaxDelta"], "DEBUG", "AL")
                } catch {
                }
                continue
            }
        }

        ; drop text-like blocks (high transition density)
        if (m.Has("hTransD")) {
            if (m["hTransD"] > opts["textTransHigh"] && (ratio > 1.8 || h <= 32)) {
                rejHTrans += 1
                try {
                    Log("AL REJECT | hTrans idx=" idx " hTransD=" Round(m["hTransD"], 4) " max=" opts["textTransHigh"] " ratio=" Round(ratio, 3) " h=" h, "DEBUG", "AL")
                } catch {
                }
                continue
            }
        }

        s := cand.score

        ; icon-ish bonus
        if (ratio >= 0.65 && ratio <= 1.55)
            s += 0.18
        else if (ratio > 1.55 && ratio <= 2.6 && h >= 24)
            s += 0.08

        ; contrast bonus
        if (m.Has("contrastAvg")) {
            s += AL_Clamp((m["contrastAvg"] - 18) / 70, 0, 1) * 0.35
        }

        ; edge density: moderate is best, extremely high is usually text/noise
        if (m.Has("edgeDensity")) {
            ed := m["edgeDensity"]
            if (ed >= 0.20 && ed <= 0.65)
                s += 0.10
            else if (ed > 0.80)
                s -= 0.15
        }

        ; stability bonus/penalty
        if (m.Has("stabDeltaPct")) {
            st := m["stabDeltaPct"]
            if (st <= 0.03)
                s += 0.15
            else if (st <= 0.08)
                s += 0.05
            else
                s -= 0.25
        }

        ; extra penalty if still looks like text
        if (m.Has("hTransD")) {
            if (m["hTransD"] > 0.22 && ratio > 1.8)
                s -= 0.25
        }

        cand.score := s
        ; attach stats for debug
        if (IsObject(cand.stats))
            if (m.Has("contrastAvg")) cand.stats["contrast"] := m["contrastAvg"]
        if (IsObject(cand.stats))
            if (m.Has("edgeDensity")) cand.stats["edgeDensity"] := m["edgeDensity"]
        if (IsObject(cand.stats))
            if (m.Has("hTransD")) cand.stats["hTransD"] := m["hTransD"]
        if (IsObject(cand.stats))
            if (m.Has("stabDeltaPct")) cand.stats["stabDelta"] := m["stabDeltaPct"]

        if (s < minScore) {
            rejScore += 1
            try {
                Log("AL REJECT | score idx=" idx " score=" Round(s, 3) " need>=" minScore, "DEBUG", "AL")
            } catch {
            }
            continue
        }

        if (keepLogged < keepLogCap) {
            keepLogged += 1
            try {
                Log("AL KEEP | idx=" idx " w=" w " h=" h " ratio=" Round(ratio, 3)
                    " contrast=" (m.Has("contrastAvg") ? Round(m["contrastAvg"], 1) : "NA")
                    " edgeD=" (m.Has("edgeDensity") ? Round(m["edgeDensity"], 3) : "NA")
                    " score=" Round(s, 3), "DEBUG", "AL")
            } catch {
            }
        } else if (keepLogged = keepLogCap) {
            keepLogged += 1
            try {
                Log("AL KEEP | ... suppressed after " keepLogCap, "DEBUG", "AL")
            } catch {
            }
        }

        filtered.Push(cand)
    }

    if (filtered.Length = 0) {
        try {
            Log("AL RESULT | final=0", "DEBUG", "AL")
            Log("AL L3 END | kept=0 rejSize=" rejSize " rejRatio=" rejRatio " rejTextStrip=" rejTextStrip " rejContrast=" rejContrast " rejStab=" rejStab " rejHTrans=" rejHTrans " rejScore=" rejScore, "DEBUG", "AL")
        } catch {
        }
        return filtered
    }

    if (filtered.Length > 1)
        AL_ArraySort(filtered, (a,b) => (b.score > a.score) ? 1 : (b.score < a.score) ? -1 : 0)

    ; Non-max suppression to avoid many overlapping boxes
    kept := []
    iouThr := opts["nmsIou"]
    cap := opts["keepTop"]
    for cand in filtered {
        if (kept.Length >= cap)
            break
        ok := true
        for k in kept {
            if (AL_IoU(cand.rectRel, k.rectRel) >= iouThr) {
                ok := false
                break
            }
        }

        if (ok)
            kept.Push(cand)
    }

    try {
        Log("AL RESULT | final=" kept.Length, "DEBUG", "AL")
        Log("AL L3 END | kept=" kept.Length " rejSize=" rejSize " rejRatio=" rejRatio " rejTextStrip=" rejTextStrip " rejContrast=" rejContrast " rejStab=" rejStab " rejHTrans=" rejHTrans " rejScore=" rejScore, "DEBUG", "AL")
    } catch {
    }

    return kept
}


; ============================================================
; Layer 4 - Template / Anchor Extraction
; ============================================================
; ======================================================================
; 🧠 FAST MODE – ROI ONLY (IDOL DEV WARNING)
; ======================================================================
; FAST MODE (F4) KHÔNG PHẢI LÀ “FLAG TRANG TRÍ”.
; FAST MODE = CẮT ĐỨT NHÁNH PARENT CAPTURE/DECIDE.
;
; Khi CAP_FAST_MODE/AL_FAST_MODE/PIPE_MODE="F4":
;   ✔ Chỉ SCREEN template capture theo ROI (screenRect/cropRect)
;   ✔ KHÔNG chạy CAP DECIDE / DXGI / PrintWindow / parent_*.bmp
;   ✔ BẮT BUỘC return sớm khỏi nhánh parent capture (capHwnd := 0)
; ======================================================================

