; ==================================================================================================
;  MODULE 21 — Logger
;  Source lines (original scale.ahk): 9742 – 10442
; ==================================================================================================
DoOne(cycIdx) {
    global DIA_LIST, SCA_LIST
    global diaSel
    global runnerL, runnerT, runnerR, runnerB
    global parentL, parentT, parentR, parentB
    global DBG_F3_DIM_TOOLTIP
    global scaleRunL, scaleRunT, scaleRunR, scaleRunB
    global clickOffsetX, clickOffsetY
    global scaleDx, scaleDy
    global diamondClickMode, scaleClickMode
    global commitKey, keyframeKey, nextCutKey
    global workflowMode, lowV, highV
    global SCANS, diaBox, scaBox, maxScanKeep
    global lastDia, lastSca
    global diaPack, scaPack
    global cacheBox, anchorThr, anchorNeedCluster, anchorNeedH, anchorNeedV
    global relOffset, baseWinW, baseWinH
    global winCache

    if (DIA_LIST.Length < 1) {
        SetStatus("ERROR: Add Diamond images.")
        return false
    }


    ; Diamond priority: try selected image first (PRIMARY), then remaining as FALLBACK.
    diaListUse := BuildPriorityList(DIA_LIST, diaSel, &primaryDiaPath)
    hwnd := winCache["hwnd"]
    winRect := GetWinRect(hwnd)
    if (!IsObject(winRect)) {
        SetStatus("ERROR: Cannot read window rect.")
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


    ; Workflow: KEYFRAME_CYCLE = Send "/" first (jump frame) -> click 💎 -> type A/B
    if (StrUpper(workflowMode) = "KEYFRAME_CYCLE") {
        JumpNextFrame_Auto()
        ; A/B cycle (best for CapCut): A=low, B=high
        val := (Mod(cycIdx, 2) = 1) ? lowV : highV
    } else {
        val := GetCycleValue(cycIdx)
    }


; 1) Find Diamond: cached -> full, clipped to window
; 1) Find Diamond: tier1 child region -> fallback to tier0 parent
diaPad := 6  ; safety margin for thin-outline diamond (4–8px recommended)
if ((runnerR > runnerL) && (runnerB > runnerT)) {
    fullRunner := Map("L", runnerL, "T", runnerT, "R", runnerR, "B", runnerB)
    fullRunner := ClipRegionToWin(fullRunner, winRect)
} else {
    fullRunner := parentReg
}
; Make sure scan region truly covers the diamond + doesn't cut thin border
try {
    fullRunner := InflateRegion(fullRunner, diaPad)
    fullRunner := ClipRegionToWin(fullRunner, winRect)
} catch {
}



    dReg := MakeCachedRegion(lastDia, fullRunner, cacheBox)
    found := FindBestMatch(diaListUse, dReg, diaPack, &dx, &dy)

    if (!found) {
        found := FindBestMatch(diaListUse, fullRunner, diaPack, &dx, &dy)
    }

    ; Fallback: if tier1 failed, try tier0 parent (manual) region
    if (!found && hasParent) {
        if (fullRunner["L"] != parentReg["L"] || fullRunner["T"] != parentReg["T"] || fullRunner["R"] != parentReg["R"] || fullRunner["B"] != parentReg["B"]) {
            dReg2 := MakeCachedRegion(lastDia, parentReg, cacheBox)
            found := FindBestMatch(diaListUse, dReg2, diaPack, &dx, &dy)
            if (!found) {
                found := FindBestMatch(diaListUse, parentReg, diaPack, &dx, &dy)
            }
        }
    }

    if (!found) {
    ; Fallback: diamond is often a THIN OUTLINE -> image search can miss.
    fbOk := false
    try {
        fbOk := AL_FindDiamondOutlineBright(fullRunner, winRect, &dx, &dy, 0, 210)
    } catch as e {
        fbOk := false
        try {
            LogWarn("Diamond fallback exception err=" e.Message, "DIA")
        } catch {
        }
    }

    if (fbOk) {
        found := true
        try {
            Log("Diamond fallback OK x=" dx " y=" dy, "WARN", "DIA")
        } catch {
        }
    } else {
        try {
            Log("Diamond fallback FAIL reg=(" fullRunner["L"] "," fullRunner["T"] "," fullRunner["R"] "," fullRunner["B"] ")", "WARN", "DIA")
        } catch {
        }
    }
}

if (!found) {
    ToolTip("Diamond NOT found.", 20, 20)
    SetTimer(() => ToolTip(), -900)
    SetStatus("STOP: Diamond not found.")
    return false
}


    ; Learn anchors after successful find
    lastDia["x"] := dx
    lastDia["y"] := dy
    LearnAnchorPack(dx, dy, &diaPack)

    ; clipboard = x,y only
    A_Clipboard := dx "," dy

    ; scan record now
    rec := Map()
    rec["diaL"] := dx - diaBox
    rec["diaT"] := dy - diaBox
    rec["diaR"] := dx + diaBox
    rec["diaB"] := dy + diaBox
    rec["scaL"] := ""
    rec["scaT"] := ""
    rec["scaR"] := ""
    rec["scaB"] := ""
    rec["time"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    SCANS.InsertAt(1, rec)
    ; Limit scan history length
    if (maxScanKeep < 1)
        maxScanKeep := 1
    while (SCANS.Length > maxScanKeep)
        SCANS.Pop()
    SaveScansToIni()
    RefreshScanCombo()

    ; click diamond (tiny jitter before click)
    MoveCursor(dx + clickOffsetX, dy + clickOffsetY)
    Sleep(Random(8, 18))
    MouseClickLeft(diamondClickMode)

    ; 2) Find Scale (image-based if configured + valid region), else relative offset fallback
    sx := ""
    sy := ""
    usedImg := false

    if (SCA_LIST.Length > 0) {
        ; Tier1 scale child region if available, else tier0 parent
        if ((scaleRunR > scaleRunL) && (scaleRunB > scaleRunT)) {
            fullScale := Map("L", scaleRunL, "T", scaleRunT, "R", scaleRunR, "B", scaleRunB)
            fullScale := ClipRegionToWin(fullScale, winRect)
        } else {
            fullScale := parentReg
        }

        sReg := MakeCachedRegion(lastSca, fullScale, cacheBox)
        usedImg := FindBestMatch(SCA_LIST, sReg, scaPack, &sx, &sy)
        if (!usedImg) {
            usedImg := FindBestMatch(SCA_LIST, fullScale, scaPack, &sx, &sy)
        }

        ; Fallback: if tier1 scale failed, try parent region
        if (!usedImg && hasParent) {
            if (fullScale["L"] != parentReg["L"] || fullScale["T"] != parentReg["T"] || fullScale["R"] != parentReg["R"] || fullScale["B"] != parentReg["B"]) {
                sReg2 := MakeCachedRegion(lastSca, parentReg, cacheBox)
                usedImg := FindBestMatch(SCA_LIST, sReg2, scaPack, &sx, &sy)
                if (!usedImg) {
                    usedImg := FindBestMatch(SCA_LIST, parentReg, scaPack, &sx, &sy)
                }
            }
        }

        if (usedImg) {
            lastSca["x"] := sx
            lastSca["y"] := sy
            LearnAnchorPack(sx, sy, &scaPack)
        }
    }

    if (!usedImg) {
        dx2 := scaleDx
        dy2 := scaleDy
        if (relOffset = 1 && baseWinW > 0 && baseWinH > 0) {
            sxFactor := winRect["W"] / baseWinW
            syFactor := winRect["H"] / baseWinH
            dx2 := Round(scaleDx * sxFactor)
            dy2 := Round(scaleDy * syFactor)
        }
        sx := dx + dx2
        sy := dy + dy2
        lastSca["x"] := sx
        lastSca["y"] := sy
    }

    ; update scan record with scale
    rec["scaL"] := sx - scaBox
    rec["scaT"] := sy - scaBox
    rec["scaR"] := sx + scaBox
    rec["scaB"] := sy + scaBox
    rec["time"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    SaveScansToIni()
    RefreshScanCombo()

    ; clipboard = x,y only
    A_Clipboard := sx "," sy

    ; click scale + type
    MoveCursor(sx, sy)
    Sleep(Random(8, 18))
    MouseClickLeft(scaleClickMode)
    Sleep(25)
    Send("^a")
    Sleep(10)
    SendText("" val)
    Sleep(10)
    if (commitKey != "")
        Send(commitKey)

    if (StrUpper(workflowMode) != "KEYFRAME_CYCLE") {
        if (keyframeKey != "")
            Send(keyframeKey)
        if (nextCutKey != "")
            Send(nextCutKey)
    }

    return true
}


; ============================================================
; Layer 1 - Manual Parent Pick
; ============================================================
AL_L1_ManualParentPick(store := 0) {
    local rect
    ; Input: user picks region via your existing F3 handler
    ; Output: ParentContext or 0

    r := 0
    try {
        r := AL_PickRegionDrag() ; MUST return Map(ok:=1, L,T,R,B) or Map(cancel:="...")
    } catch {
        return 0
    }

    if (!IsObject(r) || !r.Has("ok") || !r["ok"])
        return 0

    rect := Rect(r["L"], r["T"], r["R"], r["B"])

    bmp := ""
    try {
        bmp := A_ScriptDir "\parent_" FormatTime(A_Now, "yyyyMMdd_HHmmss") ".bmp"
        if (!AL_Capture_RectToBMP(rect, bmp, Map("caller","AL_L1_ManualParentPick","srcMode","Screen","hwnd",0)))
            bmp := ""
    } catch {
        bmp := ""
    }

    ctx := ParentContext(rect, bmp, Map("dpi", A_ScreenDPI, "ts", A_Now))

    ; Optional persist
    if (IsObject(store)) {
        try {
            store.Write("parent", "L", rect.L)
            store.Write("parent", "T", rect.T)
            store.Write("parent", "R", rect.R)
            store.Write("parent", "B", rect.B)
            store.Write("parent", "bmp", bmp)
        } catch {
        }
    }
    return ctx
}


; ============================================================
; Layer 2 - Visual Segmentation (no ML)
; ============================================================
AL_L2_Segment(parentCtx, opts := 0) {
    local rect
    ; Input: ParentContext
    ; Output: Array of Candidate (rectRel inside parent)

    if (!IsObject(opts))
        opts := AL_DefaultOpts()

    candidates := []
    rect := parentCtx.rect


    try {
        Log("AL L2 START | rect=" rect.L "," rect.T "," rect.R "," rect.B, "DEBUG", "AL")
    } catch {
    }
    ; Pre-init locals to keep #Warn All happy (avoid "unassigned" warnings)
    local L := 0, T := 0, R := 0, B := 0
    local w := 0, h := 0, area := 0
    local sizeScore := 0.0, densScore := 0.0, s := 0.0
    local rectRel := 0, cand := 0


    grid := 0
    try {
        grid := AL_Capture_ReadPixelGrid(rect, opts["stride"])
        parentCtx.meta["grid"] := grid
    } catch {
        return candidates
    }

    wCells := grid["wCells"]
    hCells := grid["hCells"]
    stride := grid["stride"]
    luma := grid["luma"]
    edgeThr := opts["edgeThresh"]
    varThr  := opts["varThresh"]


    totalCells := wCells*hCells
    maskOnCount := 0
    try {
        Log("AL GRID | wCells=" wCells " hCells=" hCells " stride=" stride " total=" totalCells, "DEBUG", "AL")
    } catch {
    }

    mask := []
    mask.Length := wCells*hCells

    ; Build an "interest mask" from edge + local deviation (no ML)
    Loop hCells {
        y := A_Index - 1
        Loop wCells {
            x := A_Index - 1
            i := y*wCells + x + 1
            c := luma[i]

            ; local deviation from 4-neighbors
            sumN := 0
            cntN := 0
            if (x > 0) {
                sumN += luma[i-1]
                cntN += 1
            }

            if (x+1 < wCells) {
                sumN += luma[i+1]
                cntN += 1
            }

            if (y > 0) {
                sumN += luma[i-wCells]
                cntN += 1
            }

            if (y+1 < hCells) {
                sumN += luma[i+wCells]
                cntN += 1
            }
            meanN := (cntN > 0) ? (sumN / cntN) : c
            dVar := Abs(c - meanN)

            ; edge energy
            dEdge := 0
            if (x+1 < wCells)
                dEdge += Abs(c - luma[i+1])
            if (y+1 < hCells)
                dEdge += Abs(c - luma[i+wCells])

            v := (dEdge >= edgeThr || dVar >= varThr) ? 1 : 0

            mask[i] := v
            if (v = 1)
                maskOnCount += 1
        }
    }

    try {
        mratio := (totalCells > 0) ? Round(maskOnCount/totalCells, 3) : 0
        Log("AL MASK | on=" maskOnCount " total=" totalCells " ratio=" mratio, "DEBUG", "AL")
    } catch {
    }

    ; optional dilation to connect thin edges

    dilateN := (opts.Has("dilate") ? opts["dilate"] : 0)
    if (dilateN > 0) {
        Loop dilateN {
            mask2 := []
            mask2.Length := wCells*hCells
            Loop mask2.Length {
                mask2[A_Index] := 0
            }
            Loop hCells {
                y := A_Index - 1
                Loop wCells {
                    x := A_Index - 1
                    i := y*wCells + x + 1
                    if (AL_ArrGet(mask, i, 0) != 1)
                        continue
                    mask2[i] := 1
                    if (x > 0) {
                        mask2[i-1] := 1
                    }

                    if (x+1 < wCells) {
                        mask2[i+1] := 1
                    }

                    if (y > 0) {
                        mask2[i-wCells] := 1
                    }

                    if (y+1 < hCells) {
                        mask2[i+wCells] := 1
                    }
                }
            }
            mask := mask2
        }
    }

    maskAfterCount := 0
    Loop totalCells {
        if (AL_ArrGet(mask, A_Index, 0) = 1)
            maskAfterCount += 1
    }
    try {
        Log("AL DILATE | level=" dilateN " maskAfter=" maskAfterCount, "DEBUG", "AL")
    } catch {
    }



    visited := Map()
    minCells := opts["minCells"]
    maxBlobFrac := opts["maxBlobFrac"]


    minW2 := opts["minW"]
    minH2 := opts["minH"]
    blobSeen := 0
    blobLogged := 0
    blobLogCap := 80

    rejMinCells := 0
    rejTooBig := 0
    rejBBox0 := 0
    rejBBoxInvalid := 0
    rejBBoxFloodInvalid := 0
    rejSmallWH := 0
    dirs := [[1,0],[-1,0],[0,1],[0,-1]]

    parentCells := wCells*hCells
    parentW := rect.W
    parentH := rect.H

    ; Connected components on the interest mask -> candidate rects
    ; Sentinel guard: mask must be a valid object before flood-fill
    if !IsObject(mask) {
        LogError("F4 -> mask invalid", "F4")
        return false
    }
    maskSize := wCells*hCells

    Loop hCells {
        y0 := A_Index - 1
        Loop wCells {
            x0 := A_Index - 1
            idx0 := y0*wCells + x0 + 1
            if (idx0 <= 0 || idx0 > maskSize) {
                LogWarn("F4 skip invalid index idx0=" idx0 " size=" maskSize, "F4")
                continue
            }

            if (mask.Get(idx0, 0) != 1)
                continue
            if (visited.Has(idx0))
                continue

            q := [[x0, y0]]
            visited[idx0] := 1

            ; BBox in CELL space (sentinel init)
            minX := 9999
            minY := 9999
            maxX := -1
            maxY := -1
            cnt := 0

            while (q.Length) {
                p := q.Pop()
                cx := p[1]
                cy := p[2]
                cnt += 1

                if (cx < minX)
                    minX := cx
                if (cx > maxX)
                    maxX := cx
                if (cy < minY)
                    minY := cy
                if (cy > maxY)
                    maxY := cy

                for d in dirs {
                    nx := cx + d[1]
                    ny := cy + d[2]
                    if (nx < 0 || ny < 0 || nx >= wCells || ny >= hCells)
                        continue
                    nidx := ny*wCells + nx + 1
                    if (nidx <= 0 || nidx > maskSize) {
                        LogWarn("F4 skip invalid index nidx=" nidx " size=" maskSize, "F4")
                        continue
                    }

                    if (mask.Get(nidx, 0) != 1)
                        continue
                    if (visited.Has(nidx))
                        continue
                    visited[nidx] := 1
                    q.Push([nx, ny])
                }
            }
            blobSeen += 1
            if (minX > maxX || minY > maxY) {
                rejBBoxFloodInvalid += 1
                try {
                    Log("AL FATAL | bbox invalid after flood idx=" blobSeen " cnt=" cnt
                        " min=" minX "," minY " max=" maxX "," maxY, "ERROR", "AL")
                } catch {
                }
                continue
            }

            if (blobLogged < blobLogCap) {
                blobLogged += 1
                try {
                    Log("AL BLOB | idx=" blobSeen " size=" cnt " rect=" minX "," minY "," maxX "," maxY, "DEBUG", "AL")
                } catch {
                }
            } else if (blobLogged = blobLogCap) {
                blobLogged += 1
                try {
                    Log("AL BLOB | ... suppressed after " blobLogCap, "DEBUG", "AL")
                } catch {
                }
            }

            if (cnt < minCells) {
                rejMinCells += 1
                if (blobLogged <= blobLogCap) {
                    try {
                        Log("AL REJECT | minCells idx=" blobSeen " size=" cnt " need>=" minCells, "DEBUG", "AL")
                    } catch {
                    }
                }
                continue
            }

            bboxCells := (maxX - minX + 1) * (maxY - minY + 1)
            if (bboxCells <= 0) {
                rejBBox0 += 1
                if (blobLogged <= blobLogCap) {
                    try {
                        Log("AL REJECT | bbox<=0 idx=" blobSeen " bboxCells=" bboxCells, "DEBUG", "AL")
                    } catch {
                    }
                }
                continue
            }

            if (bboxCells > parentCells * maxBlobFrac) {
                rejTooBig += 1
                if (blobLogged <= blobLogCap) {
                    try {
                        Log("AL REJECT | tooBig idx=" blobSeen " bboxCells=" bboxCells " max=" Round(parentCells*maxBlobFrac, 0), "DEBUG", "AL")
                    } catch {
                    }
                }
                continue
            }

            density := cnt / bboxCells

            ; Guard: bbox can be thin/collapsed in cell space (still salvageable)
            if (minX = maxX || minY = maxY) {
                try {
                    Log("AL GUARD | BBox thin/collapsed-cells | min=" minX "," minY " max=" maxX "," maxY, "WARN", "AL")
                } catch {
                }
            }

            ; bbox cell->px (relative inside parent)
            cellW := (maxX - minX + 1)
            cellH := (maxY - minY + 1)
            L := minX * stride
            T := minY * stride
            R := L + (cellW * stride)
            B := T + (cellH * stride)

            ; bbox size in UI pixels (cells -> px)
            w := cellW * stride
            h := cellH * stride

            ; clamp to parent
            if (L < 0)
                L := 0
            if (T < 0)
                T := 0
            if (R > parentW)
                R := parentW
            if (B > parentH)
                B := parentH

            ; Salvage: avoid zero-size rect after clamp (boundary/off-by-one cases)
            if (R <= L) {
                if (parentW > L) {
                    R := Min(parentW, L + stride)
                } else if (parentW >= stride) {
                    R := parentW
                    L := Max(0, parentW - stride)
                }
            }

            if (B <= T) {
                if (parentH > T) {
                    B := Min(parentH, T + stride)
                } else if (parentH >= stride) {
                    B := parentH
                    T := Max(0, parentH - stride)
                }
            }

            w := R - L
            h := B - T
            if (w <= 0 || h <= 0) {
                rejBBoxInvalid += 1
                if (blobLogged <= blobLogCap) {
                    try {
                        Log("AL FATAL | BBox invalid after scale w=" w " h=" h " min=" minX "," minY " max=" maxX "," maxY " stride=" stride, "ERROR", "AL")
                    } catch {
                    }
                }
                continue
            }

            if (w < minW2 || h < minH2) {
                rejSmallWH += 1
                if (blobLogged <= blobLogCap) {
                    try {
                        Log("AL REJECT | size w=" w " h=" h " need>=" minW2 "," minH2, "DEBUG", "AL")
                    } catch {
                    }
                }
                continue
            }

            ; cheap prior: prefer "icon-ish" mid-size regions and moderate density
            area := w*h
            sizeScore := 0.0
            if (area >= 18*18 && area <= 170*170)
                sizeScore := 0.25
            else if (area >= 12*12 && area <= 220*220)
                sizeScore := 0.12

            densScore := AL_Clamp((density - 0.12) / 0.55, 0, 1) * 0.35
            s := 0.35 + densScore + sizeScore

            rectRel := __RectClass(L, T, R, B)
            cand := Candidate(rectRel, s, Map("cells", cnt, "density", density))
            candidates.Push(cand)
        }
    }

    ; sort desc (light)
    if (candidates.Length > 1)
        AL_ArraySort(candidates, (a,b) => (b.score > a.score) ? 1 : (b.score < a.score) ? -1 : 0)
    
    try {
        Log("AL L2 END | blobs=" blobSeen " cands=" candidates.Length
            " rejMinCells=" rejMinCells " rejTooBig=" rejTooBig " rejBBox0=" rejBBox0 " rejSmallWH=" rejSmallWH " rejBBoxFloodInvalid=" rejBBoxFloodInvalid " rejBBoxInvalid=" rejBBoxInvalid, "DEBUG", "AL")
    } catch {
    }
    return candidates
}
