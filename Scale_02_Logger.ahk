; ==================================================================================================
;  MODULE 02 — Logger
;  Source lines (original scale.ahk): 514 – 998
; ==================================================================================================
; F3 MULTI-ICON SPLIT (2 icon → 2 template images)
; ===============================
; NOTE (IDOL DEV):
; - Nếu parent region (F3) chứa 2 icon mà chỉ ra 1 ảnh: thường do minCells/minW/minH quá cao hoặc dilate/NMS làm dính/loại bớt blob.
; - Multi-icon mode sẽ:
;     ✔ giảm minCells/minW/minH để không drop icon nhỏ
;     ✔ dilate=0 để 2 icon không dính blob
;     ✔ nmsIou=0.99 (gần như tắt NMS) để không loại ROI overlap
;     ✔ lưu thêm tpl_elem_2 / tpl_elem_3 ... từ cùng 1 ảnh parent
global F3_MULTI_ICON := true          ; bật multi-icon khi AutoLearn (F4) chạy trên parent vùng F3
global AL_MULTI_MIN_W := 6
global AL_MULTI_MIN_H := 6
global AL_MULTI_MIN_CELLS := 3
global AL_MULTI_DILATE := 0
global AL_MULTI_DISABLE_NMS := true
global AL_MULTI_SAVE_EACH := true     ; save thêm tpl cho từng ROI (idx>=2)
global AL_MULTI_RELAX_L3 := true       ; nới L3 filter khi multi-icon (tránh drop cả 2 icon)
global AL_MULTI_H_TRANS_MAX := 0.45    ; nâng ngưỡng hTrans (default 0.30) để icon UI không bị coi là "text"
global AL_MULTI_ALLOW_TEXTSTRIP := true ; cho phép ROI dạng "wide/short" (tránh nhầm icon nhỏ thành textstrip)


; ===============================
; F3 ROI ORDERING LAYER (GUI + CLICK ORDER)
; ===============================
; Mục tiêu: khi F3 parent chứa 2+ icon (multi-icon), ta có danh sách ROI theo THỨ TỰ,
; GUI có thể sắp xếp (LTR/RTL/TTB/BTT/Score/Size), mỗi ROI có click mode riêng (Click/Double),
; và có thể preview highlight + click theo thứ tự.
;
; Lưu ý: bạn KHÔNG cần hiểu L2/L3. Chỉ cần nhìn GUI: ROI #1, #2,... và chọn order/mode.

global F3_SORT_MODE := "LTR"          ; LTR|RTL|TTB|BTT|SCORE|AREA
global F3_ROI_LIST := []              ; array of roi items (sorted)
global F3_ROI_PARENT_RECT := 0        ; last parent Rect used to build ROIs (screen coords)
global F3_ROI_SELECTED := 1           ; selected ROI index in GUI



DBG__ShouldSaveTpl(pipeMode := "", force := false) {
    global DEBUG_SAVE_IMAGE, DEBUG_SAVE_EVERY, DBG_SAVE_CNT

    if (force)
        return true

    ; F3: setup/learn → luôn save để soi ROI
    if (pipeMode = "F3")
        return true

    if (!DEBUG_SAVE_IMAGE)
        return false

    ; Throttle: mỗi N vòng save 1 lần
    DBG_SAVE_CNT += 1
    if (DEBUG_SAVE_EVERY <= 1)
        return true
    return (Mod(DBG_SAVE_CNT, DEBUG_SAVE_EVERY) = 0)
}

DBG__MakeUniqueBmpPath(prefix := "tpl") {
    global DBG_SAVE_SEQ
    ; F4 ordered capture: prefix dạng "f4_001" → tên theo thứ tự, không timestamp, không ghi đè
    if (RegExMatch(prefix, "^f4_\d{3}$")) {
        return A_ScriptDir "\\" prefix ".bmp"
    }
    DBG_SAVE_SEQ += 1
    ts := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    ms := A_MSec
    return A_ScriptDir "\\" prefix "_" ts "_" ms "_" DBG_SAVE_SEQ ".bmp"
}

F4__InitIndexOnce() {
    global g_F4_Index, g_F4_InitDone
    if (g_F4_InitDone)
        return
    g_F4_InitDone := true

    max := 0
    Loop Files A_ScriptDir "\\f4_*.bmp" {
        if RegExMatch(A_LoopFileName, "^f4_(\d+)\.bmp$", &m) {
            n := m[1] + 0
            if (n > max)
                max := n
        }
    }
    g_F4_Index := max
}


; ======================================================================
; ⚠️  AHK v2 – LỜI NHẮN NHỦ BẮT BUỘC KHI VÁ / CHỈNH SỬA FILE NÀY
; ======================================================================
; File này chạy trên AutoHotkey v2.x. Mọi chỉnh sửa PHẢI TUÂN THEO.
; ❌ Vi phạm bất kỳ điều nào → dễ dính lỗi cú pháp (compile-time) hoặc phá flow.
;
; ----------------------------------------------------------------------
; 1) TUYỆT ĐỐI KHÔNG DÙNG GOTO / LABEL / GOSUB
; ----------------------------------------------------------------------
; ❌ Cấm:  Goto Label, Gosub, Label:
; 👉 AHK v2 cấm Goto “nhảy vào trong” block { } và rất dễ lỗi:
;    "A Goto must not jump into a block that doesn't enclose it"
; ✅ Thay bằng: if/else + return sớm (early return) + function nhỏ.
;
; ----------------------------------------------------------------------
; 2) IF / ELSE LUÔN DÙNG BLOCK { } (TRÁNH ELSE LỆCH)
; ----------------------------------------------------------------------
; ❌ Tránh kiểu 1-dòng dễ sinh: "Unexpected Else" / "Missing }"
; ✅ Chuẩn:
;     if (cond) {
;         ...
;     } else {
;         ...
;     }
;
; ----------------------------------------------------------------------
; 3) TRY / CATCH CHỈ DÙNG DẠNG BLOCK (AHK v2)
; ----------------------------------------------------------------------
; ✅ Chuẩn duy nhất trong file này:
;     try {
;         ...
;     } catch {
;         ...
;     }
; (Không dùng catch e, không dùng one-line try/catch)
;
; ----------------------------------------------------------------------
; 4) NGUYÊN TẮC ROUTE CAPTURE: SCREEN LÀ NHÁNH CỤT (TERMINAL BRANCH)
; ----------------------------------------------------------------------
; Nếu srcMode = "SCREEN":
;   ✔ Tạo bitmap RIÊNG
;   ✔ Log ROUTE rõ ràng
;   ✔ return ngay (cắt nhánh)
;   ❌ Không được rơi xuống HWND/GDI/DXGI, không PrintWindow, không dùng bmpBase chung.
;
; ----------------------------------------------------------------------
; 5) KHÔNG REFACTOR – KHÔNG ĐỤNG CÁC KHỐI “LÕI”
; ----------------------------------------------------------------------
; 🔒 Không đụng: AL / scoring / grid, F3 pick, INI/history, thứ tự log cũ.
; ✅ Chỉ được: thêm chặn nhánh, thêm return sớm, thêm log ROUTE/WHY.
;
; ----------------------------------------------------------------------
; 6) SAU KHI SỬA PHẢI TỰ CHECK 3 LỖI CÚ PHÁP HAY GẶP
; ----------------------------------------------------------------------
; - Missing "}"
; - Unexpected "Else"
; - Goto must not jump into a block
; ======================================================================

; --- #Warn discipline (DEV/RELEASE) ---
; DEV: keep #Warn All ON.
; If you still have legacy LocalSameAsGlobal warnings you haven't fixed yet, you may TEMPORARILY enable the next line:
; #Warn LocalSameAsGlobal, Off
; RELEASE (optional): comment out #Warn All.


#SingleInstance Force

#UseHook True

; ---- Unified log file (all WARN/DEBUG/RUNTIME in one place) ----
;
; ============================================================
; 🧠 PIPELINE STATE MACHINE – F3 LEARN → F4 MATCH (IDOL DEV)
; ============================================================
; Đây là pipeline trạng thái (state) để AI/dev hiểu flow mà KHÔNG vá sai tầng.
;
; F3 (SETUP / LEARN MODEL):
;   [INPUT_ACQUIRE]  → lấy dữ liệu gốc (parent/ROI/rect/hwnd)
;   [SEGMENTING]     → crop ROI (bmpCrop) theo rectRel/rectAbs
;   [FILTERING]      → chuẩn hóa/lọc nhiễu (mask/edge/contrast)
;   [BEHAVIOR]       → kiểm tra hình học (w/h/ratio/blob sanity)
;   [EXTRACT_MODEL]  → trích đặc trưng (grid/mask/blob/edge stats)
;   [SAVE_MODEL]     → lưu model/signature (INI/history/AL_LAST)
;
; F4 (RUN / MATCH MODEL):
;   [INPUT_ACQUIRE]  → chụp ROI hiện tại (FAST: SCREEN ROI-only)
;   [SEGMENTING]     → crop/confirm ROI bitmap (ROI-only)
;   [FILTERING]      → filter nhanh (FAST: stride>=2, minCells>=6)
;   [MATCHING]       → so khớp với model đã học (F3)
;   [DECISION]       → PASS/FAIL (score)
;   [ACTION]         → click/key/drag theo kịch bản
;
; Quy tắc:
; - Mỗi STATE chỉ làm 1 việc.
; - Không nhảy bước, không click trong state phân tích.
; - FAST MODE (F4): KHÔNG PrintWindow, KHÔNG DXGI, KHÔNG full rect.
; ============================================================

LOG_FILE := A_ScriptDir "\error.log"


; ---- Capture debug master toggles ----
; Set CAP_DEBUG := false to mute CAP | ... logs.
CAP_DEBUG := true
; Deep mode prints RAWRECT before/after normalization and extra fallbacks.
CAP_DEBUG_DEEP := false

; Use DXGI Desktop Duplication exe (dxgi_cap.exe) before GDI capture.
global CAP_USE_DXGI := true
; ============================================================
; Integration Hooks (replace with real code)
; ============================================================

; ============================================================
; AutoLearn UI Element - 5 Layers (embedded from AutoLearn_5Layers_AHKv2.ahk)
; Hooked into ScaleCycle (AHK v2)
; Hotkey: F4 => run auto-learn on current parent region (or prompt to set it)
; ============================================================

global AL_LAST := Map() ; holds last learn result: model, sig, stats

global AL_FAST_MODE := false ; F4 FAST flag (ROI-only, avoids full pixel scan)
global AL_IDOL_FAST_MODE := true  ; ✅ IDOL FAST MODE: use single bitmap + LockBits sampling (no PixelGetColor loops)
global AL_IDOL_FAST_MAX_SAMPLES := 18000 ; cap to auto-increase stride if region is big
global AL_IDOL_L3_YIELD_EVERY := 2500 ; yield every N sampled pixels in extreme cases
global AL_IDOL_LEARN_MAX_MS := 800    ; shorten learn window when idol fast mode is ON (ms)
; ============================================================
; GLOBALS – 5 LAYER + GLUE + GUI (IDOL DEV)
; -------- GUI MODE (Overlay mờ + click-through) --------
; Policy mới: KHÔNG hide/show GUI cho F3/F4. Chỉ đổi MODE:
;   RUN  = GUI mờ + click-through (không chặn chuột)
;   EDIT = GUI rõ nét + nhận chuột để chỉnh ROI
global GUI_MODE := "EDIT"         ; "RUN" | "EDIT"
global GUI_OPA_RUN := 120         ; độ mờ khi RUN (0-255)
global GUI_OPA_EDIT := 255        ; rõ nét khi EDIT
global GUI_HOT_X := 10            ; vị trí hotspot (px)
global GUI_HOT_Y := 10
global GUI_HOT_W := 44            ; kích thước hotspot
global GUI_HOT_H := 44
global gHot := 0                  ; HWND GUI hotspot (cửa sổ riêng)

; Capture overlay hide policy (deprecated)
global GUI_HIDE_DURING_CAPTURE := false ; để false: KHÔNG hide GUI/border khi capture

; ============================================================

; -------- L1: ROI MAP --------
global ROI_LIST := []          ; danh sách ROI theo thứ tự kịch bản
global ROI_COUNT := 0          ; số ROI hiện có

; ===== ROI DATA (current pointer) =====
global ROI_CUR_IDX := 0
global ROI_CUR_RECT := ""
global ROI_CUR_NAME := ""

; ===== UI STATE ROI (MULTI-ROI) =====
global ROI_STATE := ""            ; LOADING | READY | ERROR | UNKNOWN
global ROI_LOADING := 0           ; index ROI loading (optional)
global ROI_READY := 0             ; index ROI ready   (optional)
global ROI_ERROR := 0             ; index ROI error   (optional)

; -------- L0/L4: LOGIC GLUE / STEP CONTROLLER --------
global STEP_IDX := 0
global STEP_MAX := 0
global STEP_RETRY := 0
global STEP_RETRY_MAX := 3
global STEP_DONE := false
global STEP_WAIT_MS := 300
global STEP_TIMEOUT_MS := 5000
global STEP_START_TICK := 0

; -------- L5: ACTION --------
global ACTION_ENABLED := true
global ACTION_PENDING := false
global ACTION_DONE := false
global ACTION_LAST := ""
global CLICK_DELAY_MS := 50
global AFTER_ACTION_DELAY_MS := 200

; ===== FAST MODE / F4 (HIỆU NĂNG) =====
global FAST_MAX_CHECK := 3
global FAST_CHECK_CNT := 0

; ===== EVENT WAIT (EVENT-DRIVEN) =====
global EVT_WAIT_BASE_MS := 120
global EVT_WAIT_ANIM_MS := 300
global EVT_LAST_ACTION_TICK := 0
global EVT_WAIT_DONE := true


; ===== AUTO-LEARNING WINDOW (F4 BEHAVIOR) =====
; Mục tiêu: vẫn học hành vi (behValid), nhưng KHÔNG học vô hạn 10–20s.
global LEARN_ACTIVE := false         ; đang trong phiên learning (sau ACTION)
global LEARN_START_TICK := 0         ; tick bắt đầu phiên learning
global LEARN_MAX_MS := 3000          ; giới hạn thời gian học (ms)

global LEARN_LOOP_CNT := 0           ; đếm số vòng refine/behavior test
global LEARN_LOOP_MAX := 20          ; giới hạn vòng học (anti-infinite)

global LEARN_BEH_VALID := false      ; behValid đã đạt chưa
global LEARN_LOCKED := false         ; đã khóa model/behavior để khỏi học lại
global LEARN_ABORT := false          ; timeout/overloop → abort learning

global LEARN_TRIGGER_ACTION := ""    ; click/drag/key (để log/diag)
global LEARN_LAST_ACTION_TICK := 0   ; tick ACTION kích hoạt learning
global HAS_ACTION_SINCE_PICK := false  ; đã có ACTION thật kể từ lần F3 pick gần nhất
; -------- L2: CAPTURE --------
global CAP_FAST_MODE := false         ; F4 FAST: chỉ chụp ROI (không full parent)
global RUN_HIDE_GUI := false          ; (deprecated) KHÔNG dùng hide GUI nữa – dùng GUI_MODE RUN/EDIT
global CAP_HIDE_GUI := false          ; nội bộ capture: có hide hay không (do mode set)
global CAP_SRC_MODE := ""             ; "HWND"/"SCREEN"/"DXGI" (log/diagnostic)

; -------- PIPELINE STATE (F3 LEARN / F4 MATCH) --------
; NOTE: Chỉ dùng để debug/định hướng. Không bắt buộc set hết mọi biến.
global PIPE_MODE := ""                 ; "F3" | "F4"
global PIPE_STATE := "WAIT"            ; WAIT | CHECK | DECIDE | ACTION
global PIPE_LAST_ACTION := ""          ; click / key / drag / cycle
global PIPE_LAST_TICK := 0
global PIPE_STAGE_IDX := 0
global PIPE_TRACE_ID := ""             ; id để correlate log (nếu cần)


; ===== GUI STATE MACHINE (HIỂN THỊ TRẠNG THÁI + TỔNG THỜI GIAN) =====
; NOTE: Đây chỉ là "bảng đồng hồ" cho GUI, KHÔNG thay đổi thuật toán AL/CAP.
; Nếu gặp lỗi cú pháp kiểu "Unexpected }" thường do copy/paste làm DƯ/THIẾU dấu { }.
; Quy tắc vàng:
;   - Mỗi function() { ... } phải có ĐÚNG 1 dấu "}" đóng.
;   - KHÔNG để code tiếp ngay sau "}" trên cùng 1 dòng (vd: "} try {" là SAI).
;   - Khi vá, chỉ sửa 1 khu vực, không dán chồng 2 phiên bản UI_* lên nhau.
global UI_STATE := "IDLE"              ; IDLE | WAIT | CHECK | DECIDE | ACTION | TIMEOUT | STOP
global UI_STATE_REASON := ""           ; text ngắn: behValid=0 / evtwait / roi=...
global UI_STATE_SINCE_TICK := 0        ; tick bắt đầu state hiện tại
global UI_STATE_TIMEOUT_MS := 0        ; 0 = không timeout
global UI_RUN_SINCE_TICK := 0          ; tick bắt đầu RUN (ToggleRun ON)
global UI_LAST_GUI_STATE := ""         ; throttle repaint
global UI_LAST_GUI_REASON := ""
global UI_LAST_GUI_TICK := 0
global UI_HEARTBEAT_ON := false        ; SetTimer heartbeat để refresh elapsed khi WAIT
global UI_HEARTBEAT_MS := 200          ; 200ms là đủ mượt, không spam GUI
global UI_WAIT_FALLBACK_TIMEOUT_MS := 15000  ; fallback nếu WAIT không rõ ai (ms)

; ===== GLUE (chống flow chồng) =====
global GLUE_LOCK := false
global GLUE_NEXT_ALLOWED := true

; ===== SAFETY =====
global IS_RUNNING := false
global IS_STOP_REQUEST := false

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



; ----------------------------
; Hook: capture to BMP/PNG (Layer1/4/5)
; Uses minimal GDI+ to save bitmap to file
; ----------------------------
global GdipToken := 0


; =========================================================
; LAYER 7 — Compiler Structure Lock
; Core đứng TRÊN – Logic đứng GIỮA – UI đứng DƯỚI
; (Reordered automatically to satisfy your checklist)
; =========================================================

; -------------------------
; CORE / SHARED UTILITIES
; -------------------------


; =========================================================
; Utils
; =========================================================
; =========================================================
; INI SAFE GUARDS (no-crash if INI missing/locked/corrupt)
; =========================================================

; -------- Debug log --------
; All logs (DEBUG/WARN/ERROR + runtime errors) go to: error.log
IsLogLevel(x) {
    return (x = "INFO" || x = "WARN" || x = "ERROR" || x = "DEBUG" || x = "TRACE")
}

Log(msg, level := "INFO", src := "") {
    global LOG_FILE
    try {
        ; Backward-compat: old calls were Log(msg, func) or Log(msg, func, ctx)
        if (src = "" && level != "" && !IsLogLevel(level)) {
            src := level
            level := "DEBUG"
        } else if (src != "" && !IsLogLevel(level)) {
            msg := msg " | " src
            src := level
            level := "DEBUG"
        }

        line := A_Now " | " level " | " (src ? src " | " : "") msg "`n"
        FileAppend(line, LOG_FILE, "UTF-8")
    } catch {
    }
}

LogWarn(msg, src := "WARN") {
    Log(msg, "WARN", src)
}

LogError(msg, src := "ERROR") {
    Log(msg, "ERROR", src)
}

; -------- Global runtime error logger --------
LogRuntimeError(e, mode) {
    msg := ""
    try {
        msg := "ERR=" e.Message " | File=" e.File " | Line=" e.Line " | What=" e.What " | Mode=" mode
    } catch {
        try {
            msg := "ERR=" e.Message " | Mode=" mode
        } catch {
            msg := "ERR=<unknown> | Mode=" mode
        }
    }
    Log(msg, "ERROR", "RUNTIME")
    ; Return 0 to keep the default error dialog (so Continue works when supported).
    return 0
}

; Register runtime error logger as early as possible (before Init()).
OnError(LogRuntimeError)
OnExit(AL_GdipShutdown)
; -------- Safe wrapper for DllCall (no throw, logs once per call) --------
SC_DllCall(fn, params*) {
    try {
        return DllCall(fn, params*)
    } catch as e {
        ; best effort logging (never throw)
        try {
            Log("DllCall FAIL: " fn " | err=" e.Message, "ERROR", "DLL")
        } catch {
        }
        return 0
    }
}


; -------- Sentinel validators --------
SC_IsMap(x) {
    return IsObject(x) && (x is Map)
}

SC_IsArray(x) {
    return IsObject(x) && (x is Array)
}

