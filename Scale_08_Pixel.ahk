; ==================================================================================================
;  MODULE 08 — Pixel
;  Source lines (original scale.ahk): 3559 – 3903
; ==================================================================================================



; ----------------------------
; Hook: pixel grid sampler (Layer2/3/4/5)
; Returns Map: wCells, hCells, stride, luma:Array(1-based), rgb:Array(1-based optional)
; ----------------------------
AL_Capture_ReadPixelGrid(screenRect, stride := 4) {
    local r, g, b

; IDOL FAST MODE: avoid PixelGetColor loops (very slow). Capture one bitmap and sample from memory.
try {
    global AL_IDOL_FAST_MODE
    if (AL_IDOL_FAST_MODE)
        return AL_Capture_ReadPixelGrid_IDOL(screenRect, stride)
} catch {
    ; if anything fails, fall back to legacy PixelGetColor sampler below
}    ; Accept Rect or Map with L/T/R/B
    if (!IsObject(screenRect))
        throw Error("AL_Capture_ReadPixelGrid(): bad rect")
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(screenRect, &L, &T, &R, &B))
        throw Error("AL_Capture_ReadPixelGrid(): bad rect")
    w := Max(1, R - L)
    h := Max(1, B - T)

    ; auto stride if too many samples
    maxSamples := 18000
    if (stride < 2)
        stride := 2
    est := Ceil(w/stride) * Ceil(h/stride)
    if (est > maxSamples) {
        s := Ceil(Sqrt((w*h) / maxSamples))
        if (s > stride)
            stride := s
        if (stride > 20)
            stride := 20
    }

    wCells := Ceil(w / stride)
    hCells := Ceil(h / stride)

    luma := []
    rgb  := []

    ; Sample at cell centers for stability
    Loop hCells {
        cy := A_Index - 1
        y := T + Min(h-1, cy*stride + Floor(stride/2))
        Loop wCells {
            cx := A_Index - 1
            x := L + Min(w-1, cx*stride + Floor(stride/2))
            col := 0
            try {
                col := PixelGetColor(x, y, "RGB")
            } catch {
                col := 0
            }

            ; col is 0xRRGGBB
            r := (col >> 16) & 0xFF
            g := (col >> 8) & 0xFF
            b := col & 0xFF
            ; integer luma (BT.601-ish)
            yv := (r*299 + g*587 + b*114) // 1000

            luma.Push(yv)
            rgb.Push(col)
        }
    }

    return Map("wCells", wCells, "hCells", hCells, "stride", stride, "luma", luma, "rgb", rgb)
}

AL_Capture_ReadPixelGrid_IDOL(screenRect, stride := 4) {
    ; Fast sampler:
    ; - CAPTURE ONCE (GDI+ bitmap)
    ; - LockBits 32bpp ARGB
    ; - Read sample pixels from Scan0 buffer (BGRA)
    ;
    ; Output format matches AL_Capture_ReadPixelGrid():
    ;   Map("wCells",..,"hCells",..,"stride",..,"luma",Array(),"rgb",Array())

    if (!IsObject(screenRect))
        throw Error("AL_Capture_ReadPixelGrid_IDOL(): bad rect")

    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(screenRect, &L, &T, &R, &B))
        throw Error("AL_Capture_ReadPixelGrid_IDOL(): bad rect")

    w := Max(1, R - L)
    h := Max(1, B - T)

    ; auto stride if too many samples (keep behavior similar to legacy)
    global AL_IDOL_FAST_MAX_SAMPLES
    if (stride < 2)
        stride := 2
    est := Ceil(w/stride) * Ceil(h/stride)
    if (est > AL_IDOL_FAST_MAX_SAMPLES) {
        stride := Ceil(Sqrt((w*h) / AL_IDOL_FAST_MAX_SAMPLES))
        if (stride < 2)
            stride := 2
    }

    wCells := Ceil(w / stride)
    hCells := Ceil(h / stride)

    luma := []
    rgb  := []
    luma.Capacity := wCells * hCells
    rgb.Capacity  := wCells * hCells

    ; Ensure GDI+ ready
    if (!EnsureGdip(true))
        throw Error("AL_Capture_ReadPixelGrid_IDOL(): GDI+ not ready")

    pBmp := 0
    try {
        ; Gdip_BitmapFromScreen supports "x|y|w|h"
        pBmp := Gdip_BitmapFromScreen(L "|" T "|" w "|" h)
    } catch {
        pBmp := 0
    }
    if (!pBmp)
        throw Error("AL_Capture_ReadPixelGrid_IDOL(): capture failed")

    ; LockBits (32bpp ARGB)
    rect := Buffer(16, 0)
    NumPut("int", 0, rect, 0)
    NumPut("int", 0, rect, 4)
    NumPut("int", w, rect, 8)
    NumPut("int", h, rect, 12)

    bmpData := Buffer(16 + (A_PtrSize*2), 0) ; Width,Height,Stride,PixelFormat,Scan0,Reserved
    PixelFormat32ARGB := 0x26200A
    ImageLockModeRead := 0x0001

    ok := 0
    try {
        ok := DllCall("gdiplus\GdipBitmapLockBits"
            , "ptr", pBmp
            , "ptr", rect
            , "uint", ImageLockModeRead
            , "int", PixelFormat32ARGB
            , "ptr", bmpData
            , "int")
    } catch {
        ok := -1
    }

    if (ok != 0) {
        try {
            Gdip_DisposeImage(pBmp)
        } catch {
        }
        throw Error("AL_Capture_ReadPixelGrid_IDOL(): LockBits failed hr=" ok)
    }

    strideBytes := NumGet(bmpData, 8, "int")
    scan0 := NumGet(bmpData, 16, "ptr")

    ; Handle negative stride (rare)
    flip := false
    if (strideBytes < 0) {
        strideBytes := -strideBytes
        flip := true
    }

    ; Sample centers like legacy: cx*stride + Floor(stride/2)
    global AL_IDOL_L3_YIELD_EVERY
    sampleCnt := 0
    mid := Floor(stride/2)

    Loop hCells {
        cy := A_Index - 1
        yy := Min(h-1, cy*stride + mid)
        y := flip ? (h-1-yy) : yy
        row := scan0 + (y * strideBytes)

        Loop wCells {
            cx := A_Index - 1
            x := Min(w-1, cx*stride + mid)
            px := row + (x * 4)

            ; BGRA in memory
            b := NumGet(px, 0, "UChar")
            g := NumGet(px, 1, "UChar")
            r := NumGet(px, 2, "UChar")
            ; a := NumGet(px, 3, "UChar") ; not needed

            col := (r << 16) | (g << 8) | b
            yv := (r*299 + g*587 + b*114) // 1000

            luma.Push(yv)
            rgb.Push(col)

            sampleCnt += 1
            if (AL_IDOL_L3_YIELD_EVERY > 0 && Mod(sampleCnt, AL_IDOL_L3_YIELD_EVERY) = 0)
                Sleep(-1) ; yield to keep GUI responsive
        }
    }

    ; Unlock + dispose
    try {
        DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pBmp, "ptr", bmpData)
    } catch {
    }
    try {
        Gdip_DisposeImage(pBmp)
    } catch {
    }

    return Map("wCells", wCells, "hCells", hCells, "stride", stride, "luma", luma, "rgb", rgb)
}



; ----------------------------
; Default Options
; ----------------------------
AL_DefaultOpts() {
    o := Map()

    ; Layer 2: segmentation (explicit)
    ; NOTE (small-outline objects like "diamond"):
    ;  - stride=4 can skip thin borders
    ;  - edgeThresh=28 can be too strict for anti-aliased UI outlines
    ;  - minCells=12 can drop tiny outline clusters
    ; Use more permissive defaults and rely on later filtering/NMS.
    o["stride"] := 2                 ; downsample step (px)
    o["edgeThresh"] := 20            ; contrast threshold (luma diff)
    o["varThresh"] := 12             ; deviation-from-neighbors threshold (lower helps thin/AA outlines like diamond)
    o["dilate"] := 2                 ; thicken mask to close gaps (2 helps connect thin outlines)
    o["minCells"] := 6               ; blob min size (cells)
    o["maxBlobFrac"] := 0.65         ; reject blobs covering too much of parent

    ; Layer 3: filtering
    o["minW"] := 8
    o["minH"] := 8
    o["maxW"] := 260
    o["maxH"] := 260
    o["minScore"] := 0.30
    o["ratioMax"] := 6.0
    o["ratioMin"] := 0.2
    o["bgContrastMin"] := 8         ; reject near-flat background
    o["textTransHigh"] := 0.30       ; text-like transition density
    o["allowTextStrip"] := false    ; allow textstrip ROI (default off)
    o["nmsIou"] := 0.55              ; non-max suppression overlap
    o["keepTop"] := 40               ; cap results after NMS

    ; Stability (cheap, no-ML): filter out animated/noisy areas
    o["stabEnabled"] := 1
    o["stabDelayMs"] := 70
    o["stabPixelDiff"] := 10
    o["stabMaxDelta"] := 0.12

    ; Layer 4: extraction
    o["anchorsK"] := 6              ; number of anchors
    o["anchorTol"] := 45            ; default tolerance
    o["templatePad"] := 3           ; pad when cropping template

    ; Layer 5: behavior
    o["behPad"] := 6                ; expand ROI margin
    o["behBorderRing"] := 3         ; ring thickness for borderDelta
    o["behPixelDiff"] := 24         ; per-pixel luma diff threshold
    o["behSamples"] := 2            ; reserved (future multi-sample)
    o["behTryTopK"] := 2            ; try top-K candidates by behavior before finalizing
    o["behMinDelta"] := 0.025       ; minimal meaningful deltaPct to call it "state change"
    o["behMinBorder"] := 0.012

    return o
}

; Safe array/map getter: returns default if idx/key is missing or out of range
AL_ArrGet(arr, idx, default := 0) {
    if !IsObject(arr)
        return default
    if (idx < 1)
        return default

    len := 0
    try {
        len := arr.Length
    } catch {
        len := 0
    }

    if (len > 0 && idx > len)
        return default

    v := default
    try {
        v := arr[idx]
    } catch {
        v := default
    }
    return v
}


; ============================================================
; Helpers (geometry, anchors, diff)
; ============================================================
AL_RelToScreen(parentRect, relRect) {
    ; Khuyên nhủ (tránh crop bị cụt mép):
    ; rectRel thường theo kiểu inclusive (R/B là pixel cuối). Khi đổi sang screenRect để capture/crop,
    ; cộng +1 cho R/B để bao trọn icon, rồi tiếp tục áp pad + clamp ở bước capture.
    return Rect(parentRect.L + relRect.L
              , parentRect.T + relRect.T
              , parentRect.L + relRect.R + 1
              , parentRect.T + relRect.B + 1)
}



SetStatus(msg) {
    global stStatus
    stStatus.Text := "Status: " msg
}



; ======================================================================
; GUI STATE MACHINE (theo state, có tổng thời gian + timeout)
; - Mục tiêu: GUI đổi trạng thái NGAY khi state đổi, không "đơ 10–20s"
; - Không dùng loop while để repaint; dùng SetTimer heartbeat nhẹ
; ======================================================================

UI__Heartbeat() {
    global UI_HEARTBEAT_ON, UI_STATE
    if (!UI_HEARTBEAT_ON)
        return
    ; Chỉ cần refresh khi đang WAIT (để thấy elapsed tăng)
    if (UI_STATE = "WAIT") {
        try {
            UI_UpdateGui(true)
        } catch {
        }
        try {
            UI_CheckTimeout()
        } catch {
        }
    }
}

