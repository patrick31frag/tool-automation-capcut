; ==================================================================================================
;  CapCut Scale Tool (AHKv2) — IN-PLACE PATCH DIRECTIVES
; --------------------------------------------------------------------------------------------------
;  @PATCH_MODE        : IN_PLACE              ; vá trực tiếp trên chính file này
;  @OUTPUT            : SAME_FILE             ; output = chính file hiện tại
;  @NO_PATCH_FILE     : TRUE                  ; không tạo file *_PATCHED.ahk / *_VAXXX.ahk
;  @ALLOW_OVERWRITE   : TRUE                  ; cho phép ghi đè nội dung file hiện tại
;  @BACKUP            : FALSE                 ; không tạo backup (đổi TRUE nếu muốn .bak)
;
;  @ENGINE_POLICY     : IMMUTABLE             ; engine core KHÔNG được sửa
;  @PATCH_SCOPE       : PATCHABLE_ZONE_ONLY   ; chỉ vá trong vùng cho phép (marker)
;  @HOTKEY_POLICY     : PRESERVE              ; bảo toàn phím tắt/hotkey
;  @STATE_POLICY      : PRESERVE              ; bảo toàn state / config
;
;  @PATCH_TARGET      : %A_ScriptFullPath%    ; mục tiêu vá mặc định = file đang chạy
;  @PATCH_NOTE        : "In-place patch requested by user; do not emit new file."
; --------------------------------------------------------------------------------------------------
;  SAFETY:
;   - Tuyệt đối KHÔNG sửa ENGINE_CORE (nếu có).
;   - Chỉ được thay nội dung trong vùng PATCHABLE_ZONE (nếu có marker).
;   - Nếu không thấy marker, KHÔNG tự ý chèn lung tung — phải tạo marker trước rồi mới vá.
; ==================================================================================================

#Requires AutoHotkey v2.0
#Include <Gdip_All>

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

__SelfLint_Boot()
OnError(__OnError)

; PATCHABLE_ZONE__BOOT_LINT_END
; ============================================================


; ======================================================================
; AI_SAFEZONE100_BEGIN
; Plain-ASCII safety markers for stable patching + stable runtime.
; RULES (read once, then follow):
;   1) Do NOT insert markers/comments inside control headers or expressions.
;      Bad: if (x ; marker)  |  Good: put marker on its own line.
;   2) Prefer edits ONLY inside clearly marked SAFE modules.
;   3) try/catch MUST be block form: try { ... } catch { ... } (or catch as e { ... }).
;   4) Never use 'return <value>' in the auto-execute (global) section.
;   5) Markers MUST stay as plain ASCII (no emoji) to avoid encoding parser issues.
; AI_SAFEZONE100_END
; ======================================================================


; SAFEZONE PATCH (2026-01-02): Converted 43 one-line try statements to block try { } catch { } to prevent AHK v2 syntax pitfalls.
; ======================================================================================================================
; 🧠 AHK v2 — SYNTAX GUARD (COMMENT + HELPER FUNCTIONS)  |  KHÔNG CHẠY, KHÔNG ẢNH HƯỞNG LOGIC
; ======================================================================================================================
; MỤC TIÊU:
; - Ghi chú “khuyên nhủ” để tránh các lỗi cú pháp AHK v2 hay dính (đặc biệt các lỗi bạn đã gặp: Return ret, Else, Missing "}")
; - Thêm vài helper function chỉ chứa comment (KHÔNG BAO GIỜ được gọi), như “tài liệu sống” ngay trong file.
;
; QUY TẮC VÀNG AHK v2 (dễ dính lỗi nhất):
; 1) ✅ Return ngoài function: CHỈ được "Return" trống (kết thúc auto-execute). ❌ Không được "Return value".
;    - Sai (global / auto-execute):
;         ret := 1
;         Return ret              ; ❌ Error: Return's parameter should be blank except inside a function.
;    - Đúng:
;         ; (A) kết thúc auto-execute:
;         Return                  ; ✅ OK
;         ; (B) cần trả về giá trị -> phải đưa vào function:
;         MyFunc() {
;             ret := 1
;             return ret          ; ✅ OK
;         }
;
; 2) ✅ Else PHẢI “dính” ngay sau If tương ứng (cùng block). ❌ Không được đặt Else sau khi đã đóng block sai chỗ.
;    - Sai (thường gây "Unexpected Else"):
;         if (ok) {
;             ...
;         }
;         Else                    ; ❌ Else đứng lẻ (không attach được)
;             ...
;    - Đúng:
;         if (ok) {
;             ...
;         } else {
;             ...
;         }
;
; 3) ✅ Dấu ngoặc nhọn { } phải cân. Thiếu 1 dấu } là nổ "Missing '}'".
;    - Tip: bật bracket-matching trong editor, hoặc search "{", "}" để đếm block khi nghi ngờ.
;
; 4) ✅ try/catch AHK v2: nên dùng DẠNG BLOCK (đúng yêu cầu dự án của bạn).
;    - Đúng:
;         try {
;             ...
;         } catch {
;             ...
;         }
;    - Tránh one-line / bắt kiểu v1.
;
; 5) ✅ Toán tử "ASSIGN" vs "COMPARE":
;    - GÁN:     x := 123
;    - SO SÁNH: x = 123     (so sánh, thường case-insensitive với chuỗi)
;              x == 123    (so sánh chặt hơn / case-sensitive với chuỗi)
;    - Lỗi hay gặp: viết if (x := 1) thì nó gán luôn -> điều kiện luôn true.
;
; 6) ✅ Nếu dùng biến global trong function, phải khai báo rõ:
;         global gVar
;    - Không khai báo -> có thể thành local, gây lỗi logic khó thấy (không phải cú pháp nhưng rất hay nhầm).
;
; 7) ✅ Gọi function bắt buộc có ngoặc:
;    - Đúng:  Foo()
;    - Sai:   Foo           ; (v2 không “đoán” như v1, dễ phát sinh lỗi/hiểu nhầm)
;
; 8) ✅ Lệnh If/While/For trong v2 dùng biểu thức (expression). Hạn chế dùng kiểu legacy.
;
; 9) ✅ String literal & escape:
;    - Dùng "..." cho chuỗi; dùng `"` để chèn dấu nháy kép.
;    - Backtick ` là ký tự escape chính.
;
; 10) ✅ Khi ghép chuỗi + biến, nhớ dùng toán tử hoặc Format():
;      s := "A=" a " B=" b     ; ✅ concat theo expression
;      s := Format("A={1} B={2}", a, b)
;
; 11) ✅ Dấu phẩy trong function call / array:
;      arr := [1, 2, 3]
;      m := Map("k", "v")
;
; 12) ✅ Với object / map: dùng [] cho index, "." cho property.
;      v := obj["key"]
;      x := obj.Prop
;
; 13) ✅ Các lỗi “hay nổ chương trình” khác:
;      - Gọi biến/hàm chưa tồn tại (NameError)
;      - Thiếu ngoặc đóng ) trong call / expression
;      - Dùng `and/or/not` sai chỗ (nên dùng && || !)
;      - Dính dấu `:`/`?` sai trong ternary (cond ? a : b)
;
; ======================================================================================================================
; ⚙️ HELPER FUNCTIONS (CHỈ LÀ TÀI LIỆU - KHÔNG GỌI)
; ======================================================================================================================
__AHKv2_Syntax_Guard__DO_NOT_CALL() {
    ; KHÔNG BAO GIỜ gọi function này.
    ; Mục đích: làm “neo” để bạn search nhanh trong file: "SYNTAX GUARD", "DO_NOT_CALL", "__WARN_"
    ;
    ; Nếu muốn kiểm tra nhanh cú pháp:
    ; - Lỗi Return ret: tìm "Return " + giá trị ngoài function
    ; - Lỗi Unexpected Else: tìm "Else" và xem nó có dính ngay sau "if" không
    ; - Lỗi Missing "}": tìm block mới mở gần nhất trước dòng báo lỗi
    return
}

__WARN_Return_Outside_Function__DO_NOT_CALL() {
    ; ✅ Auto-execute (global scope) chỉ cho phép: Return (trống)
    ; ❌ Không được: Return value
    ; Nếu cần “báo kết quả”: đặt logic vào function rồi return trong function.
    return
}

__WARN_Else_Attach_Rule__DO_NOT_CALL() {
    ; ✅ else phải đi kèm if ngay lập tức:
    ; if (...) {
    ; } else {
    ; }
    ; ❌ Tránh:
    ; if (...) { }
    ; Else
    return
}

__WARN_TryCatch_BlockOnly__DO_NOT_CALL() {
    ; ✅ Chuẩn dự án: try { ... } catch { ... }
    ; Không dùng one-line.
    return
}

__WARN_Brace_Balance__DO_NOT_CALL() {
    ; ✅ Mỗi { phải có một } tương ứng.
    ; Tip: khi gặp Missing "}", hãy:
    ; - nhìn lên trên: block nào mới mở mà chưa đóng?
    ; - kiểm tra các chỗ "if {" / "try {" / "loop {" / "for {" / "while {"
    return
}

__WARN_Assign_VS_Compare__DO_NOT_CALL() {
    ; ✅ GÁN: :=   | ✅ SO SÁNH: = hoặc ==
    ; Tránh gán trong if/while trừ khi bạn thực sự muốn.
    return
}

; ======================================================================================================================
; END SYNTAX GUARD
; ======================================================================================================================

; ======================================================================
; ⚠️ IMPORTANT – AHK v2 SYNTAX SAFETY NOTICE (DO NOT IGNORE)
;
; This script is **AutoHotkey v2** (STRICT braces).
; - Every `{` MUST have a matching `}`. Extra/missing braces => "Unexpected }"
; - When editing via ChatGPT: ONLY insert code INSIDE existing blocks.
; - DO NOT add/remove standalone `{` or `}` lines unless absolutely required.
;
; ✅ PERFORMANCE NOTE (IDOL FAST MODE)
; Legacy PixelGetColor-per-sample is VERY slow (can cause 10–60s waits).
; IDOL FAST MODE replaces it with a single bitmap capture + LockBits sampling
; to keep multi-icon AutoLearn within ~1–2 seconds in most cases.
; ======================================================================
; ======================================================================
; 🧠 IMAGE-BASED UI AUTOMATION – 5 LAYER + LOGIC GLUE (IDOL DEV)
; ======================================================================
; Mục tiêu: quét ROI theo THỨ TỰ bạn sắp xếp → nhận diện ảnh → click theo kịch bản.
; Đây là "UI script bằng hình ảnh", KHÔNG phải full-screen search / chọn candidate tốt nhất.
;
; KIẾN TRÚC (6 LAYER):
;   [GUI EDITOR]  → bạn kéo ROI + đánh số thứ tự
;        ↓
;   [L0: LOGIC GLUE]        – điều phối đúng trình tự, retry/timeout (không đoán)
;   [L1: ROI MAP]           – danh sách ROI theo thứ tự kịch bản (chỉ dữ liệu)
;   [L2: CAPTURE]           – chụp pixel ROI (không logic)
;   [L3: AL CHECK]          – kiểm tra ảnh ROI (YES/NO)
;   [L4: STEP CONTROLLER]   – não: bước hiện tại, retry, sang bước
;   [L5: ACTION]            – tay: click/key/drag theo lệnh
;
; CORE RULE:
;   ROI   = BẢN ĐỒ
;   CAP   = LẤY PIXEL
;   AL    = MẮT
;   STEP  = NÃO
;   ACTION= TAY
;
; FAST MODE (F4):
;   - CAP_FAST_MODE = true  → SCREEN capture ROI trực tiếp (KHÔNG full parent rect)
;   - AL_FAST_MODE  = true  → stride>=2, minCells>=6 (ROI-only, nhanh)
;   - GUI_MODE="RUN"    → GUI mờ + click-through (không chặn chuột), KHÔNG hide
;
; GUI POLICY (MỚI – KHÓA AI/DEV):
;   - KHÔNG dùng hide/show GUI cho F3/F4.
;   - Dùng GUI_MODE + HOTSPOT:
;       RUN  = GUI mờ + click-through (vẫn click được desktop/app bên dưới)
;       EDIT = GUI rõ nét + nhận chuột để chỉnh ROI/trình tự
;   - Mọi logic capture/AL phải ROI-only (không full rect) khi FAST.
;
; ======================================================================

; ======================================================================
; 🧠 DEBUG IMAGE SAVE POLICY (IDOL DEV – GIỮ NHANH NHƯNG VẪN CÓ ẢNH SOI ROI)
; ======================================================================
; - AL/CAP xử lý ảnh trong RAM; file .bmp chỉ để CON NGƯỜI kiểm tra ROI/split/crop.
; - FAST MODE (F4) KHÔNG được save mỗi vòng (disk IO sẽ giết tốc độ).
; - Thay vào đó: THROTTLE save (mỗi N vòng) + TÊN FILE DUY NHẤT (KHÔNG GHI ĐÈ).
; - F3 (setup/learn) vẫn ưu tiên save đầy đủ để bạn nhìn đúng ROI.
;
global DEBUG_SAVE_IMAGE := true         ; bật/tắt xuất ảnh debug
global DEBUG_SAVE_EVERY := 20          ; throttle: mỗi N vòng save 1 ảnh
global DBG_SAVE_CNT := 0               ; đếm vòng để throttle
global DBG_SAVE_SEQ := 0               ; seq để đảm bảo tên file không trùng
global DBG_LAST_TPL_PATH := ""         ; giữ path ảnh tpl gần nhất đã save

; ===============================
; GLOBAL STATE – F4 CAPTURE ORDER
; ===============================
global g_F4_Index := 0          ; số thứ tự ảnh F4 (001,002,…)
global g_F4_IsBusy := false     ; khóa chống double-trigger
global g_F4_LastTick := 0       ; anti-spam / debounce (nếu cần)
global g_F4_InitDone := false   ; init index 1 lần (scan file), tránh ghi đè
; ===============================
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

SC_TryGet(m, k, def := "") {
    if (!IsObject(m))
        return def
    try {
        if (m.Has(k))
            return m[k]
    } catch {
    }
    return def
}

SC_RectUnpack(srcRect, &L, &T, &R, &B) {
    ; Accepts:
    ;   - Rect object (properties: L,T,R,B)
    ;   - Map with keys: "L","T","R","B"
    ;   - Array [L,T,R,B] (1-based) or [0..3]
    L := 0, T := 0, R := 0, B := 0

    if (!IsObject(srcRect))
        return false

    ; Rect class instance
    try {
        if (srcRect is Rect) {
            L := srcRect.L, T := srcRect.T, R := srcRect.R, B := srcRect.B
            return true
        }
    } catch {
    }

    ; Map-like keys
    try {
        if (srcRect.Has("L") && srcRect.Has("T") && srcRect.Has("R") && srcRect.Has("B")) {
            L := srcRect["L"], T := srcRect["T"], R := srcRect["R"], B := srcRect["B"]
            return true
        }
    } catch {
    }

    ; Array-like [L,T,R,B]
    try {
        if (srcRect is Array) {
            if (srcRect.Length >= 4) {
                L := srcRect[1], T := srcRect[2], R := srcRect[3], B := srcRect[4]
                return true
            }

            if (srcRect.Has(0) && srcRect.Has(1) && srcRect.Has(2) && srcRect.Has(3)) {
                L := srcRect[0], T := srcRect[1], R := srcRect[2], B := srcRect[3]
                return true
            }
        }
    } catch {
    }

    return false
}

SC_RectUnpack_SAFE(srcRect, &L, &T, &R, &B) {
    ; SAFE unpack:
    ;   - Rect-like objects with .L/.T/.R/.B (including property-getters, no HasOwnProp required)
    ;   - Map with keys: "L","T","R","B"
    ;   - Array [L,T,R,B] (1-based) or [0..3]
    ;   - String "L,T,R,B"
    L := 0, T := 0, R := 0, B := 0

    ; String "L,T,R,B"
    if (Type(srcRect) = "String") {
        parts := StrSplit(Trim(srcRect), ",")
        if (parts.Length = 4) {
            L := Trim(parts[1]) + 0
            T := Trim(parts[2]) + 0
            R := Trim(parts[3]) + 0
            B := Trim(parts[4]) + 0
            return true
        }
        return false
    }

    if (!IsObject(srcRect))
        return false

    ; Rect-like object (works for custom classes too)
    try {
        L := srcRect.L, T := srcRect.T, R := srcRect.R, B := srcRect.B
        return true
    } catch {
    }

    ; Map-like keys
    try {
        if (srcRect.Has("L") && srcRect.Has("T") && srcRect.Has("R") && srcRect.Has("B")) {
            L := srcRect["L"], T := srcRect["T"], R := srcRect["R"], B := srcRect["B"]
            return true
        }
    } catch {
    }

    ; Array-like [L,T,R,B]
    try {
        if (srcRect is Array) {
            if (srcRect.Length >= 4) {
                L := srcRect[1], T := srcRect[2], R := srcRect[3], B := srcRect[4]
                return true
            }

            if (srcRect.Has(0) && srcRect.Has(1) && srcRect.Has(2) && srcRect.Has(3)) {
                L := srcRect[0], T := srcRect[1], R := srcRect[2], B := srcRect[3]
                return true
            }
        }
    } catch {
    }

    return false
}


SC_IsRectLike(r) {
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
        return false
    return IsNumber(L) && IsNumber(T) && IsNumber(R) && IsNumber(B) && (R > L) && (B > T)
}

RectAbsToWnd(hwnd, rectAbs) {
    ; Convert SCREEN-rect (abs) -> WINDOWDC-rect (relative to window top-left)
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(rectAbs, &L, &T, &R, &B))
        return 0
    rc := Buffer(16, 0)
    if (!DllCall("user32.dll\GetWindowRect", "ptr", hwnd, "ptr", rc, "int"))
        return 0
    wx := NumGet(rc, 0, "int")
    wy := NumGet(rc, 4, "int")
    return __RectClass(L - wx, T - wy, R - wx, B - wy)
}

GDI_BitBlt_FromHWND(hwnd, rectWnd, cap := 0) {
    ; WindowDC BitBlt using WINDOW-relative rect (LTRB)
    try {
        if (IsObject(cap))
            cap["coordBase"] := "WND"
    } catch {
    }
    return AL_GdipBitmapFromHWNDBitBlt(hwnd, rectWnd, cap)
}

GDI_BitBlt_FromScreen(rectAbs, cap := 0) {
    ; ScreenDC BitBlt using ABSOLUTE rect (LTRB)
; ---------------- AI_SAFEZONE100:CAPTURE_MODULE_BEGIN ----------------
; Capture helpers (SCREEN/HWND/DXGI). Keep flow isolated and return early per mode.
; ---------------------------------------------------------------------
    return AL_GdipBitmapFromScreenRect(rectAbs, cap)
}



IsNum(v) {
    s := Trim(v)
    if (s = "")
        return false
    return RegExMatch(s, "^-?\d+(\.\d+)?$")
}


ToIntSafe(v, def := 0) {
    try {
        s := Trim(v)
        if (s = "")
            return def
        return Integer(Number(s))
    } catch {
        return def
    }
}


; Convert "yyyy-MM-dd HH:mm:ss" => numeric key yyyymmddhhmmss. Returns 0 if invalid.
TimeKeySafe(s) {
    s := Trim(s)
    if (s = "")
        return 0
    if !RegExMatch(s, "^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})$", &m)
        return 0
    return Integer(m[1] . m[2] . m[3] . m[4] . m[5] . m[6])
}


ReverseArray(arr) {
    i := 1
    j := arr.Length
    while (i < j) {
        tmp := arr[i]
        arr[i] := arr[j]
        arr[j] := tmp
        i += 1
        j -= 1
    }
}

; -------- Stable Array Sort (for AHK v2 builds without built-in array sort) --------
; Comparator contract: cmpFn(a,b) > 0 => a comes after b ; < 0 => a comes before b ; 0 => equal.
AL_ArraySort(arr, cmpFn) {
    if !IsObject(arr)
        return false
    try {
        len := arr.Length
    } catch {
        return false
    }

    if (len <= 1)
        return true

    if !IsObject(cmpFn)
        cmpFn := (a, b) => (a > b) ? 1 : (a < b) ? -1 : 0

    tmp := []
    tmp.Length := len
    AL__MergeSort(arr, tmp, 1, len, cmpFn)
    return true
}

AL__MergeSort(arr, tmp, left, right, cmpFn) {
    if (left >= right)
        return

    mid := Floor((left + right) / 2)
    AL__MergeSort(arr, tmp, left, mid, cmpFn)
    AL__MergeSort(arr, tmp, mid + 1, right, cmpFn)

    i := left
    j := mid + 1
    k := left

    while (i <= mid && j <= right) {
        if (cmpFn(arr[i], arr[j]) <= 0) {
            tmp[k] := arr[i]
            i += 1
        } else {
            tmp[k] := arr[j]
            j += 1
        }
        k += 1
    }

    while (i <= mid) {
        tmp[k] := arr[i]
        i += 1
        k += 1
    }

    while (j <= right) {
        tmp[k] := arr[j]
        j += 1
        k += 1
    }

    idx := left
    while (idx <= right) {
        arr[idx] := tmp[idx]
        idx += 1
    }
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


; ============================================================

; =========================
; LOGIC / BEHAVIOR / UI (original functions)
; =========================
InitDpiGuard() {
    global DPI_AWARE, SYS_DPI, SCALE_PCT
    try {
        SC_DllCall("user32.dll\SetProcessDpiAwarenessContext", "ptr", -4, "int")
    } catch {
    }
    try {
        SC_DllCall("Shcore\SetProcessDpiAwareness", "int", 2, "int")
    } catch {
    }
    try {
        SC_DllCall("user32.dll\SetProcessDPIAware", "int")
    } catch {
    }

    try {
        ctx := SC_DllCall("user32.dll\GetThreadDpiAwarenessContext", "ptr")
        aw  := SC_DllCall("user32.dll\GetAwarenessFromDpiAwarenessContext", "ptr", ctx, "int")
        DPI_AWARE := (aw != 0)
    } catch {
        DPI_AWARE := true
    }

    try {
        SYS_DPI := SC_DllCall("user32.dll\GetDpiForSystem", "uint")
    } catch {
        SYS_DPI := A_ScreenDPI
    }

    if (SYS_DPI <= 0)
        SYS_DPI := 96
    SCALE_PCT := Round(SYS_DPI * 100 / 96)
}


GetDpiInfo() {
    global DPI_AWARE, SYS_DPI, SCALE_PCT
    return (DPI_AWARE ? "Aware" : "UNaware") " | System DPI=" SYS_DPI " (" SCALE_PCT "%)"
}


; AutoLearn UI Element - 5 Layers (AHK v2, no-ML)
; ============================================================
; This section contains only the 5 layers + minimal types + helpers.
; To hook this into your existing tool, replace the indicated stubs:
;   - AL_PickRegionDrag()      (Layer 1)
;   - AL_Capture_RectToBMP()   (Layer 1/4/5)
;   - AL_Capture_ReadPixelGrid() (Layer 2/3/4/5)
;   - AL_ClickCenterRect()     (Layer 5 - click test)
; and (optionally) persist settings to your INI store.
;
; I/O design:
;   Layer1 -> ParentContext
;   Layer2 -> Candidates[]
;   Layer3 -> Filtered[]
;   Layer4 -> ElementModel
;   Layer5 -> BehaviorSignature
;
; Suggested usage:
;   parent := AL_L1_ManualParentPick(store)
;   cands  := AL_L2_Segment(parent, opts)
;   filt   := AL_L3_Filter(parent, cands, opts)
;   model  := AL_L4_Extract(parent, filt, store, opts)
;   beh    := AL_L5_LearnBehavior(parent, model, store, opts)
;
; ============================================================

; ----------------------------
; Types
; ----------------------------
class Rect {
    __New(L := 0, T := 0, R := 0, B := 0) {
        this.L := L
        this.T := T
        this.R := R
        this.B := B
    }
    W => (this.R - this.L)
    H => (this.B - this.T)
    CenterX => (this.L + this.W//2)
    CenterY => (this.T + this.H//2)
    ToString() => Format("L{} T{} R{} B{} ({}x{})", this.L, this.T, this.R, this.B, this.W, this.H)
}
__RectClass := Rect  ; stable handle to Rect class (avoid accidental shadowing)



class ParentContext {
    __New(rectScreen, bmpPath := "", meta := 0) {
        this.rect := rectScreen          ; Rect screen coords
        this.bmpPath := bmpPath          ; optional: screenshot path
        this.meta := IsObject(meta) ? meta : Map()
    }
}


class Candidate {
    __New(rectRel, score := 0.0, stats := 0) {
        this.rectRel := rectRel          ; Rect relative to parent
        this.score := score
        this.stats := IsObject(stats) ? stats : Map()
    }
}


class ElementModel {
    __New(id, normRectRel, templatePath := "", anchors := 0, meta := 0) {
        this.id := id
        this.normRect := normRectRel     ; Rect relative to parent (expected size)
        this.templatePath := templatePath
        this.anchors := IsObject(anchors) ? anchors : []
        this.meta := IsObject(meta) ? meta : Map()
    }
}


class BehaviorSignature {
    __New(deltaPctMin := 0.03, borderDeltaMin := 0.015, lumaShiftDir := "any", settleDelayMs := 120, valid := true, meta := 0) {
        this.deltaPctMin := deltaPctMin          ; min % pixels changed in ROI
        this.borderDeltaMin := borderDeltaMin    ; min % changed mainly in border ring
        this.lumaShiftDir := lumaShiftDir        ; "up" | "down" | "any"
        this.settleDelayMs := settleDelayMs
        this.valid := valid
        this.meta := IsObject(meta) ? meta : Map()
    }
}



; --- GDI+ lib compat layer (AHKv2) ---
; Some common libs expose Gdip_Startup()/Gdip_Shutdown(). Provide wrappers for compatibility.



; =========================================================
; CAPTURE DEBUG MASTER HELPERS (CAP | ...)
; =========================================================
CAP_SM(n) {
    ; Safe GetSystemMetrics
    try {
        return DllCall("user32.dll\GetSystemMetrics", "int", n, "int")
    } catch {
        return 0
    }
}

CAP_GetVirtualDesktop(&vx, &vy, &vw, &vh) {
    ; Virtual screen may start at negative coords in multi-monitor setups.
    vx := CAP_SM(76) ; SM_XVIRTUALSCREEN
    vy := CAP_SM(77) ; SM_YVIRTUALSCREEN
    vw := CAP_SM(78) ; SM_CXVIRTUALSCREEN
    vh := CAP_SM(79) ; SM_CYVIRTUALSCREEN
    if (vw <= 0)
        vw := A_ScreenWidth
    if (vh <= 0)
        vh := A_ScreenHeight
}

CAP_GetSystemDPI() {
    global SYS_DPI
    if (IsSet(SYS_DPI) && SYS_DPI > 0)
        return SYS_DPI
    try {
        return DllCall("user32.dll\GetDpiForSystem", "uint")
    } catch {
        return (A_ScreenDPI > 0 ? A_ScreenDPI : 96)
    }
}

CAP_GetWindowDPI(hwnd, sysDpi := 96) {
    if (!hwnd)
        return sysDpi
    try {
        dpi := DllCall("user32.dll\GetDpiForWindow", "ptr", hwnd, "uint")
        return (dpi > 0 ? dpi : sysDpi)
    } catch {
        return sysDpi
    }
}

CAP_GetMonitorIndexForPoint(x, y, &total) {
    total := 0
    idx := 0
    try {
        ; Prefer built-ins (Win 10/11)
        total := MonitorGetCount()
        if (total <= 0)
            total := CAP_SM(80) ; SM_CMONITORS
        Loop total {
            i := A_Index
            MonitorGet(i, &l, &t, &r, &b)
            if (x >= l && x < r && y >= t && y < b)
                return i
        }
        return 0
    } catch {
        total := CAP_SM(80)
        return 0
    }
}

CAP_Log(msg, level := "DEBUG") {
    ; Centralized capture log line
    try {
        Log(msg, level, "CAP")
    } catch {
    }
}

CAP_KV(stage, capId, kv, level := "DEBUG") {
    ; stage="START"/"DPI"/"VALID"/... kv already formatted "a=b c=d ..."
    CAP_Log(Format("CAP | {} id={} {}", stage, capId, kv), level)
}


EnsureGdip(silent := false) {
    global GdipToken

    if (GdipToken)
        return true

    try {
        GdipToken := Gdip_Startup()
    } catch as e {
        if (!silent)
            Log("CAP | GDI+ startup EXCEPTION msg=" e.Message, "ERROR", "CAP")
        return false
    }

    if (!GdipToken) {
        if (!silent)
            Log("CAP | GDI+ startup FAIL token=0 hr=2", "ERROR", "CAP")
        return false
    }

    if (!silent)
        Log(Format("CAP | GDI+ START OK token={}", GdipToken), "DEBUG", "CAP")
    return true
}

; ============================================================
; GUI/OVERLAY GUARD FOR DXGI DESKTOP CAPTURE
; DXGI captures the final desktop composition, so any on-top GUI
; (main window, drag border overlay, tooltips) can contaminate
; the captured bitmap. We hide them briefly before running dxgi_cap.exe
; and restore right after. (No refactor: just a small guard.)
; ============================================================

CAP_IsWindowVisible(hwnd) {
    try {
        return DllCall("user32.dll\IsWindowVisible", "ptr", hwnd, "int")
    } catch {
        return 0
    }
}
; =========================
; IDOL CAP LAYER (no refactor)
; Target detect + best HWND for PrintWindow (Browser/Electron).
; =========================
CAP_DetectTargetType(hwnd) {
    ; Returns: "BROWSER" | "GAME" | "APP"
    cls := ""
    exe := ""
    try {
        cls := WinGetClass("ahk_id " hwnd)
    } catch {
        cls := ""
    }
    try {
        exe := StrLower(WinGetProcessName("ahk_id " hwnd))
    } catch {
        exe := ""
    }

if (cls = "")
        return "APP"

    ; Browsers / Chromium / Electron shells
    if (InStr(cls, "Chrome_WidgetWin") || cls = "MozillaWindowClass"
        || exe = "chrome.exe" || exe = "msedge.exe" || exe = "brave.exe" || exe = "vivaldi.exe" || exe = "opera.exe" || exe = "firefox.exe") {
        return "BROWSER"
    }

    ; Common game engines (heuristic)
    if (cls = "UnityWndClass" || InStr(cls, "UnrealWindow") || InStr(exe, "roblox") || InStr(exe, "ue4") || InStr(exe, "unity")) {
        return "GAME"
    }

    return "APP"
}

CAP_GetBestPrintWindowHwnd(hwnd) {
    ; For Chromium/Electron, PrintWindow on top-level can return 0/black.
    ; Prefer the render-host child if found.
    cls := ""
    try {
        cls := WinGetClass("ahk_id " hwnd)
    } catch {
        cls := ""
    }

if (!InStr(cls, "Chrome_WidgetWin"))
        return hwnd

    child := 0
    ; Try common Chromium render child classes
    try {
        child := DllCall("user32.dll\FindWindowExW", "ptr", hwnd, "ptr", 0, "wstr", "Chrome_RenderWidgetHostHWND", "ptr", 0, "ptr")
        if (!child)
            child := DllCall("user32.dll\FindWindowExW", "ptr", hwnd, "ptr", 0, "wstr", "Chrome_RenderWidgetHostHWND1", "ptr", 0, "ptr")
        if (!child)
            child := DllCall("user32.dll\FindWindowExW", "ptr", hwnd, "ptr", 0, "wstr", "Chrome_RenderWidgetHostHWND2", "ptr", 0, "ptr")
    } catch {
        child := 0
    }

    return child ? child : hwnd
}


CAP_BeginDesktopCapture() {
    st := Map()

    ; Kill any tooltip that could be on top.
    try {
        ToolTip()
    } catch {
    }

    ; GUI hide policy: mặc định KHÔNG hide GUI/border khi capture.
    ; Nếu bạn muốn hide thật sự (không khuyên dùng cho pixel-truth), set:
    ;   GUI_HIDE_DURING_CAPTURE := true
    try {
        global GUI_HIDE_DURING_CAPTURE
        if (!GUI_HIDE_DURING_CAPTURE)
            return st
    } catch {
    }

    ; Hide main GUI if present.
    try {
        global g
        if (IsObject(g) && g.Hwnd) {
            was := CAP_IsWindowVisible(g.Hwnd)
            st["gWasVisible"] := was
            if (was)
                g.Hide()
        }
    } catch {
    }

    ; Hide border/overlay GUIs if present.
    try {
        global borderG
        vis := []
        if (IsObject(borderG)) {
            for _, gg in borderG {
                try {
                    if (IsObject(gg) && gg.Hwnd && CAP_IsWindowVisible(gg.Hwnd)) {
                        vis.Push(gg)
                        gg.Hide()
                    }
                } catch {
                }
            }
        }
        st["borderVis"] := vis
    } catch {
    }

    ; Give DWM a moment to re-compose without overlays.
    Sleep 60
    return st
}

CAP_EndDesktopCapture(st) {
    if !IsObject(st)
        return

    ; Restore border overlays if they were visible.
    try {
        if (st.Has("borderVis")) {
            for _, gg in st["borderVis"] {
                try {
                    gg.Show("NA")
                } catch {
                }
            }
        }
    } catch {
    }

    ; Restore main GUI.
    try {
        global g
        if (st.Has("gWasVisible") && st["gWasVisible"] && IsObject(g)) {
            g.Show()
        }
    } catch {
    }
}
_GdipGetEncoderClsid(mime) {
    ; Returns Buffer(16) CLSID, or 0 (dynamic struct sizing).
    size := 0
    count := 0
    if (SC_DllCall("gdiplus\GdipGetImageEncodersSize", "UIntP", count, "UIntP", size, "Int") != 0)
        return 0
    if (count <= 0 || size <= 0)
        return 0

    buf := Buffer(size, 0)
    if (SC_DllCall("gdiplus\GdipGetImageEncoders", "UInt", count, "UInt", size, "Ptr", buf.Ptr, "Int") != 0)
        return 0

    itemSize := (A_PtrSize = 8 ? 104 : 76)  ; ImageCodecInfo struct size
    offMime := 32 + (4 * A_PtrSize)
    base := buf.Ptr

    Loop count {
        pItem := base + (A_Index - 1) * itemSize
        pMime := NumGet(pItem + offMime, "Ptr")
        if (!pMime)
            continue
        mt := StrGet(pMime, "UTF-16")
        if (mt = mime) {
            clsid := Buffer(16, 0)
            SC_DllCall("RtlMoveMemory", "Ptr", clsid.Ptr, "Ptr", pItem, "UPtr", 16)
            return clsid
        }
    }
    return 0
}

AL_GdipGetEncoderClsid(mime) {
    ; compatibility wrapper (minimal) for AL_GdipSaveBitmapToFile
    return _GdipGetEncoderClsid(mime)
}

CAP_CopyRect_DXGI(rectAbs) {
    ; rectAbs: "L,T,R,B" (absolute screen coords)
    ; returns: pBitmap (GDI+ bitmap ptr) or 0
    static dxgiExeCached := ""
    try {
        parts := StrSplit(rectAbs, ",")
        if (parts.Length < 4)
            return 0
        L := parts[1] + 0, T := parts[2] + 0, R := parts[3] + 0, B := parts[4] + 0
        W := Max(1, R - L), H := Max(1, B - T)

        dxgiExe := dxgiExeCached
        if (!dxgiExe) {
            dxgiExe := A_MyDocuments "\AutoHotkey\Lib\dxgi_cap.exe"
            if (!FileExist(dxgiExe))
                dxgiExe := A_ScriptDir "\dxgi_cap.exe"
            if (!FileExist(dxgiExe))
                return 0
            dxgiExeCached := dxgiExe
        } else if (!FileExist(dxgiExe)) {
            dxgiExeCached := ""
            return 0
        }

        outBmp := A_Temp "\dxgi_cap_" A_TickCount "_" DllCall("kernel32.dll\GetCurrentThreadId", "uint") ".bmp"
        cmd := Format('"{1}" {2} {3} {4} {5} "{6}"', dxgiExe, L, T, W, H, outBmp)

        ; Hide console; wait for completion (retry once on failure/lock)
        tries := 0
        while (tries < 2) {
            tries += 1
            try {
                FileDelete outBmp
            } catch {
            }

            Log("DXGI CALL rectAbs=" rectAbs, "DEBUG", "DXGI")

            Log("DXGI CMD=" cmd, "DEBUG", "DXGI")
            exitCode := 0
            stCap := 0
            try {
                stCap := CAP_BeginDesktopCapture()
            } catch {
                stCap := 0
            }
            try {
                exitCode := RunWait(cmd, , "Hide")
            } catch as e {
                Log("DXGI RUN EXCEPTION msg=" e.Message, "ERROR", "DXGI")
                Sleep 20
                continue
            } finally {
                try {
                    CAP_EndDesktopCapture(stCap)
                } catch {
                }
            }

            Log("DXGI EXIT exitCode=" exitCode, "DEBUG", "DXGI")
            Log("DXGI OUT exist=" FileExist(outBmp), "DEBUG", "DXGI")

            if (exitCode != 0) {
                Sleep 20
                continue
            }

            ; wait until file exists and is "ready" (size >= 100 bytes and stable)
            okFile := false
            lastSz := -1
            stableCount := 0
            t0 := A_TickCount
            while ((A_TickCount - t0) < 800) {
                if (FileExist(outBmp)) {
                    sz := 0
                    try {
                        sz := FileGetSize(outBmp)
                    } catch {
                    }
                    if (sz >= 100) {
                        if (sz = lastSz)
                            stableCount += 1
                        else
                            stableCount := 0
                        lastSz := sz
                        if (stableCount >= 1) {
                            okFile := true
                            break
                        }
                    } else {
                        lastSz := sz
                        stableCount := 0
                    }
                }
                Sleep 10
            }

            if (!okFile) {
                Sleep 20
                continue
            }

            ; load bitmap (retry a few times in case of transient lock)
            bmp := 0
            Loop 10 {
                try {
                    bmp := Gdip_CreateBitmapFromFile(outBmp)
                } catch {
                }
                if (bmp)
                    break
                Sleep 10
            }

            if (bmp) {
                try {
                    FileDelete outBmp
                } catch {
                }
                return bmp
            }

            Sleep 20
        }
        try {
            FileDelete outBmp
        } catch {
        }
        return 0
    } catch as e {
        return 0
    }
}

; ============================================================
; FILE-LEVEL BMP HELPERS (IDOL STANDARD)
; - Used to crop EXACTLY the same captured parent.bmp (DXGI/GDI)
; - Outputs opaque 24-bit BMP (normal-looking, no alpha issues)
; ============================================================

SC_BmpGetSize(path, &w, &h) {
    w := 0, h := 0
    f := 0
    try {
        f := FileOpen(path, "r -raw")
        if (!f)
            return false
        ; BITMAPINFOHEADER width/height at offset 18/22 from file start
        f.Pos := 18
        w := f.ReadInt()
        hRaw := f.ReadInt()
        h := Abs(hRaw)
        try {
            f.Close()
        } catch {
        }
        return (w > 0 && h > 0)
    } catch {
        try {
            f.Close()
        } catch {
        }
        return false
    }
}

SC_BmpGetBitCount(path, &bpp) {
    ; Reads biBitCount from BMP header. Returns true/false.
    bpp := 0
    f := 0
    try {
        f := FileOpen(path, "r -raw")
        if (!f)
            return false
        ; biBitCount at file offset 28 (BITMAPFILEHEADER 14 + BIH offset 14)
        f.Pos := 28
        bpp := f.ReadUShort()
        try {
            f.Close()
        } catch {
        }
        return (bpp > 0)
    } catch {
        try {
            if (f)
                f.Close()
        } catch {
        }
        bpp := 0
        return false
    }
}

SC_BmpProbeAlphaAndBlack(path, &alphaAllZero, &rgbAllZero) {
    ; Quick probe (sample a few rows/cols) to detect DXGI "alpha=0" or full black frames.
    alphaAllZero := 0
    rgbAllZero := 0
    f := 0
    try {
        f := FileOpen(path, "r -raw")
        if (!f)
            return false

        ; Validate BMP signature
        if (f.ReadUShort() != 0x4D42) {
            try {
                f.Close()
            } catch {
            }
            return false
        }

        ; OffBits
        f.Pos := 10
        offBits := f.ReadUInt()

        ; Width/Height/BitCount
        f.Pos := 18
        w := f.ReadInt()
        hRaw := f.ReadInt()
        h := Abs(hRaw)
        f.Pos := 28
        bpp := f.ReadUShort()

        if (w <= 0 || h <= 0) {
            try {
                f.Close()
            } catch {
            }
            return false
        }

        if (bpp != 32 && bpp != 24) {
            try {
                f.Close()
            } catch {
            }
            return false
        }

        bytesPP := (bpp = 32 ? 4 : 3)
        stride := (bpp = 24) ? (((w * 3 + 3) // 4) * 4) : (w * 4)

        sampleRows := Min(3, h)
        sampleCols := Min(64, w)

        alphaZero := true
        rgbZero := true

        rowBuf := Buffer(sampleCols * bytesPP, 0)

        Loop sampleRows {
            f.Pos := offBits + (A_Index - 1) * stride
            f.RawRead(rowBuf, rowBuf.Size)

            Loop sampleCols {
                i := (A_Index - 1) * bytesPP
                b := NumGet(rowBuf, i + 0, "UChar")
                g := NumGet(rowBuf, i + 1, "UChar")
                r := NumGet(rowBuf, i + 2, "UChar")

                if ((r | g | b) != 0)
                    rgbZero := false

                if (bpp = 32) {
                    a := NumGet(rowBuf, i + 3, "UChar")
                    if (a != 0)
                        alphaZero := false
                }
            }
        }

        try {
            f.Close()
        } catch {
        }

        alphaAllZero := (bpp = 32 && alphaZero) ? 1 : 0
        rgbAllZero := rgbZero ? 1 : 0
        return true
    } catch {
        try {
            if (f)
                f.Close()
        } catch {
        }
        alphaAllZero := 0
        rgbAllZero := 0
        return false
    }
}


SC_BmpCropFile(srcPath, dstPath, x, y, cw, ch, flattenOnWhite := true) {
    ; x,y,cw,ch in top-left coordinate system of the source image
    ; Supports uncompressed 24-bit and 32-bit BMP. Outputs 24-bit BMP.
    fs := 0
    fd := 0
    try {
        fs := FileOpen(srcPath, "r -raw")
        if (!fs)
            return false

        ; --- BITMAPFILEHEADER (14 bytes) ---
        bfType := fs.ReadUShort()
        if (bfType != 0x4D42) { ; 'BM'
            try {
                fs.Close()
            } catch {
            }
            return false
        }
        bfSize := fs.ReadUInt()
        fs.ReadUShort() ; bfReserved1
        fs.ReadUShort() ; bfReserved2
        bfOffBits := fs.ReadUInt()

        ; --- BITMAPINFOHEADER (assume >= 40 bytes) ---
        biSize := fs.ReadUInt()
        if (biSize < 40) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }
        biWidth := fs.ReadInt()
        biHeight := fs.ReadInt()
        biPlanes := fs.ReadUShort()
        biBitCount := fs.ReadUShort()
        biCompression := fs.ReadUInt()
        biSizeImage := fs.ReadUInt()
        fs.ReadInt() ; biXPelsPerMeter
        fs.ReadInt() ; biYPelsPerMeter
        fs.ReadUInt() ; biClrUsed
        fs.ReadUInt() ; biClrImportant

        if (biPlanes != 1) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        ; Only BI_RGB (0) or BI_BITFIELDS (3) are common for 32-bit.
        if (biCompression != 0 && biCompression != 3) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        srcW := biWidth
        srcHRaw := biHeight
        srcTopDown := (srcHRaw < 0)
        srcH := Abs(srcHRaw)

        if (srcW <= 0 || srcH <= 0) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        if (x < 0 || y < 0 || cw <= 0 || ch <= 0 || x + cw > srcW || y + ch > srcH) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        bpp := biBitCount
        if (bpp != 24 && bpp != 32) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }
        srcBytesPP := (bpp = 24 ? 3 : 4)
        srcStride := (bpp = 24) ? (((srcW * 3 + 3) // 4) * 4) : (srcW * 4)

        ; If BI_BITFIELDS and header has masks, skip them (we still treat as BGRA for standard masks).
        ; For simplicity, we do not parse masks; most desktop captures use standard BGRA.

        ; --- Prepare destination (24-bit) ---
        dstBpp := 24
        dstBytesPP := 3
        dstStride := (((cw * dstBytesPP + 3) // 4) * 4)
        dstImageSize := dstStride * ch
        dstOffBits := 14 + 40
        dstFileSize := dstOffBits + dstImageSize

        ; Write headers
        fd := FileOpen(dstPath, "w -raw")
        if (!fd) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        ; BITMAPFILEHEADER
        fd.WriteUShort(0x4D42)
        fd.WriteUInt(dstFileSize)
        fd.WriteUShort(0)
        fd.WriteUShort(0)
        fd.WriteUInt(dstOffBits)

        ; BITMAPINFOHEADER (40 bytes)
        fd.WriteUInt(40)
        fd.WriteInt(cw)
        fd.WriteInt(ch) ; bottom-up
        fd.WriteUShort(1)
        fd.WriteUShort(dstBpp)
        fd.WriteUInt(0) ; BI_RGB
        fd.WriteUInt(dstImageSize)
        fd.WriteInt(0)
        fd.WriteInt(0)
        fd.WriteUInt(0)
        fd.WriteUInt(0)

        ; --- Copy pixels row by row (write bottom-up) ---
        padBytes := dstStride - (cw * dstBytesPP)
        if (padBytes < 0)
            padBytes := 0
        pad := (padBytes ? Buffer(padBytes, 0) : 0)

        rowBuf := Buffer(cw * srcBytesPP, 0)

        ; Destination row index 0 is bottom row in file
        Loop ch {
            dstRowTop := ch - A_Index ; 0..ch-1 (top-down index)
            srcY := y + dstRowTop
            fileRow := srcTopDown ? srcY : (srcH - 1 - srcY)
            srcPos := bfOffBits + fileRow * srcStride + x * srcBytesPP
            fs.Pos := srcPos

            ; Read the contiguous crop row bytes
            fs.RawRead(rowBuf, cw * srcBytesPP)

            ; Convert/write 24-bit row
            if (srcBytesPP = 3) {
                ; BGR already
                fd.RawWrite(rowBuf, cw * 3)
            } else {
                ; BGRA -> BGR (flatten on white if requested)
                outRow := Buffer(cw * 3, 0)
                si := 0
                di := 0
                Loop cw {
                    b := NumGet(rowBuf, si, "UChar")
                    g := NumGet(rowBuf, si+1, "UChar")
                    r := NumGet(rowBuf, si+2, "UChar")
                    a := NumGet(rowBuf, si+3, "UChar")
                    if (flattenOnWhite) {
                        inv := 255 - a
                        b := (b * a + 255 * inv) // 255
                        g := (g * a + 255 * inv) // 255
                        r := (r * a + 255 * inv) // 255
                    }
                    NumPut("UChar", b, outRow, di)
                    NumPut("UChar", g, outRow, di+1)
                    NumPut("UChar", r, outRow, di+2)
                    si += 4
                    di += 3
                }
                fd.RawWrite(outRow, cw * 3)
            }

            if (padBytes)
                fd.RawWrite(pad, padBytes)
        }

        try {
            fs.Close()
        } catch {
        }
        try {
            fd.Close()
        } catch {
        }
        return FileExist(dstPath) ? true : false
    } catch {
        try {
            fs.Close()
        } catch {
        }
        try {
            fd.Close()
        } catch {
        }
        return false
    }
}


SC_BmpFlattenTo24(path, flattenOnWhite := true) {
    ; Converts the whole BMP to an opaque 24-bit BMP in-place (safe temp swap).
    ; Fixes "black preview" when DXGI outputs pixels with A=0.
    if (!FileExist(path))
        return false
    bw := 0, bh := 0
    if (!SC_BmpGetSize(path, &bw, &bh))
        return false
    if (bw <= 0 || bh <= 0)
        return false
    tmp := path ".tmp24.bmp"
    ok := false
    try {
        ok := SC_BmpCropFile(path, tmp, 0, 0, bw, bh, flattenOnWhite)
    } catch {
        ok := false
    }

    if (!ok) {
        try {
            FileDelete tmp
        } catch {
        }
        return false
    }
    try {
        FileMove(tmp, path, 1)
    } catch {
        ; if move fails, keep tmp for inspection
        return false
    }
    return true
}

AL_GdipBitmapFromScreenRect(r, cap := 0) {
    global CAP_USE_DXGI
    IsFunc := Func("IsFunc")
    ; Returns: pBitmap (GDI+ Bitmap ptr) or 0
    ; cap: Map used for CAPTURE DEBUG MASTER (id/debug/deep). This function may write:
    ;   cap["lastStage"], cap["fail"], cap["method"], cap["copyMs"], cap["winErr"]
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
        return 0


    rectAbs := L "," T "," R "," B

    ; (DXGI disabled for ScreenRect path; DESKTOP must use GDI only)

; clamp to virtual desktop to avoid out-of-screen DXGI/GDI issues
vdL := SysGet(76), vdT := SysGet(77), vdW := SysGet(78), vdH := SysGet(79)
vdR := vdL + vdW, vdB := vdT + vdH
if (L < vdL)
    L := vdL
if (T < vdT)
    T := vdT
if (R > vdR)
    R := vdR
if (B > vdB)
    B := vdB
    capId := ""
    debug := true
    deep := false
    if (IsObject(cap)) {
        try {
            if (cap.Has("id"))
                capId := cap["id"]
            if (cap.Has("debug"))
                debug := cap["debug"]
            if (cap.Has("deep"))
                deep := cap["deep"]
        } catch {
        }
    }
        ; srcMode := StrUpper(srcMode)  ; (unused local, avoid shadow)
if (capId = "")
        capId := "NA"
    if (!IsNumber(L) || !IsNumber(T) || !IsNumber(R) || !IsNumber(B))
        return 0


; clamp to virtual desktop to avoid out-of-screen DXGI/GDI issues
vdL := SysGet(76), vdT := SysGet(77), vdW := SysGet(78), vdH := SysGet(79)
vdR := vdL + vdW, vdB := vdT + vdH
if (L < vdL)
    L := vdL
if (T < vdT)
    T := vdT
if (R > vdR)
    R := vdR
if (B > vdB)
    B := vdB
    W := Max(1, R - L)
    H := Max(1, B - T)

    
rectAbs := Format("{},{},{},{}", L, T, R, B)

; (DXGI disabled for ScreenRect path; DESKTOP must use GDI only)

pBitmap := 0
    tCopy := A_TickCount

    ; =========================
    ; Method 1: Gdip_All helper (fast, simple)
    ; =========================
    if (IsFunc("Gdip_BitmapFromScreen")) {
        if (IsObject(cap)) {
            cap["method"] := "Gdip_BitmapFromScreen"
            cap["lastStage"] := "COPY"
        }
        try {
            pBitmap := Gdip_BitmapFromScreen(L "|" T "|" W "|" H)
        } catch as e {
            pBitmap := 0
            if (IsObject(cap))
                cap["fail"] := "Gdip_BitmapFromScreen exception: " e.Message
        }
        dur := A_TickCount - tCopy
        if (IsObject(cap))
            cap["copyMs"] := dur

        if (debug) {
            if (pBitmap)
                CAP_KV("COPY", capId, Format("method=Graphics.Copy ok=1 duration={}ms", dur))
            else
                CAP_KV("COPY FAIL", capId, Format("method=Graphics.Copy ok=0 duration={}ms msg={}", dur, ((IsObject(cap) && cap.Has("fail") && cap["fail"] != "") ? cap["fail"] : "Gdip_BitmapFromScreen=0")), "ERROR")
        }

        if (pBitmap)
            return pBitmap
    }

    ; =========================
    ; Method 2: Manual BitBlt (fallback)
    ; =========================
    if (IsObject(cap)) {
        cap["method"] := "BitBlt"
        cap["lastStage"] := "CTX"
        cap["winErr"] := 0
    }

    hdcScreen := 0
    hdcMem := 0
    hbm := 0
    obm := 0

    try {
        ; CTX
        hdcScreen := DllCall("user32.dll\GetDC", "ptr", 0, "ptr")
        if (!hdcScreen) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "GetDC=0"
                cap["lastStage"] := "CTX"
            }

            if (debug)
                CAP_KV("CTX FAIL", capId, Format("step=GetDC err={}", A_LastError), "ERROR")
            return 0
        }

        if (debug)
            CAP_KV("CTX", capId, "getWindowDC=0 hdcWindow=NA hdcScreen=OK hdcMem=...")

        hdcMem := DllCall("gdi32.dll\CreateCompatibleDC", "ptr", hdcScreen, "ptr")
        if (!hdcMem) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "CreateCompatibleDC=0"
                cap["lastStage"] := "CTX"
            }

            if (debug)
                CAP_KV("CTX FAIL", capId, Format("step=CreateCompatibleDC err={}", A_LastError), "ERROR")
            return 0
        }

        hbm := DllCall("gdi32.dll\CreateCompatibleBitmap", "ptr", hdcScreen, "int", W, "int", H, "ptr")
        if (!hbm) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "CreateCompatibleBitmap=0"
                cap["lastStage"] := "BMP"
            }

            if (debug)
                CAP_KV("BMP FAIL", capId, Format("reason=CreateFailed winErr={} W={} H={}", A_LastError, W, H), "ERROR")
            return 0
        }

        obm := DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")
        if (!obm) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "SelectObject=0"
                cap["lastStage"] := "CTX"
            }

            if (debug)
                CAP_KV("CTX FAIL", capId, Format("step=SelectObject err={}", A_LastError), "ERROR")
            return 0
        }

        if (debug)
            CAP_KV("BMP", capId, Format("create=1 w={} h={} handle={}", W, H, hbm))

        ; COPY
        if (IsObject(cap))
            cap["lastStage"] := "COPY"
        t2 := A_TickCount
        ; COPY safety (AHK v2: prevent [] on non-objects upstream)
        if (debug)
            CAP_KV("COPY PRE", capId, Format('rectType={} rectIsObj={} hbmType={} hbmIsObj={} hdcMemType={} hdcScreenType={}'
                , Type(r), IsObject(r) ? 1 : 0, Type(hbm), IsObject(hbm) ? 1 : 0, Type(hdcMem), Type(hdcScreen)))
        if (!hbm || !hdcMem || !hdcScreen) {
            if (IsObject(cap)) {
                cap["fail"] := "preCopy invalid handles"
                cap["lastStage"] := "COPY"
                cap["winErr"] := A_LastError
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, "bmp invalid", "ERROR")
            return 0
        }

        ok := DllCall("gdi32.dll\BitBlt"
            , "ptr", hdcMem
            , "int", 0, "int", 0
            , "int", W, "int", H
            , "ptr", hdcScreen
            , "int", L, "int", T
            , "uint", 0x00CC0020
            , "int")
        dur := A_TickCount - t2

        if (!ok) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "BitBlt=0"
                cap["copyMs"] := dur
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method=BitBlt ok=0 winErr={} msg=BitBlt=0 duration={}ms", A_LastError, dur), "ERROR")
            return 0
        }

        if (IsObject(cap))
            cap["copyMs"] := dur

        if (debug)
            CAP_KV("COPY", capId, Format("method=BitBlt ok=1 duration={}ms", dur))

        ; Convert HBITMAP -> GDI+ bitmap pointer
        if (IsObject(cap))
            cap["lastStage"] := "BMP"

        try {
            pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
        } catch as e {
            pBitmap := 0
            if (IsObject(cap))
                cap["fail"] := "CreateBitmapFromHBITMAP exception: " e.Message
        }

        if (!pBitmap) {
            if (IsObject(cap)) {
                cap["fail"] := (cap.Has("fail") ? cap["fail"] : "CreateBitmapFromHBITMAP=0")
                cap["lastStage"] := "BMP"
            }

            if (debug)
                CAP_KV("BMP FAIL", capId, Format("reason=CreateFailed msg={}", ((IsObject(cap) && cap.Has("fail") && cap["fail"] != "") ? cap["fail"] : "CreateBitmapFromHBITMAP=0")), "ERROR")
            return 0
        }

        return pBitmap
    } catch as e {
        if (IsObject(cap)) {
            cap["fail"] := "EXCEPTION: " e.Message
            cap["lastStage"] := "COPY"
        }

        if (debug)
            CAP_KV("COPY FAIL", capId, Format("method=Exception msg={}", e.Message), "ERROR")
        return 0
    } finally {
        ; Always restore/release GDI handles (no leaks on any path)
        if (hdcMem && obm) {
            try {
                DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", obm)
            } catch {
            }
        }

        if (hbm) {
            try {
                DllCall("gdi32.dll\DeleteObject", "ptr", hbm)
            } catch {
            }
        }

        if (hdcMem) {
            try {
                DllCall("gdi32.dll\DeleteDC", "ptr", hdcMem)
            } catch {
            }
        }

        if (hdcScreen) {
            try {
                DllCall("user32.dll\ReleaseDC", "ptr", 0, "ptr", hdcScreen)
            } catch {
            }
        }
    }
}




AL_GdipSaveBitmapToFile(pBitmap, outPath, cap := 0) {
    AL_GdipGetEncoderClsid := Func("AL_GdipGetEncoderClsid")
    capId := ""
    debug := true
    if (IsObject(cap)) {
        try {
            if (cap.Has("id"))
                capId := cap["id"]
            if (cap.Has("debug"))
                debug := cap["debug"]
        } catch {
        }
    }

    if (capId = "")
        capId := "NA"

    if (!pBitmap) {
        if (IsObject(cap)) {
            cap["fail"] := "InvalidBitmap"
            cap["lastStage"] := "SAVE"
        }

        if (debug)
            CAP_KV("SAVE FAIL", capId, "reason=InvalidBitmap", "ERROR")
        return false
    }

    ; Pick encoder from extension, default PNG
    ext := ""
    try {
        ext := StrLower(RegExReplace(outPath, ".*\.(\w+)$", "$1"))
    } catch {
        ext := "png"
    }

    if (ext = "bmp")
        clsid := AL_GdipGetEncoderClsid("image/bmp")
    else if (ext = "jpg" || ext = "jpeg")
        clsid := AL_GdipGetEncoderClsid("image/jpeg")
    else
        clsid := AL_GdipGetEncoderClsid("image/png")

    if (!clsid) {
        if (IsObject(cap)) {
            cap["fail"] := "MissingEncoderClsid"
            cap["lastStage"] := "SAVE"
        }

        if (debug)
            CAP_KV("SAVE FAIL", capId, "reason=MissingEncoderClsid", "ERROR")
        return false
    }

    ; Ensure folder exists
    try {
        dir := RegExReplace(outPath, "[\\/][^\\/]+$", "")
        if (dir && !DirExist(dir))
            DirCreate(dir)
    } catch {
    }

    hr := 2
    try {
        hr := DllCall("gdiplus.dll\GdipSaveImageToFile"
            , "ptr", pBitmap
            , "wstr", outPath
            , "ptr", clsid.Ptr
            , "ptr", 0
            , "uint")
    } catch as e {
        if (IsObject(cap)) {
            cap["fail"] := "GdipSaveImageToFile exception: " e.Message
            cap["lastStage"] := "SAVE"
        }

        if (debug)
            CAP_KV("SAVE FAIL", capId, "reason=Exception msg=" e.Message, "ERROR")
        return false
    }

    ok := (hr = 0)
    if (!ok) {
        if (IsObject(cap)) {
            cap["fail"] := "hr=" . hr
            cap["lastStage"] := "SAVE"
        }

        if (debug)
            CAP_KV("SAVE FAIL", capId, Format('reason=hr={} path="{}"', hr, outPath), "ERROR")
        return false
    }

    return true
}


AL_GdipDisposeImage(pBitmap) {
    if (pBitmap) {
        try {
            DllCall("gdiplus.dll\GdipDisposeImage", "ptr", pBitmap)
        } catch {
        }
    }
}


AL_GdipShutdown(*) {
    global GdipToken
    if (GdipToken) {
        Gdip_Shutdown(GdipToken)
        GdipToken := 0
    }
}


AL_GdipBitmapFromHWNDRect(hwnd, r, cap := 0) {
    global CAP_USE_DXGI
    ; Capture a screen-rect region from a WINDOW DC (HWND) using PrintWindow/BitBlt fallback.
    ; r is Rect in SCREEN coords (LTRB). hwnd is a valid window handle.
    capId := ""
    debug := false
    deep := false
    try {
        if (IsObject(cap)) {
            if (cap.Has("id"))
                capId := cap["id"]
            if (cap.Has("debug"))
                debug := cap["debug"]
            if (cap.Has("deep"))
                deep := cap["deep"]
        }
    } catch {
    }

    if (capId = "")
        capId := "NA"

    L := 0, T := 0, R := 0, B := 0
    try {
        L := r.L, T := r.T, R := r.R, B := r.B
    } catch {
        return 0
    }

    if (!IsNumber(L) || !IsNumber(T) || !IsNumber(R) || !IsNumber(B))
        return 0

    W := Max(1, R - L)
    H := Max(1, B - T)



; === HWND CAPTURE POLICY ===
; Default: DXGI only (stable rect/map), allow opt-in GDI/PrintWindow via cap.forceGDI=1.
forceGDI := 0
try {
    if (IsObject(cap) && cap.Has("forceGDI"))
        forceGDI := cap["forceGDI"] ? 1 : 0
} catch {
    forceGDI := 0
}

if (!forceGDI) {
    if (CAP_USE_DXGI) {
        rectAbs := Format("{},{},{},{}", L, T, R, B)
        bmp := CAP_CopyRect_DXGI(rectAbs)
        if (IsObject(cap)) {
            cap["method"] := "DXGI"
            cap["lastStage"] := "COPY"
            cap["fail"] := (bmp ? "" : "DXGI=0")
            cap["winErr"] := 0
        }
        return bmp
    } else {
        if (IsObject(cap)) {
            cap["method"] := "DXGI"
            cap["lastStage"] := "COPY"
            cap["fail"] := "DXGI disabled"
            cap["winErr"] := 0
        }
        return 0
    }
}


    tCopy := A_TickCount
    hdcWin := 0, hdcMem := 0, hbm := 0, obm := 0
    pBitmap := 0
    winErr := 0

    ; Resolve window top-left to convert SCREEN -> WINDOWDC coords
    wx := 0, wy := 0
    try {
        rc := Buffer(16, 0)
        if (DllCall("user32.dll\GetWindowRect", "ptr", hwnd, "ptr", rc, "int")) {
            wx := NumGet(rc, 0, "int")
            wy := NumGet(rc, 4, "int")
        }
    } catch {
        wx := 0, wy := 0
    }
    xSrc := L - wx
    ySrc := T - wy

    try {
        if (IsObject(cap) && cap.Has("coordBase") && cap["coordBase"] = "WND") {
            xSrc := L
            ySrc := T
        }
    } catch {
    }

    try {
        if (IsObject(cap)) {
            cap["lastStage"] := "COPY"
            cap["fail"] := ""
            cap["winErr"] := 0
        }

        ; Get window DC (includes non-client); fall back to client DC if needed
        hdcOwner := hwnd
hdcWin := DllCall("user32.dll\GetWindowDC", "ptr", hwnd, "ptr")
if (!hdcWin)
    hdcWin := DllCall("user32.dll\GetDC", "ptr", hwnd, "ptr")
if (!hdcWin) {
    hdcOwner := 0
    hdcWin := DllCall("user32.dll\GetDC", "ptr", 0, "ptr")
}

if (!hdcWin) {
            winErr := A_LastError
            if (IsObject(cap)) {
                cap["fail"] := "GetWindowDC/GetDC failed"
                cap["winErr"] := winErr
                cap["method"] := "HWND.DC"
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method=HWND.DC winErr={} msg=NoWindowDC hwnd=0x{}", winErr, Format("{:X}", hwnd+0)), "ERROR")
            return 0
        }

        hdcMem := DllCall("gdi32.dll\CreateCompatibleDC", "ptr", hdcWin, "ptr")
        hbm := DllCall("gdi32.dll\CreateCompatibleBitmap", "ptr", hdcWin, "int", W, "int", H, "ptr")
        if (!hdcMem || !hbm) {
            winErr := A_LastError
            if (IsObject(cap)) {
                cap["fail"] := "CreateCompatibleDC/Bitmap failed"
                cap["winErr"] := winErr
                cap["method"] := "HWND.CreateCompatible*"
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method=HWND.CreateCompatible winErr={} msg=AllocFail", winErr), "ERROR")
            return 0
        }

        obm := DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")

        ; Try PrintWindow first (often works for layered/accelerated windows)
        ok := 0

        printFlags := 0x00000002
        try {
            CAP_Log("PW HWND | " WinGetClass("ahk_id " hwnd))
        } catch {
        }
        if (!(printFlags & 0x00000002))
            CAP_Log("PW WARN | missing FULLCONTENT flag", "WARN")
        try {
            ok := DllCall("user32.dll\PrintWindow", "ptr", hwnd, "ptr", hdcMem, "uint", printFlags, "int")
        } catch {
            ok := 0
        }

        if (ok) {
            if (IsObject(cap))
                cap["method"] := "PrintWindow"
        } else {
            ok := 0
            if (IsObject(cap)) {
                try {
                    cap["method"] := "PrintWindow"
                } catch {
                }
                try {
                    cap["fail"] := "PrintWindow=0"
                } catch {
                }
            }
        }

        dur := A_TickCount - tCopy
        if (IsObject(cap))
            cap["copyMs"] := dur

        if (!ok) {
            winErr := A_LastError
            if (IsObject(cap)) {
                cap["winErr"] := winErr
                cap["fail"] := (cap.Has("fail") ? cap["fail"] : (cap.Has("method") ? cap["method"] : "HWND") " returned 0")
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method={} winErr={} msg={}"
                    , (IsObject(cap) && cap.Has("method") ? cap["method"] : "HWND")
                    , winErr
                    , (IsObject(cap) && cap.Has("fail") ? cap["fail"] : "Copy=0")), "ERROR")
            return 0
        }

        ; Convert HBITMAP -> GDI+ Bitmap
        try {
            pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
        } catch as e {
            pBitmap := 0
            if (IsObject(cap)) {
                cap["fail"] := "CreateBitmapFromHBITMAP ex: " e.Message
            }
        }

        if (debug) {
            if (pBitmap)
                CAP_KV("COPY", capId, Format("method={} ok=1 duration={}ms", (IsObject(cap) && cap.Has("method") ? cap["method"] : "HWND"), dur))
            else
                CAP_KV("COPY FAIL", capId, Format("method={} winErr={} msg={}"
                    , (IsObject(cap) && cap.Has("method") ? cap["method"] : "HWND")
                    , (IsObject(cap) && cap.Has("winErr") ? cap["winErr"] : 0)
                    , (IsObject(cap) && cap.Has("fail") && cap["fail"] != "" ? cap["fail"] : "HBITMAP->Bitmap=0")), "ERROR")
        }

        return pBitmap
    } catch as e {
        if (IsObject(cap)) {
            cap["fail"] := "HWND capture exception: " e.Message
            cap["winErr"] := A_LastError
            cap["method"] := "HWND.Exception"
        }

        if (debug)
            CAP_KV("COPY FAIL", capId, Format("method=HWND.Exception winErr={} msg={}", A_LastError, e.Message), "ERROR")
        return 0
    } finally {
        ; Always restore/release GDI handles (no leaks)
        if (hdcMem && obm) {
            try {
                DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", obm)
            } catch {
            }
        }

        if (hbm) {
            try {
                DllCall("gdi32.dll\DeleteObject", "ptr", hbm)
            } catch {
            }
        }

        if (hdcMem) {
            try {
                DllCall("gdi32.dll\DeleteDC", "ptr", hdcMem)
            } catch {
            }
        }

        if (hdcWin) {
            try {
                DllCall("user32.dll\ReleaseDC", "ptr", hdcOwner, "ptr", hdcWin)
            } catch {
            }
        }
    }
}

AL_GdipBitmapFromHWNDBitBlt(hwnd, r, cap := 0) {
    ; Minimal HWND BitBlt capture (WindowDC). r is Rect in SCREEN coords (LTRB).
    capId := ""
    debug := false
    try {
        if (IsObject(cap)) {
            if (cap.Has("id"))
                capId := cap["id"]
            if (cap.Has("debug"))
                debug := cap["debug"]
            cap["lastStage"] := "COPY"
            cap["fail"] := ""
            cap["winErr"] := 0
        }
    } catch {
    }

    if (capId = "")
        capId := "NA"

    L := 0, T := 0, R := 0, B := 0
    try {
        L := r.L, T := r.T, R := r.R, B := r.B
    } catch {
        return 0
    }
    W := R - L, H := B - T
    if (W <= 0 || H <= 0)
        return 0

    wx := 0, wy := 0, wr := 0, wb := 0
    try {
        winRect := Buffer(16, 0)
        if (!DllCall("user32.dll\GetWindowRect", "ptr", hwnd, "ptr", winRect, "int"))
            return 0
        wx := NumGet(winRect, 0, "int")
        wy := NumGet(winRect, 4, "int")
        wr := NumGet(winRect, 8, "int")
        wb := NumGet(winRect, 12, "int")
    } catch {
        return 0
    }

    xSrc := L - wx
    ySrc := T - wy

    hdcWin := 0
    hdcMem := 0
    hbm := 0
    obm := 0
    pBitmap := 0
    tCopy := A_TickCount

    try {
        hdcOwner := hwnd
hdcWin := DllCall("user32.dll\GetWindowDC", "ptr", hwnd, "ptr")
if (!hdcWin)
    hdcWin := DllCall("user32.dll\GetDC", "ptr", hwnd, "ptr")
if (!hdcWin) {
    hdcOwner := 0
    hdcWin := DllCall("user32.dll\GetDC", "ptr", 0, "ptr")
}

if (!hdcWin) {
            if (IsObject(cap)) {
                cap["fail"] := "GetWindowDC/GetDC=0"
                cap["winErr"] := A_LastError
                cap["method"] := "BitBlt(ScreenDC)"
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method=BitBlt(ScreenDC) winErr={} msg=NoWindowDC hwnd=0x{}", A_LastError, Format("{:X}", hwnd+0)), "ERROR")
            return 0
        }

        hdcMem := DllCall("gdi32.dll\CreateCompatibleDC", "ptr", hdcWin, "ptr")
        if (!hdcMem) {
            if (IsObject(cap)) {
                cap["fail"] := "CreateCompatibleDC=0"
                cap["winErr"] := A_LastError
                cap["method"] := "BitBlt(ScreenDC)"
            }
            return 0
        }

        hbm := DllCall("gdi32.dll\CreateCompatibleBitmap", "ptr", hdcWin, "int", W, "int", H, "ptr")
        if (!hbm) {
            if (IsObject(cap)) {
                cap["fail"] := "CreateCompatibleBitmap=0"
                cap["winErr"] := A_LastError
                cap["method"] := "BitBlt(ScreenDC)"
            }
            return 0
        }

        obm := DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")
        if (!obm) {
            if (IsObject(cap)) {
                cap["fail"] := "SelectObject=0"
                cap["winErr"] := A_LastError
                cap["method"] := "BitBlt(ScreenDC)"
            }
            return 0
        }

        rop := 0x00CC0020 | 0x40000000  ; SRCCOPY | CAPTUREBLT
        ok := DllCall("gdi32.dll\BitBlt"
            , "ptr", hdcMem
            , "int", 0, "int", 0, "int", W, "int", H
            , "ptr", hdcWin
            , "int", xSrc, "int", ySrc
            , "uint", rop
            , "int")

        if (IsObject(cap))
            cap["method"] := "BitBlt(ScreenDC)"

        ; Convert HBITMAP -> GDI+ Bitmap (may return 0 without throwing)
        try {
            pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
        } catch as e {
            pBitmap := 0
            if (IsObject(cap))
                cap["fail"] := "CreateBitmapFromHBITMAP ex: " e.Message
        }

        if (!pBitmap && IsObject(cap) && cap["fail"] = "")
            cap["fail"] := "CreateBitmapFromHBITMAP=0"

        dur := A_TickCount - tCopy
        if (IsObject(cap))
            cap["copyMs"] := dur

        if (debug) {
            if (pBitmap)
                CAP_KV("COPY", capId, Format("method=BitBlt(ScreenDC) ok=1 duration={}ms", dur))
            else
                CAP_KV("COPY FAIL", capId, Format("method=BitBlt(ScreenDC) ok=0 duration={}ms winErr={} msg={}", dur, (IsObject(cap) && cap.Has("winErr") ? cap["winErr"] : 0), (IsObject(cap) && cap.Has("fail") ? cap["fail"] : "BitBlt=0")), "ERROR")
        }

        return pBitmap
    } catch as e {
        if (IsObject(cap)) {
            cap["fail"] := "Exception: " e.Message
            cap["winErr"] := A_LastError
            cap["method"] := "BitBlt(ScreenDC)"
        }

        if (debug)
            CAP_KV("COPY FAIL", capId, Format("method=BitBlt(ScreenDC) winErr={} msg={}", A_LastError, e.Message), "ERROR")
        return 0
    } finally {
        if (hdcMem && obm)
            DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", obm)
        if (hbm)
            DllCall("gdi32.dll\DeleteObject", "ptr", hbm)
        if (hdcMem)
            DllCall("gdi32.dll\DeleteDC", "ptr", hdcMem)
        if (hdcWin)
            DllCall("user32.dll\ReleaseDC", "ptr", 0, "ptr", hdcWin)
    }
}



AL_Capture_RectToBMP(screenRect, outPath, opt := 0) {
    ; Returns true/false. Logs the full CAPTURE DEBUG MASTER checklist when enabled.
    global CAP_DEBUG, CAP_DEBUG_DEEP, GdipToken

    ; ---- Options (caller/srcMode/hwnd/debug/deep/id) ----
    caller := ""
    srcMode := "SCREEN"
    hwnd := 0
    method := ""
    useDXGI := CAP_USE_DXGI
    debug := CAP_DEBUG
    deep := CAP_DEBUG_DEEP
    capId := ""

    if (IsObject(opt)) {
        try {
            if (opt.Has("caller"))
                caller := opt["caller"]
            if (opt.Has("srcMode") && opt["srcMode"] != "")
                srcMode := opt["srcMode"]
            if (opt.Has("hwnd"))
                hwnd := opt["hwnd"]
            if (opt.Has("method") && opt["method"] != "")
                method := opt["method"]
            if (opt.Has("useDXGI"))
                useDXGI := opt["useDXGI"]
            if (opt.Has("debug"))
                debug := opt["debug"]
            if (opt.Has("deep"))
                deep := opt["deep"]
            if (opt.Has("id"))
                capId := opt["id"]
        } catch {
        }
    }
    ; normalize srcMode (avoid shadow/blank overrides)
    srcMode := StrUpper(Trim(srcMode))
    if (srcMode = "")
        srcMode := "SCREEN"
; FAST MODE override (F4): force SCREEN ROI-only, avoid PrintWindow/DXGI paths
global CAP_FAST_MODE
if (CAP_FAST_MODE) {
    srcMode := "SCREEN"
    hwnd := 0
    useDXGI := 0
    method := "AUTO"
}



    method := StrUpper(Trim(method))
    if (capId = "")
        capId := Format("{}_{}", FormatTime(A_Now, "yyyyMMdd_HHmmss"), A_TickCount)

    tStart := A_TickCount
    stage := "INIT"
    pBitmap := 0
    gdiMs := 0
    copyMs := 0
    saveMs := 0
    normalized := 0

    ; for DPI/desktop logging
    vx := 0, vy := 0, vw := 0, vh := 0
    sysDpi := 0, winDpi := 0, scale := 1.0
    monIdx := 0, monTotal := 0

    try {
        ; =========================
        ; 1) ENTRY / RECT EXTRACT
        ; =========================
        stage := "VALID"
        
        L := 0, T := 0, R := 0, B := 0
        if (!SC_RectUnpack_SAFE(screenRect, &L, &T, &R, &B)) {
            if (debug) {
                CAP_KV("START", capId, Format("rectAbs=NA w=NA h=NA srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller))
                CAP_KV("VALID FAIL", capId, Format("reason=NonRectObject srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller), "ERROR")
            }
            return false
        }

        if (!IsNumber(L) || !IsNumber(T) || !IsNumber(R) || !IsNumber(B)) {
            if (debug) {
                CAP_KV("START", capId, Format("rectAbs=NA w=NA h=NA srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller))
                CAP_KV("VALID FAIL", capId, Format("reason=NonNumericRect srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller), "ERROR")
            }

        ; Array input is ambiguous (could be [L,T,W,H]). Require already-normalized LTRB for Arrays.
        if (screenRect is Array) {
            if (R < L || B < T) {
                if (debug) {
                    CAP_KV("START", capId, Format("rectAbs=NA w=NA h=NA srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller))
                    CAP_KV("VALID FAIL", capId, Format("reason=RectArrayNotNormalized raw={},{},{},{} srcMode={} hwnd=0x{} caller={}", L, T, R, B, srcMode, Format("{:X}", hwnd+0), caller), "ERROR")
                    CAP_KV("EXIT", capId, "ok=0 stage=VALID", "ERROR")
                }
                return false
            }
        }
            return false
        }
        ; =========================
        ; FLOWLOCK (no refactor):
        ; Optionally force DXGI to capture RAW parent rect (debug only).
        ; Controlled by opt.forceParentAbs=1 so normal template capture can crop.
        ; =========================
        forceParentAbs := 0
        try {
            if (IsObject(opt) && opt.Has("forceParentAbs"))
                forceParentAbs := opt["forceParentAbs"] ? 1 : 0
        } catch {
            forceParentAbs := 0
        }

        if (forceParentAbs && srcMode = "HWND" && caller = "AL_L4_TemplateCapture") {
            global parentL, parentT, parentR, parentB
            if (IsNumber(parentL) && IsNumber(parentT) && IsNumber(parentR) && IsNumber(parentB)
                && (parentR - parentL) > 0 && (parentB - parentT) > 0) {
                L := parentL, T := parentT, R := parentR, B := parentB
            }
        }

        if (R < L) {
            tmp := L, L := R, R := tmp
            normalized := 1
        }

        if (B < T) {
            tmp := T, T := B, B := tmp
            normalized := 1
        }

        W := R - L
        H := B - T

        if (debug) {
            CAP_KV("START", capId, Format("rectAbs={},{},{},{} w={} h={} srcMode={} hwnd=0x{} caller={}", L, T, R, B, W, H, srcMode, Format("{:X}", hwnd+0), caller))
        }

        ; =========================
        ; 2) DPI + MONITOR
        ; =========================
        sysDpi := CAP_GetSystemDPI()
        winDpi := CAP_GetWindowDPI(hwnd, sysDpi)
        scale := Round(winDpi / (sysDpi ? sysDpi : 96), 3)

        CAP_GetVirtualDesktop(&vx, &vy, &vw, &vh)

        cx := L + (W // 2)
        cy := T + (H // 2)
        monIdx := CAP_GetMonitorIndexForPoint(cx, cy, &monTotal)

        if (debug) {
            CAP_KV("DPI", capId, Format("sysDpi={} winDpi={} scale={} monitorIndex={} total={} virtualDesktop={},{},{}x{}", sysDpi, winDpi, scale, monIdx, monTotal, vx, vy, vw, vh))
        }

        ; =========================
        ; 3) VALIDATION
        ; =========================
        wOK := (W > 0) ? 1 : 0
        hOK := (H > 0) ? 1 : 0
        inScreen := !(R <= vx || L >= (vx + vw) || B <= vy || T >= (vy + vh))

        if (debug) {
            CAP_KV("VALID", capId, Format("normalized={} w>0={} h>0={} inScreen={}", normalized, wOK, hOK, inScreen ? 1 : 0))
            if (deep)
                CAP_KV("RAWRECT", capId, Format("afterNormalize={},{},{},{} W={} H={}", L, T, R, B, W, H))
        }

        if (!wOK || !hOK) {
            stage := "VALID"
            if (debug)
                CAP_KV("VALID FAIL", capId, Format("reason=ZeroSize rectAbs={},{},{},{}", L, T, R, B), "ERROR")
            return false
        }

        if (!inScreen) {
            stage := "VALID"
            if (debug)
                CAP_KV("VALID FAIL", capId, Format("reason=OutOfScreen rectAbs={},{},{},{} v={},{},{}x{}", L, T, R, B, vx, vy, vw, vh), "ERROR")
            return false
        }

        ; =========================
        ; 4) GDI+
        ; =========================
        stage := "GDI"
        tGdi := A_TickCount

        ; FLOWLOCK: SCREEN must not start/log GDI+ inside CAP() (no refactor).
        ; FLOWLOCK: DXGI caller must not start/log GDI+ inside CAP() (no refactor).
        isDxgiCaller := (InStr(caller, "DXGI") ? 1 : 0)

        if (srcMode = "SCREEN" || isDxgiCaller) {
            if (!EnsureGdip(true)) {
                gdiMs := A_TickCount - tGdi
                if (debug)
                    CAP_KV("GDI+ FAIL", capId, Format("code=StartupFailed token={}", (IsSet(GdipToken) ? GdipToken : 0)), "ERROR")
                return false
            }
        } else {
            if (!EnsureGdip()) {
                gdiMs := A_TickCount - tGdi
                if (debug)
                    CAP_KV("GDI+ FAIL", capId, Format("code=StartupFailed token={}", (IsSet(GdipToken) ? GdipToken : 0)), "ERROR")
                return false
            }
        }

        gdiMs := A_TickCount - tGdi
        if (debug && srcMode != "SCREEN" && !isDxgiCaller)
            CAP_KV("GDI+ START", capId, Format("ok=1 token={}", (IsSet(GdipToken) ? GdipToken : 0)))

        ; =========================
        ; 5-7) BITMAP + COPY (delegated)
        ; =========================
        stage := "COPY"
        cap := Map("id", capId, "debug", debug, "deep", deep, "srcMode", srcMode, "hwnd", hwnd)
        cap["copyMs"] := 0
        cap["lastStage"] := ""
        cap["fail"] := ""
        cap["winErr"] := 0

        rNorm := __RectClass(L, T, R, B)

        rClient := 0
        rClient := 0
        ; Choose capture method based on srcMode/hwnd.
        bmp := 0   ; FIX: ensure defined before DXGI/GDI checks

        rectAbs := Format("{},{},{},{}", L, T, R, B)
        ; NOTE: SCREEN is handled as a terminal branch (independent pipeline) to avoid HWND/DXGI/GDI cross-contamination.

        ; ROUTE: log why branch is selected (debug only)
        if (debug)
            CAP_KV("ROUTE", capId, Format("route={} caller={} hwnd={} useDXGI={} method={}", srcMode, caller, hwnd, useDXGI, (method != "" ? method : "AUTO")))

        ; FLOWLOCK: SCREEN must be fully isolated. Capture now and skip HWND/DXGI/GDI pipelines.
        if (srcMode = "SCREEN") {
            ; isolate from any HWND state
            hwnd := 0
            try {
                cap["hwnd"] := 0
            } catch {
            }

            if (debug)
                CAP_KV("ROUTE", capId, "SCREEN early branch (isolated, no HWND/DXGI)")

            wScr := Max(1, R - L)
            hScr := Max(1, B - T)
            tGdiCopyScr := A_TickCount

            cap["method"] := "SCREEN"
            cap["lastStage"] := "COPY"

            bmp := pBitmap := Gdip_BitmapFromScreen(L "|" T "|" wScr "|" hScr)
            cap["copyMs"] := (A_TickCount - tGdiCopyScr)

            if (!bmp) {
                cap["fail"] := "SCREEN=0"
                cap["winErr"] := 0
                ; do not return here; let the common failure logger handle it below
            }
        } else if (srcMode = "HWND") {
            if (!hwnd || hwnd = 0) {
                if (debug)
                    CAP_KV("COPY FAIL", capId, Format("method=HWND winErr=0 msg=HWND mode but hwnd=0 caller={}", caller), "ERROR")
                return false
            }

            ; bring window to front to reduce occlusion artifacts
            DllCall("user32\ShowWindow", "ptr", hwnd, "int", 9) ; SW_RESTORE
            DllCall("user32\SetForegroundWindow", "ptr", hwnd)
            Sleep 50
            try {
                DllCall("dwmapi\DwmFlush")
            } catch {
            }

            if (method = "PRINTWINDOW") {
                ; HWND PrintWindow/GDI path (final image)
                tGdiCopy := A_TickCount
                cap["forceGDI"] := 1
                 cap["method"] := "PrintWindow"
                cap["lastStage"] := "COPY"

                ok := 0
                try {
                    ok := bmp := pBitmap := AL_GdipBitmapFromHWNDRect(hwnd, rNorm, cap)
                } catch {
                    ok := bmp := pBitmap := 0
                }

                cap["copyMs"] := (A_TickCount - tGdiCopy)

                ; FLOWLOCK: no HWND BitBlt / no SCREEN fallback inside CAP when srcMode="HWND" & method="PrintWindow"
                ; Caller will decide SCREEN fallback by calling AL_Capture_RectToBMP() again with srcMode="SCREEN".
                if (!ok) {
                    try {
                        cap["fail"] := "PrintWindow=0"
                    } catch {
                    }
                    try {
                        cap["winErr"] := (cap.Has("winErr") ? cap["winErr"] : A_LastError)
                    } catch {
                    }
                }

            } else {
                ; HWND DXGI path (rect/map)
                if (!CAP_USE_DXGI) {
                    cap["method"] := "DXGI"
                    cap["lastStage"] := "COPY"
                    cap["fail"] := "DXGI disabled"
                    cap["winErr"] := 0
                    return false
                }

                tDxgi := A_TickCount
                cap["method"] := "DXGI"
                cap["lastStage"] := "COPY"
                bmp := pBitmap := CAP_CopyRect_DXGI(rectAbs)
                cap["copyMs"] := (A_TickCount - tDxgi)

                if (!bmp) {
                    cap["fail"] := "DXGI=0"
                    cap["winErr"] := 0
                    ; do not return here; let the common failure logger handle it below
                }
            }
        }
        ; Guard: never fall back to GDI screen capture when srcMode is HWND or SCREEN
        if (!bmp && srcMode != "HWND" && srcMode != "SCREEN") {
            bmp := pBitmap := AL_GdipBitmapFromScreenRect(rNorm, cap)
        }

        copyMs := (cap.Has("copyMs") ? cap["copyMs"] : 0)

        if (!bmp) {
            stage := (cap.Has("lastStage") && cap["lastStage"] != "") ? cap["lastStage"] : "COPY"
            if (debug) {
                fail := (IsObject(cap) && cap.Has("fail") && cap["fail"] != "") ? cap["fail"] : "BitmapFromScreen=0"
                meth := (IsObject(cap) && cap.Has("method") && cap["method"] != "") ? cap["method"] : "Unknown"
                werr := (IsObject(cap) && cap.Has("winErr") ? cap["winErr"] : 0)
                CAP_KV("COPY FAIL", capId, Format("method={} winErr={} msg={}", meth, werr, fail), "ERROR")
            }
            return false
        }

        ; =========================
        ; 8) SAVE
        ; =========================
        stage := "SAVE"
        tSave := A_TickCount
        ; base eliminated: save uses bmp directly (no base/hBitmap/ptr)

        ; Alpha-flatten fix (DXGI may output pixels with A=0): draw onto opaque white canvas then save.
        bmpFlat := 0, gfxFlat := 0
        try {
            bw := Gdip_GetImageWidth(bmp), bh := Gdip_GetImageHeight(bmp)
            bmpFlat := Gdip_CreateBitmap(bw, bh)
            if (bmpFlat) {
                gfxFlat := Gdip_GraphicsFromImage(bmpFlat)
                if (gfxFlat) {
                    Gdip_GraphicsClear(gfxFlat, 0xFFFFFFFF) ; opaque white background
                    Gdip_DrawImage(gfxFlat, bmp, 0, 0, bw, bh)
                }
            }
        } catch {
        }

        if (gfxFlat)
            Gdip_DeleteGraphics(gfxFlat)

        if (bmpFlat) {
            ok := (Gdip_SaveBitmapToFile(bmpFlat, outPath) = 0)  ; save flattened (opaque) bitmap
            try {
                Gdip_DisposeImage(bmpFlat)
            } catch {
            }
        } else {
            ok := (Gdip_SaveBitmapToFile(bmp, outPath) = 0)  ; fallback: save original bmp
        }
        saveMs := A_TickCount - tSave

        if (!ok) {
            if (debug) {
                fail := (IsObject(cap) && cap.Has("fail") && cap["fail"] != "") ? cap["fail"] : "SaveFailed"
                CAP_KV("SAVE FAIL", capId, Format('reason={} path="{}"', fail, outPath), "ERROR")
            }
            return false
        }

        stage := "SUCCESS"
        if (debug) {
            sizeKB := ""
            try {
                sizeKB := Round(FileGetSize(outPath) / 1024, 1)
            } catch {
            }

            ext := ""
            try {
                ext := StrUpper(RegExReplace(outPath, ".*\.(\w+)$", "$1"))
            } catch {
            }

            CAP_KV("SAVE", capId, Format('ok=1 path="{}" size={}KB format={}', outPath, sizeKB, ext))
        }

        return true
    }
    catch as e {
        if (debug)
            CAP_KV("EXCEPTION", capId, Format("stage={} msg={} caller={}", stage, e.Message, caller), "ERROR")
        return false
    }
    finally {
        ; Always dispose bitmap pointer if allocated.
        if (pBitmap)
            AL_GdipDisposeImage(pBitmap)

        if (debug) {
            ; Object safety line (useful to spot unexpected return types upstream)
            nullFlag := (pBitmap ? 0 : 1)
            CAP_KV("RESULT", capId, Format("isObj={} type={} nullFlag={} pBitmap={}", (IsObject(pBitmap) ? 1 : 0), Type(pBitmap), nullFlag, (pBitmap ? 1 : 0)))

            totalMs := A_TickCount - tStart
            CAP_KV("PERF", capId, Format("total={}ms gdi={}ms copy={}ms save={}ms", totalMs, gdiMs, copyMs, saveMs))
            CAP_KV("EXIT", capId, Format("ok={} stage={}", (stage = "SUCCESS" ? 1 : 0), stage))
        }
    }
}



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

    ; --- AHK v2 SYNTAX NOTES (giúp tránh lỗi cú pháp khi file dài) ---
    ; 1) Else-chain: ưu tiên viết `} else if (...) {` / `} else {` cùng 1 dòng để tránh "Unexpected Else" do auto-format.
    ; 2) Map không có thuộc tính .L/.T: phải dùng m["L"], m["T"], m["R"], m["B"].
    ; 3) Tham số tuỳ chọn: dùng IsSet(x2) / IsSet(y2) trước khi đọc.
    ; 4) try/catch: luôn dùng block-form `try { ... } catch { ... }`.
    ; 5) Vẽ border: skip nếu w/h < 2 để tránh vẽ 1 điểm (w=0 h=0) khi đang drag.
    ; ---------------------------------------------------------------

UpdateBorderRect(x1, y1, x2, y2) {
    global borderG, __BORDER_LAST_TICK, F3_GUI_SHOW_BORDERS, parentHwnd, gBorderShowAll

    ShowBorderInit()

; ---------------------------
; 1) Normalize input rect (AHK v2 safe blocks)
; ⚠ RULES (v2):
;   - else must be on same line as closing brace: "} else {"
;   - else never follows try/for/while
;   - to avoid "Unexpected Else" in long functions, prefer flat if-blocks
; ---------------------------
; Support:
;   - coords: (x1,y1,x2,y2)
;   - Map/Object: x1
L := 0, T := 0, R := 0, B := 0

if (IsObject(x1)) {
    rect := x1
    if (Type(rect) = "Map") {
        if (rect.Has("L") && rect.Has("T") && rect.Has("R") && rect.Has("B")) {
            L := rect["L"], T := rect["T"], R := rect["R"], B := rect["B"]
        }
        if ((L = 0 && T = 0 && R = 0 && B = 0) && rect.Has("X") && rect.Has("Y") && rect.Has("W") && rect.Has("H")) {
            L := rect["X"], T := rect["Y"]
            R := rect["X"] + rect["W"], B := rect["Y"] + rect["H"]
        }
    } else {
        _L := "", _T := "", _R := "", _B := ""
        try {
            _L := rect.L
        } catch {
        }
        if (_L = "") {
            try {
                _L := rect.Left
            } catch {
            }
        }
        try {
            _T := rect.T
        } catch {
        }
        if (_T = "") {
            try {
                _T := rect.Top
            } catch {
            }
        }
        try {
            _R := rect.R
        } catch {
        }
        if (_R = "") {
            try {
                _R := rect.Right
            } catch {
            }
        }
        try {
            _B := rect.B
        } catch {
        }
        if (_B = "") {
            try {
                _B := rect.Bottom
            } catch {
            }
        }
        if (_L != "" && _T != "" && _R != "" && _B != "") {
            L := _L, T := _T, R := _R, B := _B
        }
    }
}

; coords path (no else-chains)
if (!IsObject(x1) && IsSet(x2) && IsSet(y2)) {
    L := Min(x1, x2)
    T := Min(y1, y2)
    R := Max(x1, x2)
    B := Max(y1, y2)
}
if (!IsObject(x1) && (!IsSet(x2) || !IsSet(y2))) {
    ; Called with a point/incomplete -> allow logs but skip draw later via size check
    L := x1
    T := (IsSet(y1) ? y1 : 0)
    R := L
    B := T
}

    __BORDER_LAST_TICK := A_TickCount

    ; ---------------------------
    ; 2) SCREEN-COORD normalization (ClientToScreen / DPI)
    ;    - If rect already looks like screen coords (within window rect), keep it.
    ;    - Else treat it as client coords and convert via ClientToScreen(0,0).
    ; ---------------------------
    hwnd := 0
    try {
        if (IsSet(parentHwnd) && parentHwnd)
            hwnd := parentHwnd
    } catch {
        hwnd := 0
    }

    try {
        Log("SRC inRect=" L "," T "," R "," B " hwnd=" (hwnd ? Format("0x{:X}", hwnd+0) : "0x0"), "DEBUG", "BORDER")
    } catch {
    }

    dx := 0, dy := 0
    alreadyScreen := 0
    if (hwnd) {
        win := 0
        try {
            win := GetWinRect(hwnd)
        } catch {
            win := 0
        }
        if (IsObject(win)) {
            if (L >= win["L"] - 4 && T >= win["T"] - 4 && R <= win["R"] + 4 && B <= win["B"] + 4) {
                alreadyScreen := 1
            } else {
                pt := Buffer(8, 0)
                NumPut("int", 0, pt, 0)
                NumPut("int", 0, pt, 4)
                okCTS := 0
                try {
                    okCTS := DllCall("user32.dll\ClientToScreen", "ptr", hwnd, "ptr", pt, "int")
                } catch {
                    okCTS := 0
                }
                if (okCTS) {
                    dx := NumGet(pt, 0, "int")
                    dy := NumGet(pt, 4, "int")
                    L += dx, R += dx
                    T += dy, B += dy
                } else {
                    try {
                        Log("WARN ClientToScreen failed hwnd=" Format("0x{:X}", hwnd+0), "DEBUG", "BORDER")
                    } catch {
                    }
                }
            }
        } else {
            try {
                Log("WARN GetWinRect failed hwnd=" Format("0x{:X}", hwnd+0), "DEBUG", "BORDER")
            } catch {
            }
        }
    }

    sysDpi := 96
    winDpi := 96
    try {
        sysDpi := CAP_GetSystemDPI()
    } catch {
        sysDpi := (A_ScreenDPI > 0 ? A_ScreenDPI : 96)
    }
    try {
        winDpi := CAP_GetWindowDPI(hwnd, sysDpi)
    } catch {
        winDpi := sysDpi
    }

    try {
        Log("SCREEN outRect=" L "," T "," R "," B
            " alreadyScreen=" alreadyScreen
            " dx=" dx " dy=" dy
            " sysDpi=" sysDpi " winDpi=" winDpi, "DEBUG", "BORDER")
    } catch {
    }

    ; ---------------------------
    ; 3) Validate + WARNs
    ; ---------------------------
    wRaw := (R - L)
    hRaw := (B - T)
    if (wRaw < 2 || hRaw < 2) {
        try {
            Log("WARN invalid size (<2) w=" wRaw " h=" hRaw " rect=" L "," T "," R "," B, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    vx := 0, vy := 0, vw := 0, vh := 0
    try {
        CAP_GetVirtualDesktop(&vx, &vy, &vw, &vh)
    } catch {
        vx := 0, vy := 0, vw := A_ScreenWidth, vh := A_ScreenHeight
    }
    if (vw <= 0)
        vw := A_ScreenWidth
    if (vh <= 0)
        vh := A_ScreenHeight

    if (L < vx || T < vy || R > vx + vw || B > vy + vh) {
        try {
            Log("WARN outOfScreen rect=" L "," T "," R "," B
                " desktop=" vx "," vy "," (vx+vw) "," (vy+vh), "DEBUG", "BORDER")
        } catch {
        }
    }

    ; ---------------------------
    ; 4) Draw border
    ; ---------------------------
    w := wRaw
    h := hRaw
    th := 2

    ; Ensure visible (HideBorder() may have hidden them)
    try {
        borderG["top"].Show("NA")
        borderG["bottom"].Show("NA")
        borderG["left"].Show("NA")
        borderG["right"].Show("NA")
    } catch {
    }

    ; Move is smoother than repeated Show(x y w h) -> less flicker
    try {
        borderG["top"].Move(L, T, w, th)
        borderG["bottom"].Move(L, B - th, w, th)
        borderG["left"].Move(L, T, th, h)
        borderG["right"].Move(R - th, T, th, h)
        ; keep border lines above topmost UI
        try {
            Border_SetTopMost(borderG["top"].Hwnd)
        } catch {
        }
        try {
            Border_SetTopMost(borderG["bottom"].Hwnd)
        } catch {
        }
        try {
            Border_SetTopMost(borderG["left"].Hwnd)
        } catch {
        }
        try {
            Border_SetTopMost(borderG["right"].Hwnd)
        } catch {
        }
    } catch {
    }


    ; Keep OrderInputs synced with border redraw (ALL ROI mode)
    try {
        if (gBorderShowAll) {
            Border_DrawOrderInputsAll()
            Border_BringOrderInputsToTop()
        }
    } catch {
    }
}




GetWinRect(hwnd) {
    x := 0
    y := 0
    w := 0
    h := 0
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch {
        return 0
    }
    return Map("L", x, "T", y, "R", x + w, "B", y + h, "W", w, "H", h)
}


Cleanup(*) {
    global borderG
    ; Destroy border overlay GUIs to avoid handle leaks on reload/exit.
    ; (Layer7) No UI calls here.
    try {
        for _, gg in borderG {
            try {
                gg.Destroy()
            } catch {
            }
        }
    } catch {
    }
}


; =========================================================
; Anchor Pack
; =========================================================
MakeEmptyAnchorPack() {
    p := Map()
    p["cluster"] := [] ; 5 points
    p["h"] := []       ; horizontal L
    p["v"] := []       ; vertical L
    return p
}


CountAnchorHits(x, y, anchors, thr) {
    hits := 0
    for _, a in anchors {
        dx := a["dx"]
        dy := a["dy"]
        c0 := a["col"]
        c1 := ""
        try {
            c1 := PixelGetColor(x + dx, y + dy, "RGB")
        } catch {
            continue
        }

        if (ColorNear(c1, c0, thr))
            hits += 1
    }
    return hits
}


SaveImageListsToIni() {
    global DIA_LIST, SCA_LIST, CFG_FILE, diaSel, scaSel

    IniWriteSafe(DIA_LIST.Length, CFG_FILE, "diamond_images", "count")
    IniWriteSafe(diaSel,          CFG_FILE, "diamond_images", "selected")

    prevDia := ToIntSafe(IniReadSafe(CFG_FILE, "diamond_images", "max", "0"), 0)
    if (prevDia < DIA_LIST.Length)
        prevDia := DIA_LIST.Length
    IniWriteSafe(prevDia, CFG_FILE, "diamond_images", "max")
    loop prevDia {
        i := A_Index
        sec := "diamond_" i
        if (i <= DIA_LIST.Length)
            IniWriteSafe(DIA_LIST[i], CFG_FILE, sec, "path")
        else
            IniWriteSafe("", CFG_FILE, sec, "path")
    }

    IniWriteSafe(SCA_LIST.Length, CFG_FILE, "scale_images", "count")
    IniWriteSafe(scaSel,          CFG_FILE, "scale_images", "selected")

    prevSca := ToIntSafe(IniReadSafe(CFG_FILE, "scale_images", "max", "0"), 0)
    if (prevSca < SCA_LIST.Length)
        prevSca := SCA_LIST.Length
    IniWriteSafe(prevSca, CFG_FILE, "scale_images", "max")
    loop prevSca {
        i := A_Index
        sec := "scale_" i
        if (i <= SCA_LIST.Length)
            IniWriteSafe(SCA_LIST[i], CFG_FILE, sec, "path")
        else
            IniWriteSafe("", CFG_FILE, sec, "path")
    }
}


; =========================================================
; GUI - Combos & click modes
; =========================================================
RefreshDiaCombo() {
    global cbDia, DIA_LIST, diaSel
    ClearComboItems(cbDia)
    items := []
    for idx, p in DIA_LIST
        items.Push(Format("{} | {}", idx, ShortName(p)))
    if (items.Length > 0) {
        cbDia.Add(items)
        if (diaSel < 1 || diaSel > items.Length)
            diaSel := 1
        try {
            cbDia.Choose(diaSel)
        } catch {
            try {
                cbDia.Text := items[diaSel]
            } catch {
            }
        }
    } else {
        try {
            cbDia.Text := ""
        } catch {
        }
    }
}


RefreshScaCombo() {
    global cbSca, SCA_LIST, scaSel
    ClearComboItems(cbSca)
    items := []
    for idx, p in SCA_LIST
        items.Push(Format("{} | {}", idx, ShortName(p)))
    if (items.Length > 0) {
        cbSca.Add(items)
        if (scaSel < 1 || scaSel > items.Length)
            scaSel := 1
        try {
            cbSca.Choose(scaSel)
        } catch {
            try {
                cbSca.Text := items[scaSel]
            } catch {
            }
        }
    } else {
        try {
            cbSca.Text := ""
        } catch {
        }
    }
}


; =========================================================
; Best match: priority top-most/left-most + jitter retry + anchor verify
; =========================================================
FindBestMatch(imgList, region, pack, &outX, &outY) {
    global anchorThr, anchorNeedCluster, anchorNeedH, anchorNeedV
    global retryMs, retryMinSleep, retryMaxSleep

    start := A_TickCount
    bestX := ""
    bestY := ""
    bestFound := false

    while (A_TickCount - start < retryMs) {
        bestFound := false
        bestX := ""
        bestY := ""

        for _, img in imgList {
            if (img = "" || !FileExist(img))
                continue

            if ImageSearchOne(img, region["L"], region["T"], region["R"], region["B"], &x, &y) {
                ; refine with L-axes before verify
                if (pack["h"].Length > 0 || pack["v"].Length > 0)
                    RefineByLAxes(&x, &y, pack, anchorThr)

                ; verify anchors
                if ((pack["cluster"].Length > 0) || (pack["h"].Length > 0) || (pack["v"].Length > 0)) {
                    if (!VerifyAnchorPack(x, y, pack, anchorThr, anchorNeedCluster, anchorNeedH, anchorNeedV))
                        continue
                }

                if (!bestFound) {
                    bestFound := true
                    bestX := x
                    bestY := y
                } else {
                    if (y < bestY || (y = bestY && x < bestX)) {
                        bestX := x
                        bestY := y
                    }
                }
            }
        }

        if (bestFound) {
            outX := bestX
            outY := bestY
            return true
        }

        ; jittered retry to dodge animation frames
        Sleep(Random(retryMinSleep, retryMaxSleep))
    }

    outX := ""
    outY := ""
    return false
}


MakeCachedRegion(last, fullRegion, box) {
    cx := last["x"]
    cy := last["y"]
    if (!IsNum(cx) || !IsNum(cy))
        return fullRegion

    cx := Integer(Number(cx))
    cy := Integer(Number(cy))
    L := fullRegion["L"]
    T := fullRegion["T"]
    R := fullRegion["R"]
    B := fullRegion["B"]

    l2 := Max(L, cx - box)
    t2 := Max(T, cy - box)
    r2 := Min(R, cx + box)
    b2 := Min(B, cy + box)

    if (r2 <= l2 || b2 <= t2)
        return fullRegion

    return Map("L", l2, "T", t2, "R", r2, "B", b2)
}

; -------------------------
; LOGIC / WORKFLOW / UI
; -------------------------




; =========================================================
; ScaleCycle - AHK v2 ONLY (NO v1)
;
; FIXES ADDED (the missing items you asked for):
;  - State-aware preflight (optional target exe/title)
;  - Cache invalidation on window move/resize/hwnd change
;  - Jittered retry (random sleep) to avoid animation frame lock
;  - L-anchor pack (H/V sets) + cluster, with majority thresholds
;  - Optional relative offset scaling by window size (simple normalize)
;  - Clip search regions to active window (hierarchy-ish coarse gate)
;
; Existing:
;  - Priority: pick match that appears first (top-most then left-most)
;  - F2 Scan toggles beside Diamond/Scale to set [runner]/[scale_runner]
;  - Cache region (small) -> full region fallback
;
; Hotkeys:
;   F1 = Toggle RUN/STOP
;   F2 = Scan Region (if enabled) OR Run once
; =========================================================

; ================= PATCH NOTES =================
; - Removed legacy AL_GdipGetEncoderClsid() implementation.
; - Added dynamic ImageCodecInfo-based encoder lookup (GDI+ safe).
; - Updated ShortName() to use StrSplit(p, "\") for correct basename handling.
; - Fixed mojibake string: "RUNNING (mojibake)" -> "RUNNING...".
; - Removed all Vietnamese text from this script.
; ==============================================


; =========================
; CORE (LOW-LEVEL) - MUST STAY ABOVE ALL LOGIC/UI
; =========================
; =========================================================
; ImageSearch helper
; =========================================================
ImageSearchOne(img, L, T, R, B, &x, &y) {
    global tolerance
    x := ""
    y := ""
    tol := ToIntSafe(tolerance, 40)
    if (tol < 0)
        tol := 0

    loop 2 {
        curTol := tol + (A_Index - 1) * 10
        opt := "*" curTol " " img
        try {
            ImageSearch(&x, &y, L, T, R, B, opt)
            if IsNum(x) && IsNum(y) {
                x := Integer(Number(x))
                y := Integer(Number(y))
                return true
            }
        } catch {
        }
    }
    x := ""
    y := ""
    return false
}


; =========================================================
; Mouse helpers
; =========================================================
MoveCursor(x, y) {
    xi := Integer(Number(x))
    yi := Integer(Number(y))
    SC_DllCall("user32.dll\SetCursorPos", "int", xi, "int", yi)
}


MouseClickLeft(count := 1) {
    global __DBG_CLICKPOLICY, __UI_IS_TESTING
    if (__DBG_CLICKPOLICY) {
        try {
            mx := 0
            my := 0
            MouseGetPos(&mx, &my)
            __DECIDE_Log("MouseClickLeft", "count=" count " isTesting=" __UI_IS_TESTING " mouse=" mx "," my)
        } catch {
        }
    }

    global __DBG_CLICKPOLICY, __UI_IS_TESTING
    if (__DBG_CLICKPOLICY) {
        try {
            MouseGetPos(&mx, &my)
            Log("CLICK_SEND | count=" count " x=" mx " y=" my " isTesting=" __UI_IS_TESTING, "DEBUG", "CLICK")
        } catch {
        }
    }
    ; Use Send-based click (mouse_event is deprecated but still supported).
    if (count <= 1) {
        Send "{Click}"
    } else {
        Send "{Click " count "}"
    }
    Sleep(25)
}


LearnAnchorPack(x, y, &packOut) {
    packOut := MakeEmptyAnchorPack()

    ; Cluster (anti-alias tolerant)
    pts := [[2,2], [10,2], [2,10], [10,10], [6,6]]
    for _, p in pts {
        dx := p[1]
        dy := p[2]
        col := ""
        try {
            col := PixelGetColor(x + dx, y + dy, "RGB")
        } catch {
            continue
        }
        packOut["cluster"].Push(Map("dx", dx, "dy", dy, "col", col))
    }

    ; L-anchors:
    ; Horizontal line sample (more sensitive to Y)
    hpts := [[4,2], [10,2], [16,2]]
    for _, p in hpts {
        dx := p[1]
        dy := p[2]
        col := ""
        try {
            col := PixelGetColor(x + dx, y + dy, "RGB")
        } catch {
            continue
        }
        packOut["h"].Push(Map("dx", dx, "dy", dy, "col", col))
    }

    ; Vertical line sample (more sensitive to X)
    vpts := [[2,4], [2,10], [2,16]]
    for _, p in vpts {
        dx := p[1]
        dy := p[2]
        col := ""
        try {
            col := PixelGetColor(x + dx, y + dy, "RGB")
        } catch {
            continue
        }
        packOut["v"].Push(Map("dx", dx, "dy", dy, "col", col))
    }
}


VerifyAnchorPack(x, y, pack, thr, needCluster, needH, needV) {
    ; Cluster majority
    if (pack["cluster"].Length > 0) {
        if (CountAnchorHits(x, y, pack["cluster"], thr) < needCluster)
            return false
    }
    ; H / V majority (L lock)
    if (pack["h"].Length > 0) {
        if (CountAnchorHits(x, y, pack["h"], thr) < needH)
            return false
    }

    if (pack["v"].Length > 0) {
        if (CountAnchorHits(x, y, pack["v"], thr) < needV)
            return false
    }
    return true
}


RefineByLAxes(&x, &y, pack, thr) {
    ; refine X using vertical anchors (lock X)
    if (pack["v"].Length > 0) {
        best := -1
        bestX := x
        for ox in [-3,-2,-1,0,1,2,3] {
            h := CountAnchorHits(x + ox, y, pack["v"], thr)
            if (h > best) {
                best := h
                bestX := x + ox
            }
        }
        x := bestX
    }
    ; refine Y using horizontal anchors (lock Y)
    if (pack["h"].Length > 0) {
        best := -1
        bestY := y
        for oy in [-3,-2,-1,0,1,2,3] {
            h := CountAnchorHits(x, y + oy, pack["h"], thr)
            if (h > best) {
                best := h
                bestY := y + oy
            }
        }
        y := bestY
    }
}


ColorNear(c1, c0, thr) {
    r1 := (c1 >> 16) & 255
    g1 := (c1 >> 8) & 255
    b1 := c1 & 255
    r0 := (c0 >> 16) & 255
    g0 := (c0 >> 8) & 255
    b0 := c0 & 255
    return (Abs(r1 - r0) <= thr && Abs(g1 - g0) <= thr && Abs(b1 - b0) <= thr)
}


; =========================================================
; INI - Image lists
; =========================================================
LoadImageListsFromIni() {
    global DIA_LIST, SCA_LIST, CFG_FILE, diaSel, scaSel
    DIA_LIST := []
    SCA_LIST := []

    diaCnt := ToIntSafe(IniReadSafe(CFG_FILE, "diamond_images", "count", "0"), 0)
    diaSel := ToIntSafe(IniReadSafe(CFG_FILE, "diamond_images", "selected", "1"), 1)
    if (diaCnt < 0)
        diaCnt := 0
    loop diaCnt {
        i := A_Index
        sec := "diamond_" i
        p := Trim(IniReadSafe(CFG_FILE, sec, "path", ""))
        if (p != "")
            DIA_LIST.Push(p)
    }

    if (diaSel < 1 || diaSel > DIA_LIST.Length)
        diaSel := 1

    scaCnt := ToIntSafe(IniReadSafe(CFG_FILE, "scale_images", "count", "0"), 0)
    scaSel := ToIntSafe(IniReadSafe(CFG_FILE, "scale_images", "selected", "1"), 1)
    if (scaCnt < 0)
        scaCnt := 0
    loop scaCnt {
        i := A_Index
        sec := "scale_" i
        p := Trim(IniReadSafe(CFG_FILE, sec, "path", ""))
        if (p != "")
            SCA_LIST.Push(p)
    }

    if (scaSel < 1 || scaSel > SCA_LIST.Length)
        scaSel := 1
}


; =========================================================
; INI: scans
; =========================================================
LoadScansFromIni() {
    global SCANS, CFG_FILE, maxScanKeep
    SCANS := []
    cnt := ToIntSafe(IniReadSafe(CFG_FILE, "scans", "count", "0"), 0)
    if (cnt < 0)
        cnt := 0
    loop cnt {
        i := A_Index
        sec := "scan_" i
        dL := IniReadSafe(CFG_FILE, sec, "diamondL", "")
        sL := IniReadSafe(CFG_FILE, sec, "scaleL", "")
        if (Trim(dL) = "" && Trim(sL) = "")
            continue
        rec := Map()
        rec["diaL"] := dL
        rec["diaT"] := IniReadSafe(CFG_FILE, sec, "diamondT", "")
        rec["diaR"] := IniReadSafe(CFG_FILE, sec, "diamondR", "")
        rec["diaB"] := IniReadSafe(CFG_FILE, sec, "diamondB", "")
        rec["scaL"] := sL
        rec["scaT"] := IniReadSafe(CFG_FILE, sec, "scaleT", "")
        rec["scaR"] := IniReadSafe(CFG_FILE, sec, "scaleR", "")
        rec["scaB"] := IniReadSafe(CFG_FILE, sec, "scaleB", "")
        rec["time"] := IniReadSafe(CFG_FILE, sec, "time", "")
        SCANS.Push(rec)
    }
    ; Cap scans loaded from INI
    if (maxScanKeep < 1)
        maxScanKeep := 1
    while (SCANS.Length > maxScanKeep)
        SCANS.Pop()
}



SaveScansToIni() {
    global SCANS, CFG_FILE
    IniWriteSafe(SCANS.Length, CFG_FILE, "scans", "count")

    prev := ToIntSafe(IniReadSafe(CFG_FILE, "scans", "max", "0"), 0)
    if (prev < SCANS.Length)
        prev := SCANS.Length
    IniWriteSafe(prev, CFG_FILE, "scans", "max")

    loop prev {
        i := A_Index
        sec := "scan_" i
        if (i <= SCANS.Length) {
            rec := SCANS[i]
            IniWriteSafe(rec["diaL"], CFG_FILE, sec, "diamondL")
            IniWriteSafe(rec["diaT"], CFG_FILE, sec, "diamondT")
            IniWriteSafe(rec["diaR"], CFG_FILE, sec, "diamondR")
            IniWriteSafe(rec["diaB"], CFG_FILE, sec, "diamondB")
            IniWriteSafe(rec["scaL"], CFG_FILE, sec, "scaleL")
            IniWriteSafe(rec["scaT"], CFG_FILE, sec, "scaleT")
            IniWriteSafe(rec["scaR"], CFG_FILE, sec, "scaleR")
            IniWriteSafe(rec["scaB"], CFG_FILE, sec, "scaleB")
            IniWriteSafe(rec["time"], CFG_FILE, sec, "time")
        } else {
            IniWriteSafe("", CFG_FILE, sec, "diamondL")
            IniWriteSafe("", CFG_FILE, sec, "diamondT")
            IniWriteSafe("", CFG_FILE, sec, "diamondR")
            IniWriteSafe("", CFG_FILE, sec, "diamondB")
            IniWriteSafe("", CFG_FILE, sec, "scaleL")
            IniWriteSafe("", CFG_FILE, sec, "scaleT")
            IniWriteSafe("", CFG_FILE, sec, "scaleR")
            IniWriteSafe("", CFG_FILE, sec, "scaleB")
            IniWriteSafe("", CFG_FILE, sec, "time")
        }
    }
}


SetModeCombos() {
    global cbDiaMode, cbScaMode, diamondClickMode, scaleClickMode
    try {
        cbDiaMode.Choose(diamondClickMode = 2 ? 2 : 1)
    } catch {
    }
    try {
        cbScaMode.Choose(scaleClickMode = 2 ? 2 : 1)
    } catch {
    }
}


SyncScanChecks() {
    global chkDiaScan, chkScaScan, f2ScanDia, f2ScanSca
    chkDiaScan.Value := f2ScanDia ? 1 : 0
    chkScaScan.Value := f2ScanSca ? 1 : 0
}


DiaOnChange(*) {
    global cbDia, diaSel, DIA_LIST
    v := SafeCtrlValue(cbDia)
    if (v >= 1 && v <= DIA_LIST.Length) {
        diaSel := v
        SaveImageListsToIni()
        SetStatus("Diamond selected #" diaSel)
    }
}


ScaOnChange(*) {
    global cbSca, scaSel, SCA_LIST
    v := SafeCtrlValue(cbSca)
    if (v >= 1 && v <= SCA_LIST.Length) {
        scaSel := v
        SaveImageListsToIni()
        SetStatus("Scale selected #" scaSel)
    }
}


DiaModeOnChange(*) {
    global cbDiaMode, diamondClickMode, CFG_FILE
    v := SafeCtrlValue(cbDiaMode)
    diamondClickMode := (v = 2) ? 2 : 1
    IniWriteSafe(diamondClickMode, CFG_FILE, "clickmodes", "diamond")
    SetStatus("Diamond mode: " (diamondClickMode=2 ? "Double" : "Click"))
}


ScaModeOnChange(*) {
    global cbScaMode, scaleClickMode, CFG_FILE
    v := SafeCtrlValue(cbScaMode)
    scaleClickMode := (v = 2) ? 2 : 1
    IniWriteSafe(scaleClickMode, CFG_FILE, "clickmodes", "scale")
    SetStatus("Scale mode: " (scaleClickMode=2 ? "Double" : "Click"))
}

; =========================================================
; F3 ROI ORDERING (GUI) + CLICK SEQUENCE
; =========================================================
SetF3OrderCombo() {
    global cbF3Order, F3_SORT_MODE
    try {
        ; Map sort mode -> ComboBox index
        idx := 1
        switch F3_SORT_MODE {
            case "LTR":   idx := 1
            case "RTL":   idx := 2
            case "TTB":   idx := 3
            case "BTT":   idx := 4
            case "SCORE": idx := 5
            case "AREA":  idx := 6
        }
        cbF3Order.Choose(idx)
    } catch {
    }
}

F3OrderOnChange(*) {
    global cbF3Order, F3_SORT_MODE, CFG_FILE
    v := SafeCtrlValue(cbF3Order)
    mode := "LTR"
    switch v {
        case 1: mode := "LTR"
        case 2: mode := "RTL"
        case 3: mode := "TTB"
        case 4: mode := "BTT"
        case 5: mode := "SCORE"
        case 6: mode := "AREA"
        default: mode := "LTR"
    }

    F3_SORT_MODE := mode
    try {
; ---------------- AI_SAFEZONE100:ROI_UI_MODULE_BEGIN -----------------
; ROI list / F3 GUI / overlay ordering. Keep state checks before actions.
; ---------------------------------------------------------------------
        IniWriteSafe(F3_SORT_MODE, CFG_FILE, "f3roi", "sort")
    } catch {
    }

    F3__ResortExisting()
    SetStatus("F3 ROI order: " F3_SORT_MODE)
}

F3RoiOnChange(*) {
    global cbF3Rois, F3_ROI_SELECTED, F3_ROI_LIST, cbF3RoiMode
    idx := SafeCtrlValue(cbF3Rois)
    if (idx < 1)
        idx := 1
    if (IsObject(F3_ROI_LIST) && idx > F3_ROI_LIST.Length)
        idx := F3_ROI_LIST.Length
    if (idx < 1)
        idx := 1
    F3_ROI_SELECTED := idx

    try {
        if (IsObject(F3_ROI_LIST) && F3_ROI_LIST.Length >= idx) {
            cbF3RoiMode.Choose(F3_ROI_LIST[idx]["mode"] = 2 ? 2 : 1)
        }
    } catch {
    }
}

F3RoiModeOnChange(*) {
    global cbF3RoiMode, F3_ROI_SELECTED, F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0)
        return

    idx := F3_ROI_SELECTED
    if (idx < 1 || idx > F3_ROI_LIST.Length)
        idx := 1

    v := SafeCtrlValue(cbF3RoiMode)
    mode := (v = 2) ? 2 : 1
    try {
        F3_ROI_LIST[idx]["mode"] := mode
    } catch {
    }

    ; Refresh labels to show mode per ROI
    RefreshF3RoiCombo(idx)
}

RefreshF3RoiCombo(keepIndex := 1) {
    global cbF3Rois, stF3RoiCount, F3_ROI_LIST, cbF3RoiMode
    if (!IsObject(cbF3Rois))
        return

    try {
        ClearComboItems(cbF3Rois)
    } catch {
    }

    labels := []
    if (IsObject(F3_ROI_LIST)) {
        for i, it in F3_ROI_LIST {
            cx := Round(it["cx"]) , cy := Round(it["cy"])
            w := it["w"] , h := it["h"]
            sc := it.Has("score") ? it["score"] : 0
            md := (it["mode"] = 2) ? "Double" : "Click"
            ord := it.Has("order") ? it["order"] : 0
            labels.Push(Format("{1:02d} | ord={2} | x={3} y={4} w={5} h={6} | score={7} | {8}", i, ord, cx, cy, w, h, Round(sc, 3), md))
        }
    }

    try {
        if (labels.Length > 0)
            cbF3Rois.Add(labels)
    } catch {
    }

    try {
        stF3RoiCount.Text := "ROIs: " (IsObject(F3_ROI_LIST) ? F3_ROI_LIST.Length : 0)
    } catch {
    }

    if (keepIndex < 1)
        keepIndex := 1
    if (IsObject(F3_ROI_LIST) && keepIndex > F3_ROI_LIST.Length)
        keepIndex := F3_ROI_LIST.Length

    try {
        if (labels.Length > 0) {
            cbF3Rois.Choose(keepIndex)
            ; sync mode combo for selected
            cbF3RoiMode.Choose(F3_ROI_LIST[keepIndex]["mode"] = 2 ? 2 : 1)
        } else {
            cbF3RoiMode.Choose(1)
        }
    } catch {
    }
}

F3PreviewSelected() {
    global F3_GUI_SHOW_BORDERS, btnF3Borders
    global F3_ROI_LIST, cbF3Rois, F3_ROI_PARENT_RECT

    ; MODE: PREVIEW one ROI only. Ensure multi-ROI overlay is OFF.
    if (F3_GUI_SHOW_BORDERS) {
        F3_GUI_SHOW_BORDERS := false
        try {
            btnF3Borders.Text := "Show Borders"
        } catch {
        }
        try {
            F3OverlayHide()
        } catch {
        }
    }

    ; Clear any leftover borders before switching mode.
    try {
        Border_ClearLinesForce("preview")
    } catch {
    }

    ; Ensure ROI list exists (auto-build from last parent if needed)
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        try {
            F3__BuildRoisFromLastParentForOverlay()
        } catch {
        }
    }
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        SetStatus("Overlay: no ROIs yet. Press F3 to set Parent, then scan.")
        try {
            Log("PREVIEW ROI: no ROIs", "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    idx := 0
    try {
        idx := cbF3Rois.Value
    } catch {
        idx := 0
    }
    if (idx < 1 || idx > F3_ROI_LIST.Length) {
        SetStatus("Preview: select a ROI first.")
        try {
            Log("PREVIEW ROI: bad idx=" idx, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    it := F3_ROI_LIST[idx]
    sr := 0

    ; Prefer stored screenRect
    if (IsObject(it) && it.Has("screenRect")) {
        try {
            sr := it["screenRect"]
        } catch {
            sr := 0
        }
    }

    ; Fallback: rectRel + last parent rect -> screenRect
    if (!IsObject(sr) && IsObject(it) && it.Has("rectRel") && IsObject(F3_ROI_PARENT_RECT)) {
        rr := 0
        try {
            rr := it["rectRel"]
        } catch {
            rr := 0
        }
        if (IsObject(rr)) {
            try {
                sr := AL_RelToScreen(F3_ROI_PARENT_RECT, rr)
            } catch {
                sr := 0
            }
        }
    }

    L := 0, T := 0, R := 0, B := 0
    if (SC_RectUnpack_SAFE(sr, &L, &T, &R, &B)) {
        UpdateBorderRect(L, T, R, B)
        try {
            Log("MODE=PREVIEW idx=" idx " L=" L " T=" T " R=" R " B=" B, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    try {
        Log("PREVIEW ROI: no valid screen rect idx=" idx, "DEBUG", "BORDER")
    } catch {
    }
}

F3RunSequence() {
    global F3_ROI_LIST, F3_OVERLAY_VISIBLE
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        SetStatus("F3 Run: no ROIs.")
        return
    }

    ; If any ROI has a manual order>0, click by that manual order (ascending).
    hasManual := false
    for _, it in F3_ROI_LIST {
        try {
            if (it.Has("order") && it["order"] > 0) {
                hasManual := true
                break
            }
        } catch {
        }
    }

    if (hasManual) {
        seq := []
        used := Map()
        seenOrd := Map()
        dupCount := 0
        for i, it in F3_ROI_LIST {
            ord := 0
            try {
                ord := it.Has("order") ? it["order"] : 0
            } catch {
                ord := 0
            }
            if (ord > 0) {
                ; detect duplicate orders (safe + deterministic tie-break)
                try {
                    if (seenOrd.Has(ord))
                        dupCount += 1
                    else
                        seenOrd[ord] := i
                } catch {
                }

                p := Map()
                p["ord"] := ord
                p["idx"] := i
                seq.Push(p)
                used[i] := true
            }
        }

        try {
            seq.Sort((a, b) => (a["ord"] < b["ord"] ? -1 : (a["ord"] > b["ord"] ? 1 : (a["idx"] < b["idx"] ? -1 : (a["idx"] > b["idx"] ? 1 : 0)))))
        } catch {
        }

        if (dupCount > 0) {
            try {
                Log("F3 Run WARN: duplicate manual orders dup=" dupCount, "WARN", "F3")
            } catch {
            }
        }

        if (F3_OVERLAY_VISIBLE) {
            ; PATCH SLOT: overlay ON => overlay makes master (click ordered only, no LTR remainder)
            SetStatus("F3 Run: clicking " seq.Length " ROI(s) by overlay order only...")
            for _, p in seq {
                i := p["idx"]
                F3__HighlightIndex(i, 260)
                Sleep 40
                F3__ClickIndex(i)
                Sleep 80
            }
        } else {
            rest := []
            for i, _ in F3_ROI_LIST {
                if (!used.Has(i))
                    rest.Push(i)
            }

            SetStatus("F3 Run: clicking " seq.Length " ROI(s) by overlay order + " rest.Length " ROI(s) remaining...")
            ; 1) assigned
            for _, p in seq {
                i := p["idx"]
                F3__HighlightIndex(i, 260)
                Sleep 40
                F3__ClickIndex(i)
                Sleep 80
            }
            ; 2) remaining (keeps current spatial sort)
            for _, i in rest {
                F3__HighlightIndex(i, 180)
                Sleep 30
                F3__ClickIndex(i)
                Sleep 80
            }
        }
    } else {
        SetStatus("F3 Run: clicking " F3_ROI_LIST.Length " ROI(s) in order...")
        ; Click each ROI in the current sorted list
        for i, it in F3_ROI_LIST {
            F3__HighlightIndex(i, 260)
            Sleep 40
            F3__ClickIndex(i)
            Sleep 80
        }
    }

    SetStatus("F3 Run: done.")
}


F3__HighlightIndex(idx, duration := 260) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return

    it := F3_ROI_LIST[idx]
    if (!IsObject(it) || !it.Has("screenRect"))
        return

    r := it["screenRect"]
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
        return
    try {
        ShowRectOverlay(L, T, R, B, duration)
    } catch {
    }
}

F3__ClickIndex(idx) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return

    it := F3_ROI_LIST[idx]
    if (!IsObject(it) || !it.Has("screenRect"))
        return

    r := it["screenRect"]
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
        return
    x := Floor((L + R) / 2)
    y := Floor((T + B) / 2)

    mode := 1
    try {
        mode := (it["mode"] = 2) ? 2 : 1
    } catch {
        mode := 1
    }

    try {
        MoveCursor(x, y)
    } catch {
        try {
            MouseMove(x, y, 0)
        } catch {
        }
    }
    Sleep 10
    try {
        MouseClickLeft(mode)
    } catch {
        ; fallback
        try {
            Click(x, y, mode)
        } catch {
            Click
            if (mode = 2)
                Click
        }
    }
}

F3__ResortExisting() {
    global F3_ROI_LIST, F3_SORT_MODE
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0)
        return

    try {
        F3__SortRoiItems(F3_ROI_LIST, F3_SORT_MODE)
    } catch {
    }

    RefreshF3RoiCombo(F3_ROI_SELECTED)
}

; ----------------------------------------------------------------------
; ⚠️ SYNTAX NOTE (AHK v2): If you ever see "Error: Missing comma" pointing
; to a function header with "ByRef" (e.g. F3__SortRoiItems(ByRef items,...))
; it usually means the parser got confused by the ByRef token in that spot.
; In v2, Objects/Arrays are already passed by reference (you can modify them
; inside the function and the caller sees the change). So we avoid ByRef here
; to prevent syntax pitfalls when patching/editing quickly.
; ----------------------------------------------------------------------
F3__SortRoiItems(items, mode) {
    ; items: array of roi-items, each has cx, cy, score, area
    if (!IsObject(items) || items.Length <= 1)
        return

    try {
        items.Sort((a, b) => F3__CompareRoi(a, b, mode))
    } catch {
        ; if Sort failed, keep original order
    }
}

F3__CompareRoi(a, b, mode) {
    ; return -1/0/1
    ax := a.Has("cx") ? a["cx"] : 0
    ay := a.Has("cy") ? a["cy"] : 0
    bx := b.Has("cx") ? b["cx"] : 0
    by := b.Has("cy") ? b["cy"] : 0
    ; NOTE (anti-syntax trap): In AutoHotkey v2, the word "as" is reserved (e.g. "catch as e").
    ; NOTE (anti-syntax trap): In AutoHotkey v2, the word "as" is reserved (e.g. catch as e).
    ; Do NOT name variables "as". Use aScore/bScore instead.
    ; Do NOT name variables "as". Use aScore/bScore instead.
    ; NOTE (anti-syntax trap): "as" is a reserved word in AHK v2 (e.g. catch as e).
    ; Avoid variable names: as, try, catch, class, global, static, etc.
    aScore := a.Has("score") ? a["score"] : 0
    bScore := b.Has("score") ? b["score"] : 0

    aa := a.Has("area") ? a["area"] : 0
    ba := b.Has("area") ? b["area"] : 0

    switch mode {
        case "LTR":
            if (ax != bx)
                return ax < bx ? -1 : 1
            if (ay != by)
                return ay < by ? -1 : 1
        case "RTL":
            if (ax != bx)
                return ax > bx ? -1 : 1
            if (ay != by)
                return ay < by ? -1 : 1
        case "TTB":
            if (ay != by)
                return ay < by ? -1 : 1
            if (ax != bx)
                return ax < bx ? -1 : 1
        case "BTT":
            if (ay != by)
                return ay > by ? -1 : 1
            if (ax != bx)
                return ax < bx ? -1 : 1
        case "SCORE":
            if (aScore != bScore)
                return aScore > bScore ? -1 : 1
            ; tie-break: left-to-right
            if (ax != bx)
                return ax < bx ? -1 : 1
        case "AREA":
            if (aa != ba)
                return aa > ba ? -1 : 1
            if (ax != bx)
                return ax < bx ? -1 : 1
        default:
            ; fallback LTR
            if (ax != bx)
                return ax < bx ? -1 : 1
            if (ay != by)
                return ay < by ? -1 : 1
    }

    return 0
}


; Build F3_ROI_LIST from AutoLearn filter candidates (F4) and apply user ordering.
; Returns: sorted candidate list (same objects as input, but reordered).
F3__ApplyOrderFromF4(parentRect, candidates) {
    global F3_ROI_LIST, F3_ROI_PARENT_RECT, F3_SORT_MODE, F3_OVERLAY_VISIBLE

    ; reset if empty
    if (!IsObject(candidates) || candidates.Length = 0) {
        F3_ROI_LIST := []
        F3_ROI_PARENT_RECT := 0
        try {
            RefreshF3RoiCombo(1)
        } catch {
        }
        return candidates
    }

    items := []
    for i, c in candidates {
        rr := c.rectRel
        L := rr.L, T := rr.T, R := rr.R, B := rr.B
        cx := (L + R) / 2
        cy := (T + B) / 2
        w := Abs(R - L)
        h := Abs(B - T)
        area := w * h
        sc := 0
        try {
            sc := c.score
        } catch {
            try {
                sc := c["score"]
            } catch {
                sc := 0
            }
        }
        srect := 0
        try {
            srect := AL_RelToScreen(parentRect, rr)
        } catch {
            srect := 0
        }

        it := Map()
        it["cand"] := c
        it["rectRel"] := rr
        it["cx"] := cx
        it["cy"] := cy
        it["w"] := w
        it["h"] := h
        it["area"] := area
        it["score"] := sc
        it["mode"] := 1
        it["order"] := 0
        if (IsObject(srect))
            it["screenRect"] := srect
        items.Push(it)
    }

    try {
        ; PATCH SLOT: overlay ON => do NOT force LTR sort (overlay order makes master)
        if (!(F3_OVERLAY_VISIBLE && F3_SORT_MODE = "LTR"))
            F3__SortRoiItems(items, F3_SORT_MODE)
    } catch {
    }

    F3_ROI_LIST := items
    F3_ROI_PARENT_RECT := parentRect

    ; Update GUI list if GUI exists
    try {
        RefreshF3RoiCombo(1)
    } catch {
    }

    ; If overlay is visible, rebuild borders/labels for the new ROI list.
    try {
        if (F3_OVERLAY_VISIBLE)
            F3OverlayRebuild()
    } catch {
    }

    sorted := []
    for _, it in items {
        sorted.Push(it["cand"])
    }
    return sorted
}

; =========================================================
; F3 OVERLAY ORDER ENGINE (Direct on-screen ordering)
; =========================================================
; Mục tiêu:
;   - Vẽ border + số thứ tự ngay trên màn hình (overlay).
;   - Click vào icon/border -> nhập số thứ tự (order) cho ROI đó.
;   - Drag icon/border -> tự động gán order theo thứ tự bạn kéo (1,2,3...).
;   - Run sẽ click theo order thủ công nếu có (order>0), nếu không có thì dùng sort mode hiện tại.
;
; Lưu ý quan trọng (để tránh lỗi cú pháp khi ChatGPT vá):
;   - AHK v2: Arrays/Objects đã là "reference" -> không cần ByRef cho items.
;   - Tránh đặt tên biến là từ khóa: as, try, catch, class, global...
; =========================================================

global F3_OVERLAY_GUI := 0
global F3_OVERLAY_VISIBLE := false
global F3_GUI_SHOW_BORDERS := false   ; GUI button state: show/hide overlay borders
global gBorderShowAll := false   ; Show Border ALL ROI mode flag
global BORDER_ORDERINPUTS := Map()
global BORDER_ORDEROVERRIDE := Map()
global F3_OVERLAY_CTRLS := []          ; mỗi phần tử: Map("top",ctrl,"bot",ctrl,"lef",ctrl,"rig",ctrl,"lbl",ctrl)
global F3_OVERLAY_NEXT := 1

global F3_OVERLAY_DRAG_IDX := 0
global F3_OVERLAY_DRAG_SX := 0
global F3_OVERLAY_DRAG_SY := 0
global F3_OVERLAY_DRAG_MOVED := false
global F3_OVERLAY_DRAG_THRESH := 6

global F3_OVERLAY_MSG_INSTALLED := false

; --- Overlay runtime init (prevents "global variable has not been assigned" in AHK v2) ---
; NOTE for future patches (để ChatGPT vá không vỡ):
;   - AHK v2: đọc biến global chưa gán (dù chỉ trong if) sẽ nổ runtime.
;   - Vì vậy: mọi biến global overlay phải có giá trị mặc định ở đây.
global F3_OVERLAY_HK_INSTALLED := false
global F3_OVERLAY_LASTCLICK_TICK := 0
global F3_OVERLAY_DRAG := Map("down", false, "idx", 0, "x", 0, "y", 0)

; Hotkeys (tùy chọn). Nếu bị trùng phím, đổi sang "" để tắt.
global F3_OVERLAY_HK_TOGGLE := ""   ; bật/tắt overlay
global F3_OVERLAY_HK_CLEAR  := ""   ; clear toàn bộ order (order=0)
global F3_OVERLAY_HK_RUN    := ""   ; chạy click theo order (gọi F3RunSequence)
; NOTE: Overlay is controlled from GUI button "Show Borders". Hotkeys are disabled by default to avoid conflicts.

InitF3OverlayHotkeys() {
    global F3_OVERLAY_HK_TOGGLE, F3_OVERLAY_HK_CLEAR, F3_OVERLAY_HK_RUN
    try {
        if (F3_OVERLAY_HK_TOGGLE != "")
            Hotkey(F3_OVERLAY_HK_TOGGLE, (*) => F3OverlayToggle())
    } catch {
    }
    try {
        if (F3_OVERLAY_HK_CLEAR != "")
            Hotkey(F3_OVERLAY_HK_CLEAR, (*) => F3OverlayClearAll())
    } catch {
    }
    try {
        if (F3_OVERLAY_HK_RUN != "")
            Hotkey(F3_OVERLAY_HK_RUN, (*) => F3RunSequence())
    } catch {
    }
}

; ===============================
; GUI button: Show/Hide all ROI borders (Overlay)
; ===============================
F3GuiToggleBorders() {
    global F3_GUI_SHOW_BORDERS, btnF3Borders, gBorderShowAll

    ; MODE: ALL ROI SPLIT (multi borders). Do NOT draw parent here.
    if (!F3_GUI_SHOW_BORDERS) {
        ; turning ON
        try {
            Border_ClearLinesForce("toggle->ON")
        } catch {
        }
        ; ensure overlay GUI is hidden to avoid black bar
        try {
            F3OverlayHide()
        } catch {
        }
        F3_GUI_SHOW_BORDERS := true
        gBorderShowAll := true
        ; Toggle ON: chỉ clear vẽ, KHÔNG destroy OrderInput
        try {
            Log("ToggleBorders ON -> DrawOrderInputsAll", "DEBUG", "ORDER")
        } catch {
        }
        try {
            Border_DrawOrderInputsAll()
        } catch {
        }
        try {
            btnF3Borders.Text := "Hide Borders"
        } catch {
        }
        ; draw ALL ROI borders from F3_ROI_LIST (each ROI = its own GUI set)
        try {
            F3GuiDrawAllRoiBorders()
        } catch {
        }
        try {
            Border_DrawOrderInputsAll()
        } catch {
        }
        try {
            Border_BringOrderInputsToTop()
        } catch {
        }
        return
    }

    ; turning OFF
    F3_GUI_SHOW_BORDERS := false
    gBorderShowAll := false
    Border_DestroyAllOrderInputs()  ; leaving ALL-ROI mode -> destroy inputs
    try {
        btnF3Borders.Text := "Show Borders"
    } catch {
    }
    try {
        F3OverlayHide()
    } catch {
    }
    try {
        Border_ClearLinesForce("toggle->OFF")
    } catch {
    }
}

; ===============================
; Helpers: ensure borders/overlay ON and draw from GUI buttons
; ===============================
F3GuiEnsureBordersOn() {
    global F3_GUI_SHOW_BORDERS, btnF3Borders, gBorderShowAll
    if (F3_GUI_SHOW_BORDERS)
        return
    F3_GUI_SHOW_BORDERS := true
    gBorderShowAll := true

    try {
        btnF3Borders.Text := "Hide Borders"
    } catch {
    }
    try {
        F3OverlayInstallHotkeys()
    } catch {
    }
    try {
        F3OverlayShow()
    } catch {
    }

    ; Ensure->ON: clear vẽ rồi vẽ lại OrderInput + borders
    try {
        Border_ClearLinesForce("ensure->ON")
    } catch {
    }
    try {
        Border_DrawOrderInputsAll()
    } catch {
    }
    try {
        F3GuiDrawAllRoiBorders()
    } catch {
    }
    try {
        Border_DrawOrderInputsAll()
    } catch {
    }
    try {
        Border_BringOrderInputsToTop()
    } catch {
    }
}


F3GuiShowParentBorder() {
    global F3_GUI_SHOW_BORDERS, btnF3Borders
    global parentL, parentT, parentR, parentB

    ; MODE: PARENT only. Ensure multi-ROI overlay is OFF.
    if (F3_GUI_SHOW_BORDERS) {
        F3_GUI_SHOW_BORDERS := false
        try {
            btnF3Borders.Text := "Show Borders"
        } catch {
        }
        try {
            F3OverlayHide()
        } catch {
        }
    }

    ; Clear any leftover borders before switching mode.
    try {
        Border_ClearLinesForce("parent")
    } catch {
    }

    L := 0, T := 0, R := 0, B := 0
    if (TryGetSelectedParentHist(&L, &T, &R, &B)) {
        UpdateBorderRect(L, T, R, B)
        try {
            Log("MODE=PARENT L=" L " T=" T " R=" R " B=" B, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    if (parentR > parentL && parentB > parentT) {
        UpdateBorderRect(parentL, parentT, parentR, parentB)
        try {
            Log("MODE=PARENT L=" parentL " T=" parentT " R=" parentR " B=" parentB, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    SetStatus("No parent region saved yet. Press F3 to set.")
    try {
        Log("MODE=PARENT no-parent", "DEBUG", "BORDER")
    } catch {
    }
}
; =====================================================================================
; Overlay hotkeys (click-through overlay). Double-click to set order, drag to swap/move.
; =====================================================================================
F3OverlayInstallHotkeys() {
    global F3_OVERLAY_HK_INSTALLED
    ; NOTE (để tránh lỗi như line 4916): AHK v2 sẽ crash nếu đọc global chưa gán.
    ; Vì vậy luôn dùng IsSet(...) khi check cờ, kể cả đã init mặc định ở phần globals.
    if (IsSet(F3_OVERLAY_HK_INSTALLED) && F3_OVERLAY_HK_INSTALLED)
        return
    F3_OVERLAY_HK_INSTALLED := true
    try {
        Hotkey("~LButton", F3Overlay_OnLButton, "On")
        Hotkey("~LButton Up", F3Overlay_OnLButtonUp, "On")
    } catch {
        ; ignore
    }
}

F3Overlay_OnLButton(*) {
    global F3_GUI_SHOW_BORDERS, F3_OVERLAY_DRAG, F3_OVERLAY_LASTCLICK_TICK, F3_ROI_LIST
    if (!F3_GUI_SHOW_BORDERS)
        return
    MouseGetPos &mx, &my
    idx := F3OverlayHitTest(mx, my)
    ; store drag start
    F3_OVERLAY_DRAG := Map("down", true, "idx", idx, "x", mx, "y", my)

    ; double-click assigns order
    isDbl := (A_PriorHotkey = "~LButton" && A_TimeSincePriorHotkey < 300)
    if (!isDbl)
        return
    if (idx <= 0)
        return

    it := F3_ROI_LIST[idx]
    cur := it.Has("order") ? it["order"] : 0
    ib := InputBox("Nhập số thứ tự click cho ROI này (1..99). Để trống = xoá.", "Set Order", cur)
    if (ib.Result != "OK")
        return
    val := Trim(ib.Value)
    if (val = "") {
        F3Overlay_SetOrderForIndex(idx, 0)
        return
    }
    if (!RegExMatch(val, "^\d+$"))
        return
    ord := Integer(val)
    if (ord < 0)
        ord := 0
    if (ord > 99)
        ord := 99
    F3Overlay_SetOrderForIndex(idx, ord)
}

F3Overlay_OnLButtonUp(*) {
    global F3_GUI_SHOW_BORDERS, F3_OVERLAY_DRAG
    if (!F3_GUI_SHOW_BORDERS)
        return
    if (!IsObject(F3_OVERLAY_DRAG) || !F3_OVERLAY_DRAG.Has("down") || !F3_OVERLAY_DRAG["down"])
        return
    MouseGetPos &mx, &my
    sx := F3_OVERLAY_DRAG["x"], sy := F3_OVERLAY_DRAG["y"], sidx := F3_OVERLAY_DRAG["idx"]
    F3_OVERLAY_DRAG["down"] := false

    if (sidx <= 0)
        return
    if (Abs(mx - sx) < 8 && Abs(my - sy) < 8)
        return

    tidx := F3OverlayHitTest(mx, my)
    if (tidx <= 0 || tidx = sidx)
        return

    F3Overlay_SwapOrMoveOrder(sidx, tidx)
}

F3Overlay_SetOrderForIndex(idx, ord) {
    global F3_ROI_LIST, F3_ROI_ORDER, F3_GUI_SHOW_BORDERS
    if (idx <= 0 || idx > F3_ROI_LIST.Length)
        return
    it := F3_ROI_LIST[idx]
    k := F3OverlayMakeKey(it)
    if (ord <= 0) {
        if (F3_ROI_ORDER.Has(k))
            F3_ROI_ORDER.Delete(k)
        it["order"] := 0
    } else {
        F3_ROI_ORDER[k] := ord
        it["order"] := ord
    }
    try {
        if (F3_GUI_SHOW_BORDERS)
            F3OverlayRebuild()
    } catch {
    }
    try {
        F3__RefreshRoiCombo()
    } catch {
    }
}

F3Overlay_SwapOrMoveOrder(aIdx, bIdx) {
    global F3_ROI_LIST
    if (aIdx <= 0 || bIdx <= 0)
        return
    a := F3_ROI_LIST[aIdx], b := F3_ROI_LIST[bIdx]
    oa := a.Has("order") ? a["order"] : 0
    ob := b.Has("order") ? b["order"] : 0

    ; If one side has an order, move it. If both have orders, swap.
    if (oa > 0 && ob = 0) {
        F3Overlay_SetOrderForIndex(bIdx, oa)
        F3Overlay_SetOrderForIndex(aIdx, 0)
        return
    }
    if (oa = 0 && ob > 0) {
        F3Overlay_SetOrderForIndex(aIdx, ob)
        F3Overlay_SetOrderForIndex(bIdx, 0)
        return
    }
    if (oa > 0 && ob > 0) {
        F3Overlay_SetOrderForIndex(aIdx, ob)
        F3Overlay_SetOrderForIndex(bIdx, oa)
        return
    }
}




F3OverlayToggle() {
    global F3_OVERLAY_VISIBLE
    if (F3_OVERLAY_VISIBLE)
        F3OverlayHide()
    else
        F3OverlayShow()
}


F3__BuildRoisFromLastParentForOverlay() {
    global F3_ROI_LIST, F3_SORT_MODE, F3_MULTI_ICON
    global AL_MULTI_MIN_W, AL_MULTI_MIN_H, AL_MULTI_MIN_CELLS, AL_MULTI_DILATE, AL_MULTI_DISABLE_NMS
    global AL_MULTI_RELAX_L3, AL_MULTI_H_TRANS_MAX, AL_MULTI_ALLOW_TEXTSTRIP
    global parentL, parentT, parentR, parentB

    ; Source of truth: selected history -> fallback to current parent globals
    L := 0, T := 0, R := 0, B := 0
    if (!TryGetSelectedParentHist(&L, &T, &R, &B)) {
        L := parentL, T := parentT, R := parentR, B := parentB
    }
    if (!(R > L && B > T)) {
        F3_ROI_LIST := []
        return false
    }

    rect := Rect(L, T, R, B)
    opts := AL_DefaultOpts()

    ; Multi-icon friendly opts (ROI split preview)
    if (F3_MULTI_ICON) {
                try {
            opts["minW"] := AL_MULTI_MIN_W
        } catch {
        }
                try {
            opts["minH"] := AL_MULTI_MIN_H
        } catch {
        }
                try {
            opts["minCells"] := AL_MULTI_MIN_CELLS
        } catch {
        }
                try {
            opts["dilate"] := AL_MULTI_DILATE
        } catch {
        }
        try {
            if (AL_MULTI_DISABLE_NMS)
                opts["nmsIou"] := 0.99
        } catch {
        }
                try {
            opts["allowTextStrip"] := AL_MULTI_ALLOW_TEXTSTRIP
        } catch {
        }
        try {
            if (AL_MULTI_RELAX_L3)
                opts["textTransHigh"] := AL_MULTI_H_TRANS_MAX
        } catch {
        }
    }

    ctx := ParentContext(rect, "", Map("dpi", A_ScreenDPI, "ts", A_Now))
    cands := []
    filt := []

    try {
        cands := AL_L2_Segment(ctx, opts)
    } catch {
        cands := []
    }

    try {
        filt := AL_L3_Filter(ctx, cands, opts)
    } catch {
        filt := []
    }

    try {
        F3__ApplyOrderFromF4(rect, filt)
    } catch {
        F3_ROI_LIST := []
    }

    return (IsObject(F3_ROI_LIST) && F3_ROI_LIST.Length > 0)
}


F3OverlayShow() {
    global F3_ROI_LIST, F3_OVERLAY_GUI
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        ; Auto-build ROI split from last F3 parent (history/INI) so "Show Borders" always has data.
        try {
            F3__BuildRoisFromLastParentForOverlay()
        } catch {
        }
    }
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        SetStatus("Overlay: no ROIs yet. Press F3 to set Parent, then Show Borders.")
        return
    }
    F3OverlayEnsureGui()
    F3OverlayRebuild()
    try {
        F3_OVERLAY_GUI.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NA")
    } catch {
        try {
            F3_OVERLAY_GUI.Show()
        } catch {
        }
    }
    global F3_OVERLAY_VISIBLE := true
    SetStatus("Overlay ON: Click=nhập số | Drag=auto 1,2,3... | Right-click=clear ROI")
}

F3OverlayHide() {
    global F3_OVERLAY_GUI, F3_OVERLAY_VISIBLE
    try {
        if (IsObject(F3_OVERLAY_GUI))
            F3_OVERLAY_GUI.Hide()
    } catch {
    }
    F3_OVERLAY_VISIBLE := false
    SetStatus("Overlay OFF.")
}

F3OverlayEnsureGui() {
    global F3_OVERLAY_GUI, F3_OVERLAY_MSG_INSTALLED
    if (IsObject(F3_OVERLAY_GUI))
        return

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20")
    g.MarginX := 0
    g.MarginY := 0
    ; nền tối nhẹ để thấy border/label (sẽ set transparency)
    g.BackColor := "010101"

    try {
        ; Show tiny first to avoid black flash before TransColor
        g.Show("x0 y0 w1 h1 NA")
    } catch {
        g.Show()
    }
    ; Không làm tối/đen màn hình: dùng TransColor để nền GUI trong suốt hoàn toàn.
    try {
        WinSetTransColor("010101 255", "ahk_id " g.Hwnd)
        try {
            Log("OVERLAY TransColor OK hwnd=" g.Hwnd, "DEBUG", "BORDER")
        } catch {
        }
    } catch as e {
        try {
            Log("OVERLAY TransColor FAIL hwnd=" g.Hwnd " err=" e.Message, "ERROR", "BORDER")
        } catch {
        }
    }
    ; Move to full screen after transparency setup (avoid desktop black bar)
    try {
        g.Move(0, 0, A_ScreenWidth, A_ScreenHeight)
    } catch {
    }
    F3_OVERLAY_GUI := g

    if (!F3_OVERLAY_MSG_INSTALLED) {
        ; Mouse messages (click/drag) cho overlay
        OnMessage(0x201, F3Overlay_WM_LBUTTONDOWN)   ; WM_LBUTTONDOWN
        OnMessage(0x200, F3Overlay_WM_MOUSEMOVE)     ; WM_MOUSEMOVE
        OnMessage(0x202, F3Overlay_WM_LBUTTONUP)     ; WM_LBUTTONUP
        OnMessage(0x205, F3Overlay_WM_RBUTTONUP)     ; WM_RBUTTONUP
        F3_OVERLAY_MSG_INSTALLED := true
    }
}

F3OverlayDestroyCtrls() {
    global F3_OVERLAY_CTRLS
    if (!IsObject(F3_OVERLAY_CTRLS))
        F3_OVERLAY_CTRLS := []

    for _, p in F3_OVERLAY_CTRLS {
        try {
            p["top"].Destroy()
        } catch {
        }
        try {
            p["bot"].Destroy()
        } catch {
        }
        try {
            p["lef"].Destroy()
        } catch {
        }
        try {
            p["rig"].Destroy()
        } catch {
        }
        try {
            p["lbl"].Destroy()
        } catch {
        }
    }
    F3_OVERLAY_CTRLS := []
}

F3OverlayRebuild() {
    global F3_OVERLAY_GUI, F3_ROI_LIST, F3_OVERLAY_CTRLS, F3_OVERLAY_NEXT, F3_ROI_PARENT_RECT
    if (!IsObject(F3_OVERLAY_GUI))
        return

    F3OverlayDestroyCtrls()

    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0)
        return

    ; next order = max(order)+1
    F3_OVERLAY_NEXT := F3OverlayComputeNext()

    thickness := 2
    for i, it in F3_ROI_LIST {
; --- FASTPATCH: convert rectRel -> screenRect using last parent rect (avoid relative-border offset) ---
if (IsObject(it) && it.Has("rectRel") && IsObject(F3_ROI_PARENT_RECT)) {
    rr := 0
    try {
        rr := it["rectRel"]
    } catch {
        rr := 0
    }
    if (IsObject(rr)) {
        try {
            sr := AL_RelToScreen(F3_ROI_PARENT_RECT, rr)
            if (IsObject(sr))
                it["screenRect"] := sr
        } catch as e {
            try {
                Log("OVERLAY RelToScreen FAIL i=" i " err=" e.Message, "ERROR", "BORDER")
            } catch {
            }
        }
    }
}
        if (!IsObject(it) || !it.Has("screenRect"))
            continue
        r := it["screenRect"]
        ; NOTE (anti-crash):
        ; screenRect đôi khi có thể bị lưu sai kiểu (Integer/Map/Array/String) do patch dài hoặc dữ liệu cũ.
        ; Tuyệt đối KHÔNG truy cập r.L/r.T/r.R/r.B trực tiếp (sẽ crash: "Integer has no property B").
        ; Luôn unpack bằng SC_RectUnpack_SAFE(...) để an toàn với mọi kiểu dữ liệu.
        L := 0, T := 0, R := 0, B := 0
        if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
            continue
; --- FASTPATCH: clamp to screen (avoid off-screen draw / black-bar artifacts) ---
L0 := L, T0 := T, R0 := R, B0 := B
if (L < 0)
    L := 0
if (T < 0)
    T := 0
if (R > A_ScreenWidth)
    R := A_ScreenWidth
if (B > A_ScreenHeight)
    B := A_ScreenHeight
if (L != L0 || T != T0 || R != R0 || B != B0) {
    try {
        Log("OVERLAY Clamp i=" i " from=" L0 "," T0 "," R0 "," B0 " to=" L "," T "," R "," B, "DEBUG", "BORDER")
    } catch {
    }
}
        W := Abs(R - L)
        H := Abs(B - T)
if (W < 2 || H < 2) {
    try {
        Log("OVERLAY Skip i=" i " invalidWH W=" W " H=" H " rect=" L "," T "," R "," B, "DEBUG", "BORDER")
    } catch {
    }
    continue
}

        ; 4 border lines
        top := F3_OVERLAY_GUI.AddText("x" L " y" T " w" W " h" thickness " BackgroundFF0000", "")
        bot := F3_OVERLAY_GUI.AddText("x" L " y" (B-thickness) " w" W " h" thickness " BackgroundFF0000", "")
        lef := F3_OVERLAY_GUI.AddText("x" L " y" T " w" thickness " h" H " BackgroundFF0000", "")
        rig := F3_OVERLAY_GUI.AddText("x" (R-thickness) " y" T " w" thickness " h" H " BackgroundFF0000", "")

        ; label (order number). Use SS_NOTIFY (+0x100) so Text can be clicked if needed.
        lbl := F3_OVERLAY_GUI.AddText("x" (L+2) " y" (T+2) " w60 h22 +0x100 BackgroundTrans cYellow", "")
        p := Map()
        p["top"] := top, p["bot"] := bot, p["lef"] := lef, p["rig"] := rig, p["lbl"] := lbl, p["idx"] := i
        F3_OVERLAY_CTRLS.Push(p)
    }

    F3OverlayUpdateLabels()
}

F3OverlayComputeNext() {
    global F3_ROI_LIST
    mx := 0
    if (!IsObject(F3_ROI_LIST))
        return 1
    for _, it in F3_ROI_LIST {
        try {
            if (it.Has("order") && it["order"] > mx)
                mx := it["order"]
        } catch {
        }
    }
    return mx + 1
}

F3OverlayUpdateLabels() {
    global F3_OVERLAY_CTRLS, F3_ROI_LIST, F3_OVERLAY_NEXT
    if (!IsObject(F3_OVERLAY_CTRLS) || !IsObject(F3_ROI_LIST))
        return

    ; keep next in sync
    F3_OVERLAY_NEXT := F3OverlayComputeNext()

    for _, p in F3_OVERLAY_CTRLS {
        idx := p["idx"]
        if (idx < 1 || idx > F3_ROI_LIST.Length)
            continue
        it := F3_ROI_LIST[idx]
        ord := 0
        md := 1
        ord := 0
        try {
            ord := it.Has("order") ? it["order"] : 0
        } catch {
            ord := 0
        }
        md := 1
        try {
            md := (it["mode"] = 2) ? 2 : 1
        } catch {
            md := 1
        }
        txt := ""
        if (ord > 0)
            txt := "" ord
        else
            txt := "(" idx ")"

        if (md = 2)
            txt .= "D"
        try {
            p["lbl"].Text := txt
        } catch {
        }
    }
}

F3OverlayClearAll() {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0)
        return
    for _, it in F3_ROI_LIST {
        try {
            it["order"] := 0
        } catch {
        }
    }
    F3OverlayUpdateLabels()
    try {
        RefreshF3RoiCombo(F3_ROI_SELECTED)
    } catch {
    }
    SetStatus("Overlay: cleared all orders.")
}

F3OverlayAssign(idx, ord, mode := 0) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return
    try {
        F3_ROI_LIST[idx]["order"] := ord
        if (mode = 2)
            F3_ROI_LIST[idx]["mode"] := 2
        else if (mode = 1)
            F3_ROI_LIST[idx]["mode"] := 1
    } catch {
    }
    F3OverlayUpdateLabels()
    try {
        RefreshF3RoiCombo(idx)
    } catch {
    }
}

F3OverlayClearOne(idx) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return
    try {
        F3_ROI_LIST[idx]["order"] := 0
    } catch {
    }
    F3OverlayUpdateLabels()
    try {
        RefreshF3RoiCombo(idx)
    } catch {
    }
}

F3OverlayAssignNext(idx, mode := 0) {
    global F3_OVERLAY_NEXT
    ord := F3_OVERLAY_NEXT
    if (ord < 1)
        ord := 1
    F3OverlayAssign(idx, ord, mode)
    F3_OVERLAY_NEXT := F3OverlayComputeNext()
}

F3OverlayPromptOrder(idx) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return

    cur := 0
    try {
        cur := F3_ROI_LIST[idx].Has("order") ? F3_ROI_LIST[idx]["order"] : 0
    } catch {
        cur := 0
    }
    ; Nhập số: 1..N. Mẹo: gõ "3d" để set DoubleClick cho ROI đó.
    ib := InputBox("Nhập thứ tự cho ROI #" idx " (vd: 1, 2, 3...).`nGõ 0 hoặc để trống để bỏ.`nGõ 'd' hậu tố (vd 3d) để set Double.", "Set ROI Order", "w360 h180", cur)
    if (ib.Result != "OK")
        return

    s := Trim(ib.Value)
    if (s = "") {
        F3OverlayClearOne(idx)
        return
    }

    isDouble := false
    if (RegExMatch(s, "i)d$")) {
        isDouble := true
        s := RegExReplace(s, "i)d$", "")
        s := Trim(s)
    }

    n := ToIntSafe(s, -1)
    if (n <= 0) {
        F3OverlayClearOne(idx)
        return
    }

    md := isDouble ? 2 : 1
    F3OverlayAssign(idx, n, md)
}

F3OverlayHitTest(x, y) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST))
        return 0
    for i, it in F3_ROI_LIST {
        if (!IsObject(it) || !it.Has("screenRect"))
            continue
        r := it["screenRect"]
        L := 0, T := 0, R := 0, B := 0
        if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
            continue
        if (x >= L && x <= R && y >= T && y <= B)
            return i
    }
    return 0
}


F3Overlay_IsOverlayHwnd(hwnd) {
    global F3_OVERLAY_GUI
    if (!IsObject(F3_OVERLAY_GUI))
        return false
    root := hwnd
    try {
        ; GA_ROOT = 2
        root := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
    } catch {
        root := hwnd
    }
    return (root = F3_OVERLAY_GUI.Hwnd)
}


F3Overlay_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global F3_GUI_SHOW_BORDERS
    if (F3_GUI_SHOW_BORDERS)
        return

    global F3_OVERLAY_GUI, F3_OVERLAY_VISIBLE, F3_OVERLAY_DRAG_IDX, F3_OVERLAY_DRAG_SX, F3_OVERLAY_DRAG_SY, F3_OVERLAY_DRAG_MOVED
    if (!F3_OVERLAY_VISIBLE || !IsObject(F3_OVERLAY_GUI))
        return
    if (!F3Overlay_IsOverlayHwnd(hwnd))
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos &mx, &my
    idx := F3OverlayHitTest(mx, my)
    if (idx < 1)
        return

    F3_OVERLAY_DRAG_IDX := idx
    F3_OVERLAY_DRAG_SX := mx
    F3_OVERLAY_DRAG_SY := my
    F3_OVERLAY_DRAG_MOVED := false
}

F3Overlay_WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global F3_GUI_SHOW_BORDERS
    if (F3_GUI_SHOW_BORDERS)
        return

    global F3_OVERLAY_VISIBLE, F3_OVERLAY_GUI, F3_OVERLAY_DRAG_IDX, F3_OVERLAY_DRAG_SX, F3_OVERLAY_DRAG_SY, F3_OVERLAY_DRAG_MOVED, F3_OVERLAY_DRAG_THRESH
    if (!F3_OVERLAY_VISIBLE || !IsObject(F3_OVERLAY_GUI))
        return
    if (!F3Overlay_IsOverlayHwnd(hwnd))
        return
    if (F3_OVERLAY_DRAG_IDX < 1)
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos &mx, &my
    dx := Abs(mx - F3_OVERLAY_DRAG_SX)
    dy := Abs(my - F3_OVERLAY_DRAG_SY)
    if (!F3_OVERLAY_DRAG_MOVED && (dx >= F3_OVERLAY_DRAG_THRESH || dy >= F3_OVERLAY_DRAG_THRESH)) {
        F3_OVERLAY_DRAG_MOVED := true
        ; highlight selected ROI while dragging
        try {
            F3__HighlightIndex(F3_OVERLAY_DRAG_IDX, 180)
        } catch {
        }
    }
}

F3Overlay_WM_LBUTTONUP(wParam, lParam, msg, hwnd) {
    global F3_GUI_SHOW_BORDERS
    if (F3_GUI_SHOW_BORDERS)
        return

    global F3_ROI_LIST
    global F3_OVERLAY_VISIBLE, F3_OVERLAY_GUI, F3_OVERLAY_DRAG_IDX, F3_OVERLAY_DRAG_MOVED
    if (!F3_OVERLAY_VISIBLE || !IsObject(F3_OVERLAY_GUI))
        return
    if (!F3Overlay_IsOverlayHwnd(hwnd))
        return

    idx := F3_OVERLAY_DRAG_IDX
    if (idx < 1)
        return

    ; If dragged -> auto-assign next order. If just click -> prompt input.
    ; Hold Shift while drag/click to set DoubleClick mode.
    isShift := GetKeyState("Shift", "P")
    md := isShift ? 2 : 1

    if (F3_OVERLAY_DRAG_MOVED) {
        F3OverlayAssignNext(idx, md)
        SetStatus("Overlay: drag assign ROI #" idx " -> order " (F3_ROI_LIST[idx].Has("order") ? F3_ROI_LIST[idx]["order"] : 0))
    } else {
        ; simple click -> input number
        F3OverlayPromptOrder(idx)
    }

    F3_OVERLAY_DRAG_IDX := 0
    F3_OVERLAY_DRAG_MOVED := false
}

F3Overlay_WM_RBUTTONUP(wParam, lParam, msg, hwnd) {
    global F3_GUI_SHOW_BORDERS
    if (F3_GUI_SHOW_BORDERS)
        return

    global F3_OVERLAY_VISIBLE, F3_OVERLAY_GUI
    if (!F3_OVERLAY_VISIBLE || !IsObject(F3_OVERLAY_GUI))
        return
    if (!F3Overlay_IsOverlayHwnd(hwnd))
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos &mx, &my
    idx := F3OverlayHitTest(mx, my)
    if (idx < 1)
        return

    F3OverlayClearOne(idx)
    SetStatus("Overlay: cleared ROI #" idx)
}





DiaScanToggle(*) {
    global chkDiaScan, chkScaScan, f2ScanDia, f2ScanSca
    f2ScanDia := (chkDiaScan.Value = 1)
    if (f2ScanDia) {
        f2ScanSca := false
        chkScaScan.Value := 0
        SetStatus("F2 Scan DIAMOND: drag to select [runner] region.")
    } else {
        SetStatus("F2 Scan DIAMOND: OFF.")
    }
}


ScaScanToggle(*) {
    global chkDiaScan, chkScaScan, f2ScanDia, f2ScanSca
    f2ScanSca := (chkScaScan.Value = 1)
    if (f2ScanSca) {
        f2ScanDia := false
        chkDiaScan.Value := 0
        SetStatus("F2 Scan SCALE: drag to select [scale_runner] region.")
    } else {
        SetStatus("F2 Scan SCALE: OFF.")
    }
}


; =========================================================
; Image list actions
; =========================================================
DiaAddImages(*) {
    global DIA_LIST, diaSel
    files := PickMultiImages("Select DIAMOND images (Ctrl/Shift)")
    if (files.Length = 0) {
        SetStatus("Diamond Add: canceled.")
        return
    }
    added := 0
    for p in files {
        if (p != "" && FileExist(p)) {
            DIA_LIST.Push(p)
            added += 1
        }
    }

    if (added = 0) {
        SetStatus("Diamond Add: no valid files.")
        return
    }
    diaSel := DIA_LIST.Length
    SaveImageListsToIni()
    RefreshDiaCombo()
    SetStatus("Diamond Add: +" added)
}


DiaUpdateSelected(*) {
    global DIA_LIST, diaSel
    if (DIA_LIST.Length < 1) {
        SetStatus("Diamond Update: list empty.")
        return
    }

    if (diaSel < 1 || diaSel > DIA_LIST.Length)
        diaSel := 1
    p := PickSingleImage("Select replacement DIAMOND image")
    if (p = "") {
        SetStatus("Diamond Update: canceled.")
        return
    }
    DIA_LIST[diaSel] := p
    SaveImageListsToIni()
    RefreshDiaCombo()
    SetStatus("Diamond Updated #" diaSel)
}


DiaRemoveSelected(*) {
    global DIA_LIST, diaSel
    if (DIA_LIST.Length < 1)
        return
    if (diaSel < 1 || diaSel > DIA_LIST.Length)
        diaSel := 1
    DIA_LIST.RemoveAt(diaSel)
    if (diaSel > DIA_LIST.Length)
        diaSel := DIA_LIST.Length
    if (diaSel < 1)
        diaSel := 1
    SaveImageListsToIni()
    RefreshDiaCombo()
    SetStatus("Diamond Removed.")
}


ScaAddImages(*) {
    global SCA_LIST, scaSel
    files := PickMultiImages("Select SCALE images (Ctrl/Shift)")
    if (files.Length = 0) {
        SetStatus("Scale Add: canceled.")
        return
    }
    added := 0
    for p in files {
        if (p != "" && FileExist(p)) {
            SCA_LIST.Push(p)
            added += 1
        }
    }

    if (added = 0) {
        SetStatus("Scale Add: no valid files.")
        return
    }
    scaSel := SCA_LIST.Length
    SaveImageListsToIni()
    RefreshScaCombo()
    SetStatus("Scale Add: +" added)
}


ScaUpdateSelected(*) {
    global SCA_LIST, scaSel
    if (SCA_LIST.Length < 1) {
        SetStatus("Scale Update: list empty.")
        return
    }

    if (scaSel < 1 || scaSel > SCA_LIST.Length)
        scaSel := 1
    p := PickSingleImage("Select replacement SCALE image")
    if (p = "") {
        SetStatus("Scale Update: canceled.")
        return
    }
    SCA_LIST[scaSel] := p
    SaveImageListsToIni()
    RefreshScaCombo()
    SetStatus("Scale Updated #" scaSel)
}


ScaRemoveSelected(*) {
    global SCA_LIST, scaSel
    if (SCA_LIST.Length < 1)
        return
    if (scaSel < 1 || scaSel > SCA_LIST.Length)
        scaSel := 1
    SCA_LIST.RemoveAt(scaSel)
    if (scaSel > SCA_LIST.Length)
        scaSel := SCA_LIST.Length
    if (scaSel < 1)
        scaSel := 1
    SaveImageListsToIni()
    RefreshScaCombo()
    SetStatus("Scale Removed.")
}


; =========================================================
; File pick helpers
; =========================================================
PickMultiImages(title) {
    global g
    g.Opt("-AlwaysOnTop")
    sel := FileSelect("M", "", title, "Images (*.png; *.bmp; *.jpg; *.jpeg)")
    g.Opt("+AlwaysOnTop")
    try {
        WinActivate("ahk_id " g.Hwnd)
    } catch {
    }
    return ParseFileSelectMulti(sel)
}


PickSingleImage(title) {
    global g
    g.Opt("-AlwaysOnTop")
    p := FileSelect(1, "", title, "Images (*.png; *.bmp; *.jpg; *.jpeg)")
    g.Opt("+AlwaysOnTop")
    try {
        WinActivate("ahk_id " g.Hwnd)
    } catch {
    }
    return p
}


ParseFileSelectMulti(sel) {
    files := []
    if (sel = "")
        return files

    try {
        if IsObject(sel) {
            for p in sel {
                if (p != "")
                    files.Push(p)
            }
            return files
        }
    } catch {
    }

    s := "" sel
    if InStr(s, "`n") {
        parts := StrSplit(s, "`n")
        dir := RTrim(parts[1], "")
        loop parts.Length - 1 {
            name := parts[A_Index + 1]
            if (name = "")
                continue
            files.Push(dir "" name)
        }
        return files
    }

    files.Push(s)
    return files
}


ShortName(p) {
    if (p = "")
        return ""
    parts := StrSplit(p, "\\")
    return parts.Length ? parts[parts.Length] : p
}


; =========================================================
; Save all settings
; =========================================================
SaveAllToIni(*) {
    global CFG_FILE
    global tolerance, baseV, lowV, highV, scaleDx, scaleDy, workflowMode, jumpPreEsc
    global edTol, edBase, edLow, edHigh, edDx, edDy

    tolerance := ToIntSafe(edTol.Value, 40)
    baseV := ToIntSafe(edBase.Value, 100)
    lowV  := ToIntSafe(edLow.Value, 96)
    highV := ToIntSafe(edHigh.Value, 104)
    scaleDx := ToIntSafe(edDx.Value, 160)
    scaleDy := ToIntSafe(edDy.Value, 0)

    IniWriteSafe(tolerance, CFG_FILE, "main", "tolerance")
    IniWriteSafe(baseV, CFG_FILE, "cycle", "base")
    IniWriteSafe(lowV,  CFG_FILE, "cycle", "low")
    IniWriteSafe(highV, CFG_FILE, "cycle", "high")
    IniWriteSafe(workflowMode, CFG_FILE, "workflow", "mode")
    IniWriteSafe(jumpPreEsc, CFG_FILE, "workflow", "jumpPreEsc")
    IniWriteSafe(scaleDx, CFG_FILE, "auto", "scaleDx")
    IniWriteSafe(scaleDy, CFG_FILE, "auto", "scaleDy")

    SaveImageListsToIni()
    SaveScansToIni()
    SetStatus("Saved INI.")
}


; =========================================================
; Scan history ComboBox
; =========================================================
RefreshScanCombo() {
    global cbScan, SCANS
    ClearComboItems(cbScan)
    if (SCANS.Length = 0) {
        try {
            cbScan.Text := ""
        } catch {
        }
        return
    }
    items := []
    idx := 0
    for rec in SCANS {
        idx += 1
        items.Push(ScanLine(idx, rec))
    }
    cbScan.Add(items)
    try {
        cbScan.Choose(1)
    } catch {
        try {
            cbScan.Text := items[1]
        } catch {
        }
    }
}


ScanLine(n, rec) {
    d := rec["diaL"] "," rec["diaT"] "," rec["diaR"] "," rec["diaB"]
    s := rec["scaL"] "," rec["scaT"] "," rec["scaR"] "," rec["scaB"]
    t := rec["time"]
    return "#" n " | Dia[" d "] | Sca[" s "] | " t
}


; =========================================================
; Cycle logic
; =========================================================
GetCycleValue(idx) {
    global baseV, lowV, highV
    if (idx = 1)
        return baseV
    if (idx = 2)
        return lowV
    if (idx = 3)
        return highV
    return baseV
}


NextCycleIndex(idx) {
    idx += 1
    if (idx > 4)
        idx := 1
    return idx
}



JumpNextFrame_Auto() {
    global nextCutKey, jumpPreEsc
    ; Ensure we are not typing into an edit box in CapCut
    if (jumpPreEsc)
        Send("{Esc}")

    if (nextCutKey != "")
        Send(nextCutKey)

    ; Small settle window (AUTO-ish). The DoOne matcher already retries; this just avoids the "first-frame" miss.
    Sleep(Random(55, 95))
}
; ---------------- AI_SAFEZONE100:CYCLE_MODULE_BEGIN ------------------
; Cycle/index helpers used by scale/sequence logic.
; ---------------------------------------------------------------------

; =========================================================
; Hotkeys logic
; =========================================================
F2Handler() {
    global busy, f2ScanDia, f2ScanSca
    if (busy)
        return

    if (f2ScanDia) {
        busy := true
        try {
            PickAndSaveRegion("runner", "F2 Scan Diamond: Drag with Left Mouse", &ok)
            SetStatus(ok ? "Saved [runner] region." : "Diamond region pick canceled.")
        } finally {
            busy := false
        }
        return
    }

    if (f2ScanSca) {
        busy := true
        try {
            PickAndSaveRegion("scale_runner", "F2 Scan Scale: Drag with Left Mouse", &ok)
            SetStatus(ok ? "Saved [scale_runner] region." : "Scale region pick canceled.")
        } finally {
            busy := false
        }
        return
    }

    RunOnce()
}


; =========================================================
; Parent region (tier0) - Hotkey F3 + History
; =========================================================
F3Handler() {
    
    global __UI_IS_TESTING, allowClickPick, busy, IS_RUNNING
    __ENTRY_Log("F3Handler", "IsTesting=" __UI_IS_TESTING " allowClickPick=" allowClickPick " busy=" (busy ? 1 : 0) " IS_RUNNING=" (IS_RUNNING ? 1 : 0))
    if (__UI_IS_TESTING) {
        Log("F3 IGNORE: UI test lock active", "DEBUG", "F3")
        return
    }
; PIPE STATE (F3 / LEARN):
    ;   INPUT_ACQUIRE → SEGMENTING → FILTERING → BEHAVIOR → EXTRACT_MODEL → SAVE_MODEL
    ; Ghi chú:
    ; - F3 là "học" model (setup). Thường hide GUI để pick/capture window sạch.
    ; - Không click theo kịch bản ở đây (click thuộc ACTION/STEP).

    global g
    global cbParentHist
    global parentL, parentT, parentR, parentB
    global parentHistSuppressStatusOnce
    global f3Atomic
    global parentHistHardLock
    global PARENT_HIST
    global lastF3CommitTick, lastF3CommitOk
    global iniFaulted
    global allowClickPick
    global busy

    global HAS_ACTION_SINCE_PICK
    ; Re-entry guard: prevents double F3 threads (button+hotkey, auto-repeat, etc.)
    static f3Busy := false
    if (f3Busy || busy) {
        try {
            Log("F3 IGNORE reentry busy=" (busy ? 1 : 0) " f3Busy=" (f3Busy ? 1 : 0), "DEBUG", "F3")
        } catch {
        }
        return
    }
    ; Reset ACTION gate for behavior learning (F3 chỉ pick/setup)
    HAS_ACTION_SINCE_PICK := false
    f3Busy := true
    busy := true

    ok := false
    lastF3CommitOk := false
    histBefore := PARENT_HIST.Length
    Log("F3 START ok=0 histBefore=" histBefore " iniFaulted=" iniFaulted " allowClickPick=" allowClickPick, "DEBUG", "F3")
    Critical "On"
    f3Atomic := true
    try {
        ; IMPORTANT: release GUI focus (prevents pick issues)
        try {
            g.Opt("-AlwaysOnTop")
        } catch {
        }
        Sleep 30

        ; Activate the window under the mouse so GUI doesn't steal the drag.
        MouseGetPos(,, &hwndUnder)
        if (hwndUnder && IsSet(g) && hwndUnder != g.Hwnd) {
            try {
                WinActivate("ahk_id " hwndUnder)
            } catch {
            }
        }
        Sleep 30

        ; Hide GUI during pick to avoid stealing clicks/focus
        try {
            g.Hide()
        } catch {
        }
        Sleep 20

        ; Atomic: pick -> save -> apply (no busy, no timer, no ComboBox dependency)
        PickAndSaveParentRegion(&ok)

        if (ok) {
            ; SNAPSHOT: lock the picked rect into locals so GUI/events can't overwrite the source of truth mid-flow
            L := parentL
            T := parentT
            R := parentR
            B := parentB

            wasNew := false
            ; F3 is user-driven: always add an entry so UX never feels like "it didn't save".
            AddOrTouchParentHistory(L, T, R, B, &wasNew, true)
            SaveParentHistoryToIni()
            Log("COMMIT history OK", "DEBUG", "F3")

            ; Refresh UI without letting Change handlers interfere with the atomic F3 flow
            try {
                cbParentHist.OnEvent("Change", ParentHistOnChange, 0)
            } catch {
            }
            parentHistHardLock := true
            RefreshParentHistCombo()
            try {
                cbParentHist.OnEvent("Change", ParentHistOnChange, 1)
            } catch {
            }
            ; Allow any queued Change messages from programmatic refresh to drain
            SetTimer(() => parentHistHardLock := false, -50)

            ; Atomic apply (use locals, not globals)
            ApplyParentRect(L, T, R, B, true)
            ShowRectOverlay(L, T, R, B, 1300)
            parentHistSuppressStatusOnce := true

            histAfter := PARENT_HIST.Length
            lastF3CommitTick := A_TickCount
            lastF3CommitOk := true
            msg := (wasNew ? "Saved [parent] + added to history." : "Saved [parent] (same as last, refreshed).")
            SetStatus(msg " History=" histAfter)
            Log("F3 COMMIT ok=1 histBefore=" histBefore " histAfter=" histAfter " tick=" lastF3CommitTick " iniFaulted=" iniFaulted, "DEBUG", "F3")
        } else {
            SetStatus("Parent region pick canceled.")
            Log("F3 END ok=0 (pick canceled) histBefore=" histBefore " iniFaulted=" iniFaulted, "DEBUG", "F3")
        }
    } finally {
        busy := false
        f3Busy := false
        f3Atomic := false
        try {
            g.Show()
        } catch {
        }
        try {
            g.Opt("+AlwaysOnTop")
        } catch {
        }
        Log("F3 END ok=" (ok ? 1 : 0), "DEBUG", "F3")
        Critical "Off"
    }
}


ShowCurrentParent() {
    global busy
    global parentL, parentT, parentR, parentB
    global DBG_F3_DIM_TOOLTIP
    global targetExe, targetTitle

    if (busy)
        return

    ; Prefer showing the currently selected history entry (more intuitive).
    if (TryGetSelectedParentHist(&L, &T, &R, &B)) {
        ApplyParentRect(L, T, R, B, true)
        ShowRectOverlay(L, T, R, B, 1300)
        SetStatus("Showing selected Parent history region.")
        return
    }

    if (parentR > parentL && parentB > parentT) {
        ShowRectOverlay(parentL, parentT, parentR, parentB, 1300)
        SetStatus("Showing current [parent] region.")
        return
    }
    SetStatus("No parent region saved yet. Press F3 to set.")
}


PickAndSaveParentRegion(&ok) {
    global CFG_FILE
    global parentL, parentT, parentR, parentB
    global DBG_F3_DIM_TOOLTIP
    global allowClickPick

    ok := false
    pickMsg := allowClickPick ? "F3 Set Parent: Drag OR Click with Left Mouse  (ESC=cancel)" : "F3 Set Parent: Drag with Left Mouse  (ESC=cancel)"
    SetStatus(pickMsg)
    Log("F3 PICK begin allowClickPick=" allowClickPick, "DEBUG", "F3")

    ; --- PICK SNAPSHOT (fix overwrite/double-call symptoms) ---
    ; Step 1) Take the raw return
    pick0 := PickRegionDrag(!allowClickPick)

    ; Step 2) Hard type guard BEFORE any indexing
    if (!IsObject(pick0) || Type(pick0) != "Map") {
        SetStatus("F3 Set Parent: canceled (non-map).")
        rType := IsObject(pick0) ? Type(pick0) : Type(pick0)
        rRepr := IsObject(pick0) ? "<obj:" rType ">" : pick0
        Log("F3 PICK fail non-map r=" rRepr " type=" rType, "DEBUG", "F3")
        return
    }

    ; Step 3) Snapshot-clone immediately, then NEVER touch pick0 again
    ; This isolates the F3 flow from any accidental overwrite / reuse of the same var name elsewhere.
    pick := Map()
    for k, v in pick0
        pick[k] := v
    pick0 := ""  ; drop reference (debug-friendly)

    if (!pick.Has("ok")) {
        SetStatus("F3 Set Parent: canceled (missing-ok).")
        Log("F3 PICK fail missing-ok", "DEBUG", "F3")
        return
    }

    if (!pick["ok"]) {
        reason := pick.Has("reason") ? pick["reason"] : "unknown"
        SetStatus("F3 Set Parent: canceled (" reason ").")
        Log("F3 PICK fail reason=" reason, "DEBUG", "F3")
        return
    }

    if (!pick.Has("L") || !pick.Has("T") || !pick.Has("R") || !pick.Has("B")) {
        SetStatus("F3 Set Parent: canceled (bad-data).")
        Log("F3 PICK fail bad-data keys missing", "DEBUG", "F3")
        return
    }

    ; Avoid any crash here (some users reported rare cases where map becomes non-indexable).
    try {
        L := pick["L"]
        T := pick["T"]
        R := pick["R"]
        B := pick["B"]
        hPicked := (pick.Has("hwnd") ? pick["hwnd"] : 0)
    } catch as e {
        SetStatus("F3 Set Parent: canceled (bad-return).")
        Log("F3 PICK fail bad-return type=" Type(pick) " err=" e.Message, "DEBUG", "F3")
        return
    }

    if (DBG_F3_DIM_TOOLTIP) {
        ToolTip("DEBUG F3: W=" (R - L) "  H=" (B - T))
        SetTimer(() => ToolTip(), -800)
    }

    ; NOTE: Do NOT reject here. PickRegionDrag() already enforces min size + clamps safely.
    ; Some edge cases (very fast drag / near screen edges) can still yield collapsed width/height.
    ; We repair to a minimum size instead of returning with ok=false.
    minSz := 5
    sw := A_ScreenWidth
    sh := A_ScreenHeight

    rawW := R - L
    rawH := B - T

    ; Optional debug (shows raw dimensions before repair)
    if (DBG_F3_DIM_TOOLTIP) {
        ToolTip("DEBUG F3 RAW: W=" rawW "  H=" rawH)
        SetTimer(() => ToolTip(), -800)
    }

    ; Expand tiny/collapsed selections
    if (rawW < minSz)
        R := L + minSz
    if (rawH < minSz)
        B := T + minSz

    ; Shift to keep inside screen bounds (CoordMode Screen)
    if (R > sw - 1) {
        dx := R - (sw - 1)
        L -= dx
        R := sw - 1
    }

    if (L < 0) {
        dx := -L
        L := 0
        R += dx
    }

    if (B > sh - 1) {
        dy := B - (sh - 1)
        T -= dy
        B := sh - 1
    }

    if (T < 0) {
        dy := -T
        T := 0
        B += dy
    }

    ; Final safety: re-enforce min size without collapsing
    if (R - L < minSz) {
        if (L + minSz <= sw - 1) {
            R := L + minSz
        } else {
            R := sw - 1
            L := Max(0, R - minSz)
        }
    }

    if (B - T < minSz) {
        if (T + minSz <= sh - 1) {
            B := T + minSz
        } else {
            B := sh - 1
            T := Max(0, B - minSz)
        }
    }

    wL := IniWriteSafe(L, CFG_FILE, "parent", "L")
    wT := IniWriteSafe(T, CFG_FILE, "parent", "T")
    wR := IniWriteSafe(R, CFG_FILE, "parent", "R")
    wB := IniWriteSafe(B, CFG_FILE, "parent", "B")
    wH := IniWriteSafe(hPicked, CFG_FILE, "parent", "hwnd")
    Log("F3 INI write parent okL=" wL " okT=" wT " okR=" wR " okB=" wB " okH=" wH " hwnd=" Format("0x{:X}", hPicked+0) " rect=" L "," T "," R "," B, "DEBUG", "F3")

    parentL := L
    parentT := T
    parentR := R
    parentB := B
    global parentHwnd := hPicked
    ok := true
}


ApplyParentRect(L, T, R, B, persist := true) {
    global parentL, parentT, parentR, parentB
    global DBG_F3_DIM_TOOLTIP, CFG_FILE
    parentL := L
    parentT := T
    parentR := R
    parentB := B
    if (persist) {
        IniWriteSafe(parentL, CFG_FILE, "parent", "L")
        IniWriteSafe(parentT, CFG_FILE, "parent", "T")
        IniWriteSafe(parentR, CFG_FILE, "parent", "R")
        IniWriteSafe(parentB, CFG_FILE, "parent", "B")
    }
}


TryGetSelectedParentHist(&L, &T, &R, &B) {
    global cbParentHist, PARENT_HIST
    L := 0
    T := 0
    R := 0
    B := 0

    if (PARENT_HIST.Length < 1)
        return false

    idx := 0
    try {
        idx := cbParentHist.Value
    } catch {
        idx := 0
    }

    if (idx < 1 || idx > PARENT_HIST.Length) {
        txt := ""
        try {
            txt := cbParentHist.Text
        } catch {
            return false
        }
        if RegExMatch(txt, "i)^\s*#\s*(\d+)", &m) {
            idx := ToIntSafe(m[1], 0)
        }
    }

    if (idx < 1 || idx > PARENT_HIST.Length)
        return false

    rec := PARENT_HIST[idx]
    if (!IsObject(rec) || Type(rec) != "Map")
        return false
    if (!rec.Has("L") || !rec.Has("T") || !rec.Has("R") || !rec.Has("B"))
        return false

    L := rec["L"]
    T := rec["T"]
    R := rec["R"]
    B := rec["B"]
    return (R > L && B > T)
}


; forceAdd=true is used by F3 so each pick is visibly recorded (better UX).
AddOrTouchParentHistory(L, T, R, B, &wasNew, forceAdd := false) {
    global PARENT_HIST

    wasNew := false
    now := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") "." Format("{:03}", A_MSec)

    ; If identical to newest, just refresh its timestamp (unless caller forces add).
    if (!forceAdd && PARENT_HIST.Length > 0) {
        top := PARENT_HIST[1]
        if (IsObject(top) && Type(top) = "Map" && top.Has("L") && top.Has("T") && top.Has("R") && top.Has("B")) {
            if (top["L"] = L && top["T"] = T && top["R"] = R && top["B"] = B) {
                top["time"] := now
                return
            }
        }
    }

    rec := Map("L", L, "T", T, "R", R, "B", B, "time", now)
    PARENT_HIST.InsertAt(1, rec)
    wasNew := true

    ; Limit history length
    maxKeep := 20
    while (PARENT_HIST.Length > maxKeep) {
        PARENT_HIST.Pop()
    }
}


LoadParentHistoryFromIni() {
    global PARENT_HIST, CFG_FILE
    PARENT_HIST := []

    ; Load into a temp array first, then normalize ordering so index 1 is ALWAYS newest.
    tmp := []

    cnt := ToIntSafe(IniReadSafe(CFG_FILE, "parent_history", "count", "0"), 0)
    if (cnt < 0)
        cnt := 0

    loop cnt {
        i := A_Index
        sec := "parent_hist_" i
        l := IniReadSafe(CFG_FILE, sec, "L", "")
        if (Trim(l) = "")
            continue
        t := IniReadSafe(CFG_FILE, sec, "T", "")
        r := IniReadSafe(CFG_FILE, sec, "R", "")
        b := IniReadSafe(CFG_FILE, sec, "B", "")
        if (Trim(r) = "" || Trim(b) = "")
            continue

        rec := Map()
        rec["L"] := ToIntSafe(l, 0)
        rec["T"] := ToIntSafe(t, 0)
        rec["R"] := ToIntSafe(r, 0)
        rec["B"] := ToIntSafe(b, 0)
        rec["time"] := IniReadSafe(CFG_FILE, sec, "time", "")
        tmp.Push(rec)
    }

    if (tmp.Length <= 1) {
        PARENT_HIST := tmp
        return
    }

    ; Heuristic: if timestamps exist and appear oldest->newest in INI, reverse.
    k1 := TimeKeySafe(tmp[1].Has("time") ? tmp[1]["time"] : "")
    kN := TimeKeySafe(tmp[tmp.Length].Has("time") ? tmp[tmp.Length]["time"] : "")
    if (k1 && kN && k1 < kN)
        ReverseArray(tmp)

    ; If all have valid timestamps, sort by time desc (newest first) for maximum robustness.
    allOk := true
    for rec in tmp {
        k := TimeKeySafe(rec.Has("time") ? rec["time"] : "")
        if (!k) {
            allOk := false
            break
        }
        rec["__k"] := k
    }

    if (allOk) {
        AL_ArraySort(tmp, (a, b) => (b["__k"] - a["__k"]))
        for rec in tmp
            rec.Delete("__k")
    }

    PARENT_HIST := tmp
}


SaveParentHistoryToIni() {
    global PARENT_HIST, CFG_FILE
    global iniFaulted
    iniFaultBefore := iniFaulted

    ; Keep a max marker so we can clear stale sections when history shrinks.
    prev := ToIntSafe(IniReadSafe(CFG_FILE, "parent_history", "max", "0"), 0)
    if (prev < PARENT_HIST.Length)
        prev := PARENT_HIST.Length

    IniWriteSafe(PARENT_HIST.Length, CFG_FILE, "parent_history", "count")
    IniWriteSafe(prev,              CFG_FILE, "parent_history", "max")

    loop prev {
        i := A_Index
        sec := "parent_hist_" i
        if (i <= PARENT_HIST.Length) {
            rec := PARENT_HIST[i]
            IniWriteSafe(rec["L"], CFG_FILE, sec, "L")
            IniWriteSafe(rec["T"], CFG_FILE, sec, "T")
            IniWriteSafe(rec["R"], CFG_FILE, sec, "R")
            IniWriteSafe(rec["B"], CFG_FILE, sec, "B")
            IniWriteSafe(rec.Has("time") ? rec["time"] : "", CFG_FILE, sec, "time")
        } else {
            IniWriteSafe("", CFG_FILE, sec, "L")
            IniWriteSafe("", CFG_FILE, sec, "T")
            IniWriteSafe("", CFG_FILE, sec, "R")
            IniWriteSafe("", CFG_FILE, sec, "B")
            IniWriteSafe("", CFG_FILE, sec, "time")
        }
    }
    Log("F3 INI write history done count=" PARENT_HIST.Length " iniFaultBefore=" iniFaultBefore " iniFaultAfter=" iniFaulted, "DEBUG", "F3")

}


UpdateParentHistCountUI() {
    global stParentHistCount, PARENT_HIST
    cnt := PARENT_HIST.Length
    try {
        stParentHistCount.Text := "Items: " cnt
    } catch {
    }
}


ParentHistLine(idx, rec) {
    w := rec["R"] - rec["L"]
    h := rec["B"] - rec["T"]
    tm := rec.Has("time") ? rec["time"] : ""
    return "#" idx "  (" rec["L"] "," rec["T"] ")-(" rec["R"] "," rec["B"] ")  [" w "x" h "]  " tm
}


RefreshParentHistCombo() {
    global cbParentHist, PARENT_HIST
    UpdateParentHistCountUI()

    ; IMPORTANT: ComboBox.Delete() does NOT reliably clear all items.
    ; Use a real reset so history always refreshes after F3.
    ClearComboItems(cbParentHist)

    if (PARENT_HIST.Length = 0) {
        try {
            cbParentHist.Text := ""
        } catch {
        }
        return
    }
    items := []
    for idx, rec in PARENT_HIST {
        items.Push(ParentHistLine(idx, rec))
    }
    cbParentHist.Add(items)
    try {
        cbParentHist.Choose(1)
    } catch {
    }


    ; Ensure displayed text reflects the newest entry immediately (programmatic Choose may not sync Text instantly).
    try {
        cbParentHist.Text := items[1]
    } catch {
    }
}



ParentHistOnChange(*) {
    global busy, f3Atomic, parentHistHardLock
    global cbParentHist, PARENT_HIST
    global parentHistSuppressStatusOnce
    global PERSIST_PARENT_ON_HISTORY_SELECT

    if (f3Atomic || busy || parentHistHardLock)
        return

    idx := 0
    try {
        idx := cbParentHist.Value
    } catch {
        idx := 0
    }

    ; ComboBox can still report Value=0 in some edge cases.
    ; Fallback: parse "#N" from the displayed text.
    if (idx < 1 || idx > PARENT_HIST.Length) {
        txt := ""
        try {
            txt := cbParentHist.Text
        } catch {
            return
        }
        if RegExMatch(txt, "i)^\s*#\s*(\d+)", &m) {
            idx := ToIntSafe(m[1], 0)
        }
    }

    if (idx < 1 || idx > PARENT_HIST.Length)
        return

    rec := PARENT_HIST[idx]
    L := rec["L"]
    T := rec["T"]
    R := rec["R"]
    B := rec["B"]
    ApplyParentRect(L, T, R, B, PERSIST_PARENT_ON_HISTORY_SELECT)
    ShowRectOverlay(L, T, R, B, 1300)
    if (parentHistSuppressStatusOnce) {
        parentHistSuppressStatusOnce := false
    } else {
        SetStatus("Loaded parent region from history.")
    }

}



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

AL_FindDiamondOutlineBright(scanReg, winRect, &outX, &outY, pad := 0, brightThr := 210) {
    ; Fallback detector for DIAMOND as a thin outline (not a solid blob)
    ; - Counts "bright" pixels (R,G,B >= brightThr)
    ; - Requires low bright ratio (mostly dark background)
    ; - Requires 4 midpoints (top/bottom/left/right) to be bright -> diamond signature
    outX := ""
    outY := ""

    if (!IsObject(scanReg) || !IsObject(winRect))
        return false

    reg := scanReg
    if (pad > 0) {
        try {
            reg := InflateRegion(reg, pad)
        } catch {
        }
    }
    reg := ClipRegionToWin(reg, winRect)

    try {
        ; Diamond is a thin outline -> avoid over-downsampling
        grid := AL_Capture_ReadPixelGrid(reg, 2)
    } catch as e {
        try {
            LogWarn("AL diamond capture fail err=" e.Message, "ALDIA")
        } catch {
        }
        return false
    }

    if (!IsObject(grid) || !grid.Has("rgb"))
        return false

    wCells := grid["wCells"]
    hCells := grid["hCells"]
    stride := grid["stride"]
    rgb := grid["rgb"]

    total := wCells * hCells
    if (total <= 0)
        return false

    brightCount := 0
    minX := 999999
    minY := 999999
    maxX := -1
    maxY := -1

    Loop hCells {
        y := A_Index - 1
        Loop wCells {
            x := A_Index - 1
            idx := y*wCells + x + 1
            col := 0
            try {
                col := rgb[idx]
            } catch {
                col := 0
            }
            isBright := AL__IsBrightRGB(col, brightThr)
            if (isBright)
                brightCount += 1
            if (isBright && x < minX)
                minX := x
            if (isBright && x > maxX)
                maxX := x
            if (isBright && y < minY)
                minY := y
            if (isBright && y > maxY)
                maxY := y
        }
    }

    ratio := brightCount / total

    ; bbox size (cells -> px) for logging/guard
    bboxWc := (maxX >= 0) ? (maxX - minX + 1) : 0
    bboxHc := (maxY >= 0) ? (maxY - minY + 1) : 0
    bboxWp := bboxWc * stride
    bboxHp := bboxHc * stride

    try {
        Log("AL diamond bright=" brightCount " ratio=" Round(ratio, 3) " width=" bboxWp " height=" bboxHp
            " reg=(" reg["L"] "," reg["T"] "," reg["R"] "," reg["B"] ")", "DEBUG", "ALDIA")
    } catch {
    }

    ; Rule: outline should have enough bright pixels, but still mostly dark
    if (brightCount <= 40)
        return false
    if (ratio >= 0.40)
        return false

    ; mild geometry guard: avoid ultra-thin or gigantic blobs
    if (bboxWc < 4 || bboxHc < 4)
        return false

    ar := bboxWp / Max(1, bboxHp)
    if (ar < 0.35 || ar > 2.85)
        return false

    xMid := (minX + maxX) // 2
    yMid := (minY + maxY) // 2

    okTop := AL__HasBrightNear(rgb, wCells, hCells, xMid, minY, brightThr, 1)
    okBot := AL__HasBrightNear(rgb, wCells, hCells, xMid, maxY, brightThr, 1)
    okLeft := AL__HasBrightNear(rgb, wCells, hCells, minX, yMid, brightThr, 1)
    okRight := AL__HasBrightNear(rgb, wCells, hCells, maxX, yMid, brightThr, 1)

    try {
        Log("AL diamond mids top=" (okTop?1:0) " bot=" (okBot?1:0) " left=" (okLeft?1:0) " right=" (okRight?1:0)
            " bboxCells=(" minX "," minY ")-(" maxX "," maxY ")", "DEBUG", "ALDIA")
    } catch {
    }

    if !(okTop && okBot && okLeft && okRight)
        return false

    ; Convert cell-midpoint to screen coords (sample center)
    outX := reg["L"] + Min((reg["R"] - reg["L"]) - 1, xMid*stride + Floor(stride/2))
    outY := reg["T"] + Min((reg["B"] - reg["T"]) - 1, yMid*stride + Floor(stride/2))
    return true
}


; =========================================================
; Region picker (drag with left mouse)
; =========================================================
PickAndSaveRegion(sectionName, title, &ok) {
    global CFG_FILE
    global runnerL, runnerT, runnerR, runnerB
    global scaleRunL, scaleRunT, scaleRunR, scaleRunB

    ok := false
    SetStatus(title "  (Hold Left Mouse, drag, release. ESC=cancel)")

    pick0 := PickRegionDrag()
    if !IsObject(pick0) {
        SetStatus(title " (cancel: nonmap)")
        return
    }

    if (Type(pick0) != "Map") {
        SetStatus(title " (cancel: nonmap)")
        return
    }

    if (!pick0.Has("ok")) {
        SetStatus(title " (cancel: missing-ok)")
        return
    }

    if (!pick0["ok"]) {
        reason := pick0.Has("reason") ? pick0["reason"] : "unknown"
        SetStatus(title " (cancel: " reason ")")
        return
    }

    if (!pick0.Has("L") || !pick0.Has("T") || !pick0.Has("R") || !pick0.Has("B")) {
        SetStatus(title " (cancel: bad-data)")
        return
    }

    L := pick0["L"]
    T := pick0["T"]
    R := pick0["R"]
    B := pick0["B"]
    if (R <= L || B <= T)
        return

    IniWriteSafe(L, CFG_FILE, sectionName, "L")
    IniWriteSafe(T, CFG_FILE, sectionName, "T")
    IniWriteSafe(R, CFG_FILE, sectionName, "R")
    IniWriteSafe(B, CFG_FILE, sectionName, "B")

    if (sectionName = "runner") {
        runnerL := L
        runnerT := T
        runnerR := R
        runnerB := B
    } else {
        scaleRunL := L
        scaleRunT := T
        scaleRunR := R
        scaleRunB := B
    }

    ok := true
}


IsLDown() {
    return GetKeyState("LButton", "P") || GetKeyState("LButton")
}


; Get physical screen cursor position (robust under DPI virtualization).
; Fallbacks to MouseGetPos if API is unavailable.
GetCursorScreen(&x, &y) {
    pt := Buffer(8, 0)
    try {
        if SC_DllCall("user32.dll\GetPhysicalCursorPos", "ptr", pt, "int") {
            x := NumGet(pt, 0, "int")
            y := NumGet(pt, 4, "int")
            return true
        }
    } catch {
    }
    try {
        if SC_DllCall("user32.dll\GetCursorPos", "ptr", pt, "int") {
            x := NumGet(pt, 0, "int")
            y := NumGet(pt, 4, "int")
            return true
        }
    } catch {
    }
    try {
        MouseGetPos(&x, &y)
    } catch {
        x := 0
        y := 0
    }
    return true
}
PickRegionDrag(requireDrag := false) {
    
    global __UI_IS_TESTING
    __ENTRY_Log("PickRegionDrag", "IsTesting=" __UI_IS_TESTING " requireDrag=" (requireDrag ? 1 : 0))
    if (__UI_IS_TESTING) {
        Log("PICK IGNORE: UI test lock active", "DEBUG", "PICK")
        return Map("ok", false, "reason", "testlock")
    }
hwndRoot := 0
    hwndRaw := 0

    global DBG_PICK_WAIT_TOOLTIP
    success := false
    try {
        HideBorder()
        Log("BEGIN PICK", "DEBUG", "PICK")
        res := ""

        ; PRO FIX: Use KeyWait to avoid missing state transitions.
        ; Normalize state: if LButton is already held, wait for release briefly.
        if GetKeyState("LButton", "P") {
            if !KeyWait("LButton", "T1.5") {
                Log("PICK FAIL reason=timeout", "DEBUG", "PICK")
                return Map("ok", false, "reason", "timeout")
            }
            Sleep 30
        }

        if (DBG_PICK_WAIT_TOOLTIP)
            ToolTip("drag with LButton... (ESC=cancel)")

        ; Wait for a NEW press
        Loop {
            if GetKeyState("Escape", "P") {
                Log("PICK FAIL reason=escape", "DEBUG", "PICK")
                return Map("ok", false, "reason", "escape")
            }
            if KeyWait("LButton", "D T0.25") {
                Sleep 15
                break
            }
        }

        if (DBG_PICK_WAIT_TOOLTIP)
            ToolTip()

        Sleep 30
        GetCursorScreen(&x1, &y1)
        ; Capture HWND under initial point (root window) for HWND-mode capture
        try {
            MouseGetPos(, , &hwndRaw)
            if (hwndRaw) {
                hwndRoot := DllCall("user32.dll\GetAncestor", "ptr", hwndRaw, "uint", 2, "ptr")
                if (!hwndRoot)
                    hwndRoot := hwndRaw
            }
        } catch {
            hwndRoot := 0
        }

        if (!IsNum(x1) || !IsNum(y1)) {
            Log("PICK FAIL reason=invalid", "DEBUG", "PICK")
            return Map("ok", false, "reason", "invalid")
        }

        ; Realtime border while dragging (smooth + no focus + click-through)
        x2 := x1
        y2 := y1
        UpdateBorderRect(x1, y1, x2, y2)
        dragged := false
        drawNext := 0
        while GetKeyState("LButton", "P") {
            if GetKeyState("Escape", "P") {
                Log("PICK FAIL reason=escape", "DEBUG", "PICK")
                return Map("ok", false, "reason", "escape")
            }
            GetCursorScreen(&x2, &y2)
            if (!dragged && (Abs(x2 - x1) > 3 || Abs(y2 - y1) > 3))
                dragged := true
            if (A_TickCount >= drawNext) {
                UpdateBorderRect(x1, y1, x2, y2)
                drawNext := A_TickCount + 33
            }
            Sleep 1
        }
        ; final draw
        UpdateBorderRect(x1, y1, x2, y2)
        GetCursorScreen(&x2, &y2)

        if (requireDrag && !dragged) {
            Log("PICK FAIL reason=nodrag", "DEBUG", "PICK")
            return Map("ok", false, "reason", "nodrag")
        }

        ; Never return a Map without L/T/R/B (click-only still yields a region)
        minSz := 5
        if (!IsNum(x2) || !IsNum(y2)) {
            L := x1
            T := y1
            R := x1 + minSz
            B := y1 + minSz
            Log("PICK OK L=" L " T=" T " R=" R " B=" B, "DEBUG", "PICK")
            success := true
            return Map("ok", true, "L", L, "T", T, "R", R, "B", B, "hwnd", hwndRoot)
        }

        L := Min(x1, x2)
        T := Min(y1, y2)
        R := Max(x1, x2)
        B := Max(y1, y2)

        if (Abs(R - L) < minSz)
            R := L + minSz
        if (Abs(B - T) < minSz)
            B := T + minSz

        ; Clamp to screen bounds (CoordMode Screen) WITHOUT collapsing min size.
        sw := A_ScreenWidth
        sh := A_ScreenHeight

        if (R > sw - 1) {
            dx := R - (sw - 1)
            L -= dx
            R := sw - 1
        }

        if (L < 0) {
            dx := -L
            L := 0
            R += dx
        }

        if (B > sh - 1) {
            dy := B - (sh - 1)
            T -= dy
            B := sh - 1
        }

        if (T < 0) {
            dy := -T
            T := 0
            B += dy
        }

        if (R - L < minSz) {
            if (L + minSz <= sw - 1) {
                R := L + minSz
            } else {
                R := sw - 1
                L := Max(0, R - minSz)
            }
        }

        if (B - T < minSz) {
            if (T + minSz <= sh - 1) {
                B := T + minSz
            } else {
                B := sh - 1
                T := Max(0, B - minSz)
            }
        }

        res := Map("ok", true, "L", L, "T", T, "R", R, "B", B, "hwnd", hwndRoot)

        if (Type(res) = "Map") {
            Log("PICK OK L=" L " T=" T " R=" R " B=" B, "DEBUG", "PICK")
            success := true
            return res
        }

        ; ===== ABSOLUTE FALLTHROUGH GUARD =====
        Log("PICK FAIL reason=fallthrough", "DEBUG", "PICK")
        return Map("ok", false, "reason", "fallthrough")
    } catch as e {
        try {
            LogWarn("PickRegionDrag exception err=" e.Message, "PICK")
        } catch {
        }
        return Map("ok", false, "reason", "exception")
    } finally {
        ; Always clear tooltip and hide border overlay.
        ; NOTE: DXGI captures desktop composition, so leaving the overlay visible
        ; can contaminate subsequent captures (black/overlay-only images).
        if (DBG_PICK_WAIT_TOOLTIP) {
            try {
                ToolTip()
            } catch {
            }
        }
        try {
            HideBorder()
        } catch {
        }
        try {
            Log("END PICK ok=" (success ? 1 : 0), "DEBUG", "PICK")
        } catch {
        }
    }
}


ShowBorderInit() {
    global borderG
    if (borderG.Has("top"))
        return
    borderG["top"] := MakeLineGui()
    borderG["left"] := MakeLineGui()
    borderG["right"] := MakeLineGui()
    borderG["bottom"] := MakeLineGui()
}


HideBorder() {
    global borderG, F3_GUI_SHOW_BORDERS, __BORDER_LAST_TICK
    if (F3_GUI_SHOW_BORDERS) {
        try {
            Log("HideBorder skipped: F3_GUI_SHOW_BORDERS=1", "DEBUG", "BORDER")
        } catch {
        }
        return
    }
    if (IsSet(__BORDER_LAST_TICK) && (A_TickCount - __BORDER_LAST_TICK < 150)) {
        try {
            Log("HideBorder skipped: recent draw tickDelta=" (A_TickCount - __BORDER_LAST_TICK), "DEBUG", "BORDER")
        } catch {
        }
        return
    }
    for _, gg in borderG {
        try {
            gg.Hide()
        } catch {
        }
    }
}

Border_ClearLinesForce(reason := "") {
    global borderG, BORDER_SETS, gBorderShowAll
    ; Hide single-set borders (parent/preview)
    try {
        ShowBorderInit()
    } catch {
    }
    if (IsObject(borderG)) {
        for _, gg in borderG {
            try {
                gg.Hide()
            } catch {
            }
        }
    }
    ; Hide all multi-ROI border sets (ALL ROI)
    if (IsObject(BORDER_SETS)) {
        for _, set in BORDER_SETS {
            if (!IsObject(set))
                continue
            for _, gg in set {
                try {
                    gg.Hide()
                } catch {
                }
            }
        }
    }
    ; Hide ROI index labels
    try {
        Border_HideAllLabels()
    } catch {
    }
    ; Keep OrderInput while ALL-ROI mode is ON; destroy only when leaving mode
    ; NOTE: ClearLinesForce chỉ clear vẽ, KHÔNG destroy OrderInput (chỉ destroy khi Toggle OFF thật sự)
    try {
        if (reason != "")
            Log("BORDER ClearLinesForce reason=" reason, "DEBUG", "BORDER")
        else
            Log("BORDER ClearLinesForce", "DEBUG", "BORDER")
    } catch {
    }
}


; ===============================
; ROI index labels (for ALL ROI Show Borders)
; Each ROI gets its own tiny click-through GUI with transparent background.
Border_EnsureLabel(i) {
    global BORDER_LABELS
    if (!IsObject(BORDER_LABELS))
        BORDER_LABELS := []
    if (i < 1)
        i := 1
    if (i <= BORDER_LABELS.Length && IsObject(BORDER_LABELS[i]))
        return BORDER_LABELS[i]
    while (BORDER_LABELS.Length < i)
        BORDER_LABELS.Push(0)

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
    ; Use transcolor background
    g.BackColor := "FFFF00"
    txt := g.AddText("x0 y0 w28 h18 Center +0x200", i) ; +0x200 = SS_CENTERIMAGE
    try {
        txt.SetFont("s9 Bold", "Segoe UI")
    } catch {
    }
    ; show tiny first, then apply TransColor
    g.Show("NA x0 y0 w1 h1")
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        WinSetTransColor("FFFF00", "ahk_id " g.Hwnd)
    } catch {
    }
    BORDER_LABELS[i] := Map("gui", g, "txt", txt)
    return BORDER_LABELS[i]
}

Border_DrawLabel(i, rectOrL, labelText := "") { 
    ; rectOrL must be SCREEN rect (Map with L/T/R/B or object with L/T/R/B)
    lab := Border_EnsureLabel(i)
    g := lab["gui"], txt := lab["txt"]
    try {
        if (labelText = "")
            labelText := i
        txt.Text := labelText
    } catch {
    }
    x := 0, y := 0
    if (IsObject(rectOrL) && Type(rectOrL) = "Map" && rectOrL.Has("L") && rectOrL.Has("T")) {
        x := rectOrL["L"] + 2
        y := rectOrL["T"] + 2
    } else if (IsObject(rectOrL)) {
        _L := HasProp(rectOrL, "L") ? rectOrL.L : (HasProp(rectOrL, "Left") ? rectOrL.Left : 0)
        _T := HasProp(rectOrL, "T") ? rectOrL.T : (HasProp(rectOrL, "Top") ? rectOrL.Top : 0)
        x := _L + 2
        y := _T + 2
    } else {
        return
    }
    ; draw small fixed-size label
    try {
        g.Hide()
    } catch {
    }
    try {
        g.Show("NA x" x " y" y " w28 h18")
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
}

Border_HideAllLabels() {
    global BORDER_LABELS
    if (!IsObject(BORDER_LABELS))
        return
    for _, it in BORDER_LABELS {
        if (!IsObject(it))
            continue
        try {
            it["gui"].Hide()
        } catch {
        }
    }
}

; ------------------------------
; ROI order input boxes (for Show Border ALL ROI)
; ------------------------------

Border_HideAllOrderInputs() {
    global BORDER_ORDERINPUTS
    if (!IsObject(BORDER_ORDERINPUTS))
        return
    for _, obj in BORDER_ORDERINPUTS {
        if (!IsObject(obj))
            continue
        try {
            obj["gui"].Hide()
        } catch {
        }
    }
}

Border_DestroyAllOrderInputs() {
    global BORDER_ORDERINPUTS
    if (!IsObject(BORDER_ORDERINPUTS))
        return
    for i, obj in BORDER_ORDERINPUTS {
        try {
            if (IsObject(obj) && obj.Has("gui"))
                obj["gui"].Destroy()
        } catch {
        }
    }
    BORDER_ORDERINPUTS := Map()
}




Border_DrawOrderInputsAll() {
    global F3_ROI_LIST
    global BORDER_ORDEROVERRIDE
    if (!IsObject(F3_ROI_LIST))
        return
    for idx, it in F3_ROI_LIST {
        if (!IsObject(it))
            continue
        if (!it.Has("screenRect"))
            continue
        sr := it["screenRect"]

        ; Show current manual order (if any). Blank means "auto".
        v := ""
        try {
            if (it.Has("order") && it["order"] > 0)
                v := it["order"]
        } catch {
        }
        try {
            if (v = "" && IsObject(BORDER_ORDEROVERRIDE) && BORDER_ORDEROVERRIDE.Has(idx))
                v := BORDER_ORDEROVERRIDE[idx]
        } catch {
        }

        try {
            Border_DrawOrderInput(idx, sr, v)
        } catch {
        }
    }
}

Border_EnsureOrderInput(i) {
    global BORDER_ORDERINPUTS
    global gBorderShowAll
    try {
        Log("ENTER idx=" i " showAll=" gBorderShowAll, "DEBUG", "ORDER")
    } catch {
    }
    if (!gBorderShowAll) {
        try {
            Log("GUARD showAll=0 idx=" i, "DEBUG", "ORDER")
        } catch {
        }
        return 0
    }
    if (!IsObject(BORDER_ORDERINPUTS))
        BORDER_ORDERINPUTS := Map()
    if (BORDER_ORDERINPUTS.Has(i) && IsObject(BORDER_ORDERINPUTS[i]) && BORDER_ORDERINPUTS[i].Has("gui") && IsObject(BORDER_ORDERINPUTS[i]["gui"])) {
        try {
            Log("REUSE idx=" i " hwnd=" BORDER_ORDERINPUTS[i]["gui"].Hwnd, "DEBUG", "ORDER")
        } catch {
        }
        return BORDER_ORDERINPUTS[i]
    }
    ; Small topmost edit box (clickable) to type order number
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border -DPIScale")
    try {
        Log("CREATE idx=" i, "DEBUG", "ORDER")
    } catch {
    }
    g.BackColor := "FFFFFF"
    g.MarginX := 2, g.MarginY := 1
    g.SetFont("s9", "Segoe UI")

    edt := g.AddEdit("w36 h20 Center Number Limit3 vord", "")
    ; Prevent initial activation flicker
    try {
        g.Show("Hide")
    } catch {
    }

    ; Remember index in the GUI object
    g.__idx := i
    ; Change event: store value (does not modify ROI list to avoid breaking logic)
    edt.OnEvent("Change", (*) => Border_OnOrderInputChange(i, edt))

    obj := Map("gui", g, "edit", edt)
    BORDER_ORDERINPUTS[i] := obj
    try {
        Log("CREATED idx=" i " hwnd=" g.Hwnd, "DEBUG", "ORDER")
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    return obj
}

Border_OnOrderInputChange(i, edt) {
    global BORDER_ORDEROVERRIDE
    global F3_ROI_LIST

    if (!IsObject(BORDER_ORDEROVERRIDE))
        BORDER_ORDEROVERRIDE := Map()

    v := Trim(edt.Value)
    ; Keep only digits
    v := RegExReplace(v, "[^\d]")

    ord := 0
    if (v != "")
        ord := v + 0

    ; Store override map (by ROI index)
    if (ord <= 0) {
        try {
            if (BORDER_ORDEROVERRIDE.Has(i))
                BORDER_ORDEROVERRIDE.Delete(i)
        } catch {
        }
    } else {
        BORDER_ORDEROVERRIDE[i] := ord
    }

    ; Apply to ROI data so RUN uses it (order>0 => manual)
    try {
        if (IsObject(F3_ROI_LIST) && i >= 1 && i <= F3_ROI_LIST.Length && IsObject(F3_ROI_LIST[i])) {
            F3_ROI_LIST[i]["order"] := ord
        }
    } catch {
    }

    ; Refresh GUI list label (ord=...)
    try {
        RefreshF3RoiCombo(i)
    } catch {
    }

    msg := "ORDERINPUT idx=" i " ord=" (ord <= 0 ? "<auto>" : ord)
    try {
        Log(msg, "DEBUG", "BORDER")
    } catch {
    }
}

Border_DrawOrderInput(i, rect, val := "") {
    try {
        Log("ENTER idx=" i, "DEBUG", "ORDER")
    } catch {
    }
    ; rect is expected to be SCREEN coords (L,T,R,B)
    obj := Border_EnsureOrderInput(i)
    if (!IsObject(obj))
        return

    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(rect, &L, &T, &R, &B)) {
        ; Fallback (older rect objects)
        if (IsObject(rect)) {
            try L := rect.Has("L") ? rect["L"] : rect.L
            catch {
            }
            try T := rect.Has("T") ? rect["T"] : rect.T
            catch {
            }
            try R := rect.Has("R") ? rect["R"] : rect.R
            catch {
            }
            try B := rect.Has("B") ? rect["B"] : rect.B
            catch {
            }
        }
    }

    try {
        Log("RECT idx=" i " L=" L " T=" T " R=" R " B=" B, "DEBUG", "ORDER")
    } catch {
    }

    ; Put the input box INSIDE the border, top-right corner.
    w := 36
    x := (R > 0 ? (R - w - 2) : (L + 2))
    y := T + 2
    if (x < 0)
        x := 0
    if (y < 0)
        y := 0

    ; Set value (only if provided; blank means "auto" and should not wipe user's input)
    if (val != "")
        try {
            obj["edit"].Value := val
        } catch {
        }
    try {
        Log("SHOW idx=" i " x=" x " y=" y, "DEBUG", "ORDER")
    } catch {
    }
    try {
        obj["gui"].Show("x" x " y" y " NA")
    } catch {
    }
    try {
        Border_SetTopMost(obj["gui"].Hwnd)
    } catch {
    }
}



; ===============================
; Border sets for ALL ROI (multi borders)
Border_EnsureSet(i) {
    global BORDER_SETS
    if (!IsObject(BORDER_SETS))
        BORDER_SETS := []
    if (i < 1)
        i := 1
    if (i <= BORDER_SETS.Length && IsObject(BORDER_SETS[i]))
        return BORDER_SETS[i]
    ; grow array
    while (BORDER_SETS.Length < i)
        BORDER_SETS.Push(0)
    set := Map()
    set["top"] := MakeLineGui()
    set["left"] := MakeLineGui()
    set["right"] := MakeLineGui()
    set["bottom"] := MakeLineGui()
    BORDER_SETS[i] := set
    return set
}

Border_DrawUsingSet(set, rectOrL, T := unset, R := unset, B := unset, hwnd := 0) {
    static _lastDrawTick := 0
    if (A_TickCount - _lastDrawTick < 60) {
        Border_BringOrderInputsToTop()
        return
    }
    _lastDrawTick := A_TickCount

    global borderG
    old := borderG
    borderG := set
    try {
        ; reuse existing UpdateBorderRect logic (SCREEN COORD + logs + w/h<2 skip)
        if (IsObject(rectOrL)) {
            ; rectOrL may be Map/Object; UpdateBorderRect requires L,T,R,B (no extra params)
            if (Type(rectOrL) = "Map") {
                if (rectOrL.Has("L") && rectOrL.Has("T") && rectOrL.Has("R") && rectOrL.Has("B")) {
                    UpdateBorderRect(rectOrL["L"], rectOrL["T"], rectOrL["R"], rectOrL["B"])
                } else if (rectOrL.Has("X") && rectOrL.Has("Y") && rectOrL.Has("W") && rectOrL.Has("H")) {
                    UpdateBorderRect(rectOrL["X"], rectOrL["Y"], rectOrL["X"] + rectOrL["W"], rectOrL["Y"] + rectOrL["H"])
                } else {
                    UpdateBorderRect(0, 0, 0, 0)
                }
            } else {
                ; Object rect: support L/T/R/B or Left/Top/Right/Bottom without try/catch
                _L := HasProp(rectOrL, "L") ? rectOrL.L : (HasProp(rectOrL, "Left") ? rectOrL.Left : 0)
                _T := HasProp(rectOrL, "T") ? rectOrL.T : (HasProp(rectOrL, "Top") ? rectOrL.Top : 0)
                _R := HasProp(rectOrL, "R") ? rectOrL.R : (HasProp(rectOrL, "Right") ? rectOrL.Right : 0)
                _B := HasProp(rectOrL, "B") ? rectOrL.B : (HasProp(rectOrL, "Bottom") ? rectOrL.Bottom : 0)
                UpdateBorderRect(_L+0, _T+0, _R+0, _B+0)
            }
        } else if (IsSet(T) && IsSet(R) && IsSet(B)) {
            UpdateBorderRect(rectOrL, T, R, B)
        } else {
            UpdateBorderRect(rectOrL, 0, rectOrL, 0)
        }
    } catch {
    }
    Border_BringOrderInputsToTop()

    borderG := old
}

F3GuiDrawAllRoiBorders() {
    global F3_ROI_LIST, F3_ROI_PARENT_RECT
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        try {
            Log("SHOW BORDERS: no ROIs", "DEBUG", "BORDER")
        } catch {
        }
        return
    }
    ; draw ALL roi borders using pooled sets (avoid overlay GUI => no black bar)
    for i, it in F3_ROI_LIST {
        sr := 0
        ; prefer screenRect
        if (IsObject(it) && it.Has("screenRect")) {
            try {
                sr := it["screenRect"]
            } catch {
            }
        }
        ; fallback: rectRel -> screen via parent
        if (!IsObject(sr) && IsObject(it) && it.Has("rectRel") && IsObject(F3_ROI_PARENT_RECT)) {
            rr := 0
            try {
                rr := it["rectRel"]
            } catch {
            }
            if (IsObject(rr)) {
                try {
                    sr := AL_RelToScreen(F3_ROI_PARENT_RECT, rr)
                } catch {
                }
            }
        }
        if (!IsObject(sr))
            continue
        set := Border_EnsureSet(i)
        ; sr is already screen coords; keep hwnd=0 so dx/dy = 0
        Border_DrawUsingSet(set, sr, unset, unset, unset, 0)
        ; label order/index for this ROI
        labelVal := i
        try {
            if (IsObject(it) && it.Has("order") && (it["order"] > 0))
                labelVal := it["order"]
        } catch {
        }
        try {
            Border_DrawOrderInput(i, sr, labelVal)
        } catch {
        }
    }
}






; =========================================================
; CORE: Diamond -> Scale
; =========================================================
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

AL_L4_Extract(parentCtx, filtered, store := 0, opts := 0) {
    ; Input: ParentContext + Filtered[]
    ; Output: ElementModel (template + anchors)

    if (!IsObject(opts))
        opts := AL_DefaultOpts()

    if (!IsObject(filtered) || filtered.Length = 0)
        return 0

    best := filtered[1]
    rel := best.rectRel
    parent := parentCtx.rect
    screenRect := AL_RelToScreen(parent, rel)

    id := "elem_" FormatTime(A_Now, "yyyyMMdd_HHmmss")

    ; 4.1 crop template (no refactor): HWND = capture FULL parent -> parent.bmp -> crop rectRel -> tpl_elem.bmp
    tplPath := ""

    pad := opts["templatePad"]

    ; determine HWND FIRST
    capHwnd := 0
    try {
        if (IsObject(parentCtx) && IsObject(parentCtx.meta) && parentCtx.meta.Has("hwnd")) {
            capHwnd := parentCtx.meta["hwnd"]
        }
    } catch {
        capHwnd := 0
    }


; ===== FAST MODE GATE: bypass CAP DECIDE + parent capture =====
global CAP_FAST_MODE, AL_FAST_MODE, PIPE_MODE
if (capHwnd && (CAP_FAST_MODE || AL_FAST_MODE || PIPE_MODE = "F4")) {
    CAP_Log("FAST MODE | bypass CAP DECIDE + parent capture → use SCREEN template capture (ROI-only)")
    capHwnd := 0
}

    if (capHwnd) {
        parentDxgiPath := A_ScriptDir "\parent_dxgi.bmp"  ; DXGI map (RECT only)
        parentBmpPath := A_ScriptDir "\parent_gdi.bmp"    ; GDI/PrintWindow image (looks like screen)
        ; ⚠️ DEBUG: KHÔNG ghi đè template. Mỗi lần F3/F4 (khi save) tạo 1 file tpl_* mới.
        tplPath := DBG__MakeUniqueBmpPath("tpl_elem")

        ; 1) CAPTURE FULL parent -> parent.bmp (single source)
        okDxgi := false
        okGdi := false

        ; IDOL LAYER: Browser/App UI -> prefer PrintWindow; Desktop/Game -> prefer DXGI.
        targetType := "APP"
        capMethod2 := "DXGI"
        pwHwnd := capHwnd

        ; ===== IDOL CAP DECISION STATE (no refactor) =====
        renderLayer := "UI"
        capMethod := ""
        capReason := ""
        blackFrameReason := ""
        captureSource := ""
        capSrcMode := "HWND"
        guiVisible := 0
        printFlags := 0x00000002
        dxgiBmp := ""
        alphaChannel := ""
        outputBitDepth := 0
        try {
            global g
            if (IsObject(g) && g.Hwnd)
                guiVisible := CAP_IsWindowVisible(g.Hwnd) ? 1 : 0
        } catch {
            guiVisible := 0
        }
        useDXGI := (capMethod2 = "DXGI") ? 1 : 0
        global CAP_HIDE_GUI, CAP_FAST_MODE

        if (guiVisible && !CAP_HIDE_GUI && !CAP_FAST_MODE) {
            CAP_Log("BLACK FRAME | GUI overlay present", "WARN")
            CAP_Log("CAP DECIDE | GUI visible → forbid DXGI (GLOBAL)", "WARN")
            useDXGI := 0
            useDXGI_SCREEN := 0 ; nếu có biến riêng cho SCREEN
        }

        if (!useDXGI && capMethod2 = "DXGI")
            capMethod2 := "PRINTWINDOW"

        try {
            targetType := CAP_DetectTargetType(capHwnd)
        } catch {
            targetType := "APP"
        }

        if (targetType = "BROWSER") {
            capMethod2 := "PRINTWINDOW"
        }

        ; ----- IDOL DECIDE (mandatory logs) -----
        if (targetType = "BROWSER")
            renderLayer := "GPU"
        else if (targetType = "GAME")
            renderLayer := "GPU"
        else
            renderLayer := "UI"

        CAP_Log("CAP DECIDE | targetType=" targetType)
        CAP_Log("CAP DECIDE | renderLayer=" renderLayer)

        capMethod := capMethod2
        if (capMethod = "PRINTWINDOW") {
            capReason := "Browser → avoid DXGI"
        } else if (targetType = "GAME") {
            capReason := "Game detected → prefer DXGI"
        } else {
            capReason := "Desktop/App → prefer DXGI"
        }

        CAP_Log("CAP MODE | " capSrcMode)
        CAP_Log("CAP METHOD | use=" capMethod)
        CAP_Log("CAP REASON | " capReason)


        try {
            pwHwnd := CAP_GetBestPrintWindowHwnd(capHwnd)
        } catch {
            pwHwnd := capHwnd
        }

        if (capMethod2 = "PRINTWINDOW") {
            ; Browser: PrintWindow on best render HWND; avoid DXGI black frames.
            try {
                okGdi := AL_Capture_RectToBMP(
                    parent,
                    parentBmpPath,
                    Map(
                        "caller","AL_L4_ParentCapture_PW",
                        "srcMode","HWND",
                        "hwnd",pwHwnd,
                        "method","PrintWindow"
                    )
                )
            } catch {
                okGdi := false
            }

            if (!okGdi) {
                ; Last resort: SCREEN capture (may include occlusion)

                capSrcMode := "SCREEN"
                CAP_Log("CAP MODE | SCREEN")
                try {
                    okGdi := AL_Capture_RectToBMP(
                        parent,
                        parentBmpPath,
                        Map(
                            "caller","AL_L4_ParentCapture_SCREEN",
                            "srcMode","SCREEN",
                            "hwnd",0,
                            "useDXGI",useDXGI
                        )
                    )
                } catch {
                    okGdi := false
                }
            }
        } else {
        ; 1) DXGI capture FULL parent -> parent_dxgi.bmp (flatten alpha inside)
            okDxgi := false
            try {
                okDxgi := AL_Capture_RectToBMP(
                    parent,
                    parentDxgiPath,
                    Map(
                        "caller","AL_L4_ParentCapture_DXGI",
                        "srcMode","HWND",
                        "hwnd",capHwnd
                    )
                )
            } catch {
                okDxgi := false
            }

            ; 2) GDI/PrintWindow capture parent rect -> parent_gdi.bmp (normal-looking)
            okGdi := false

            ; FLOWLOCK (no refactor): when DXGI ok, STOP here — do not call GDI or SCREEN.
            ; Use DXGI output as the parent image for template crop.
            if (okDxgi) {
                okGdi := true
                parentBmpPath := parentDxgiPath

                ; ----- DXGI PROBE (black/alpha reasons) -----
                dxgiBmp := parentDxgiPath
                bpp0 := 0
                if (SC_BmpGetBitCount(parentDxgiPath, &bpp0)) {
                    if (bpp0 != 24)
                        CAP_Log("WARN | 32bit alpha BMP detected", "WARN")
                }
                a0 := 0, rgb0 := 0
                if (SC_BmpProbeAlphaAndBlack(parentDxgiPath, &a0, &rgb0)) {
                    if (targetType = "BROWSER")
                        CAP_Log("BLACK FRAME | DXGI used on Browser", "WARN")
                    if (rgb0)
                        CAP_Log("BLACK FRAME | DXGI cannot see UI layer", "ERROR")
                    if (a0) {
                        alphaChannel := "0"
                        CAP_Log("BLACK FRAME | DXGI alpha=0", "WARN")
                    } else {
                        alphaChannel := "OK"
                    }
                }
                ; FORCE opaque 24-bit so the saved parent image is "normal-looking" (no alpha=0 black preview)
                try {
                    SC_BmpFlattenTo24(parentDxgiPath, true)
                } catch {
                }
            } else {
                ; DXGI failed → fallback chain: PrintWindow (HWND) → SCREEN (DXGI)
                try {
                    okGdi := AL_Capture_RectToBMP(
                        parent,
                        parentBmpPath,
                        Map(
                            "caller","AL_L4_ParentCapture_GDI",
                            "srcMode","HWND",
                            "hwnd",capHwnd,
                            "method","PrintWindow"
                        )
                    )
                } catch {
                    okGdi := false
                }

                ; ----- IDOL CAP OUTPUT (mandatory logs) -----
                if (okGdi) {
                    try {
                        captureSource := RegExReplace(parentBmpPath, "^.*\\", "")
                    } catch {
                        captureSource := parentBmpPath
                    }
                    CAP_Log("CAP SOURCE | " captureSource)

                    bpp2 := 0
                    if (SC_BmpGetBitCount(parentBmpPath, &bpp2)) {
                        outputBitDepth := bpp2
                        if (bpp2 != 24)
                            CAP_Log("WARN | 32bit alpha BMP detected", "WARN")
                    }

                    CAP_Log("CAP END | success")
                } else {
                    CAP_Log("CAP END | fail", "ERROR")
                }

                if (!okGdi) {
                    try {
                        okGdi := AL_Capture_RectToBMP(
                            parent,
                            parentBmpPath,
                            Map(
                                "caller","AL_L4_ParentCapture_SCREEN",
                                "srcMode","SCREEN",
                                "hwnd",0
                            )
                        )
                    } catch {
                        okGdi := false
                    }
                }
            }

        }

    ; 3) crop parent.bmp by rectRel (+pad) -> tpl_elem.bmp (template final)
    ; IDOL STANDARD: crop from the SAME captured file (no extra capture; no baseBmp; no hGraphics).
    ; We crop at file-level and output an opaque 24-bit BMP so the template is always "normal-looking".
        okTpl := false
        ; Ensure parent image is opaque 24-bit before cropping template (prevents black preview / alpha issues)
        if (okGdi && FileExist(parentBmpPath)) {
            try {
                SC_BmpFlattenTo24(parentBmpPath, true)
            } catch {
            }
        }

        if (okGdi && FileExist(parentBmpPath)) {
            try {
                bw := 0, bh := 0
                if (SC_BmpGetSize(parentBmpPath, &bw, &bh)) {
                    x := Max(0, rel.L - pad)
                    y := Max(0, rel.T - pad)
                    cw := Min(bw - x, ((rel.R - rel.L) + 1) + pad*2)  ; +1 để tránh cắt thiếu 1px (inclusive R/B)
                    ch := Min(bh - y, ((rel.B - rel.T) + 1) + pad*2)  ; +1 để tránh cắt thiếu 1px (inclusive R/B)

                    if (cw > 0 && ch > 0)
                        okTpl := SC_BmpCropFile(parentBmpPath, tplPath, x, y, cw, ch, true)
                }
            } catch {
                okTpl := false
            }
        }

        if (!okTpl)
            tplPath := ""

; ===============================
; MULTI-ICON EXPORT (HWND parent): crop extra candidates from SAME parentBmpPath
; ===============================
; - Không capture lại parent nhiều lần (nhanh)
; - Mỗi ROI → 1 file tpl_elem_2, tpl_elem_3...
global F3_MULTI_ICON, AL_MULTI_SAVE_EACH
if (F3_MULTI_ICON && AL_MULTI_SAVE_EACH && IsObject(filtered) && filtered.Length > 1) {
    try {
        if (okGdi && FileExist(parentBmpPath)) {
            bw := 0, bh := 0
            if (SC_BmpGetSize(parentBmpPath, &bw, &bh)) {
                dupIouThr := (IsObject(opts) && opts.Has("multiDupIou")) ? opts["multiDupIou"] : 0.92
                savedRects := [rel]  ; winner rectRel đã lưu ở tpl_elem.bmp

                ; ---- MULTI DUP GUARD ----
                ; Nếu L2/L3 trả ra nhiều rect chồng gần như y hệt cho CÙNG 1 icon,
                ; việc export nhiều tpl sẽ nhìn như "cắt chồng crop" (roi#1 -> roi#2).
                ; Chặn bằng IoU để mỗi icon chỉ ra 1 tpl (KHÔNG đụng thuật toán detect).
                Loop filtered.Length {
                    if (A_Index = 1)
                        continue
                    rel2 := filtered[A_Index].rectRel

                    ; ---- MULTI CONTAINMENT GUARD ----
                    ; Trường hợp L2/L3 đôi khi giữ lại 1 rect nhỏ nằm "lọt" trong rect winner (artifact/đốm),
                    ; export sẽ nhìn giống như "cắt chồng crop" (roi#1 rồi lại cắt 1 phần của roi#1).
                    ; Giữ nguyên thuật toán detect: chỉ skip khi rect nhỏ gần như nằm hoàn toàn trong winner.
                    containThr := (IsObject(opts) && opts.Has("multiContainThr")) ? opts["multiContainThr"] : 0.95
                    areaFracMax := (IsObject(opts) && opts.Has("multiContainAreaFracMax")) ? opts["multiContainAreaFracMax"] : 0.35
                    interW := Max(0, Min(rel2.R, rel.R) - Max(rel2.L, rel.L))
                    interH := Max(0, Min(rel2.B, rel.B) - Max(rel2.T, rel.T))
                    interA := interW * interH
                    a2 := rel2.W * rel2.H
                    aW := rel.W * rel.H
                    contain := (a2 > 0) ? (interA / a2) : 0
                    if (contain >= containThr && a2 <= (aW * areaFracMax)) {
                        CAP_Log("MULTI | SKIP INSIDE WINNER idx=" A_Index " contain=" Round(contain,3) " area=" a2, "WARN")
                        continue
                    }

                    isDup := false
                    for _, rr in savedRects {
                        ; containment first
                        if (AL_RectInside(rel2, rr, 0.92, 0.45)) {
                            isDup := true
                            break
                        }
                        if (AL_IoU(rel2, rr) >= dupIouThr) {
                            isDup := true
                            break
                        }
                    }
                    if (isDup) {
                        CAP_Log("MULTI | SKIP DUP idx=" A_Index " (IoU>=" dupIouThr ")", "WARN")
                        continue
                    }

                    tpl2 := DBG__MakeUniqueBmpPath("tpl_elem_" A_Index)
                    x2 := Max(0, rel2.L - pad)
                    y2 := Max(0, rel2.T - pad)
                    cw2 := Min(bw - x2, ((rel2.R - rel2.L) + 1) + pad*2)  ; +1 inclusive
                    ch2 := Min(bh - y2, ((rel2.B - rel2.T) + 1) + pad*2)  ; +1 inclusive
                    if (cw2 > 0 && ch2 > 0) {
                        ok2 := SC_BmpCropFile(parentBmpPath, tpl2, x2, y2, cw2, ch2, true)
                        if (ok2) {
                            CAP_Log("MULTI | SAVE tpl idx=" A_Index " -> " tpl2)
                            savedRects.Push(rel2)
                        } else
                            CAP_Log("MULTI | FAIL tpl idx=" A_Index, "WARN")
                    } else {
                        CAP_Log("MULTI | SKIP tpl idx=" A_Index " (bad crop size)", "WARN")
                    }
                }
            }
        }
    } catch {
    }
}
    } else {
        cropRect := AL_ExpandRect(screenRect, pad)

        ; CAPTURE (Screen)
        tplPath := ""
        try {
            ; FAST MODE: vẫn có ảnh để soi ROI, nhưng phải THROTTLE (mỗi N vòng) để giữ tốc độ.
            ; - Khi KHÔNG tới lượt save: giữ tplPath = ảnh lần trước (đã tồn tại), không capture+save nữa.
            global PIPE_MODE, DBG_LAST_TPL_PATH, g_F4_Index
            doSaveTpl := DBG__ShouldSaveTpl(PIPE_MODE)

            ; đảm bảo lần đầu luôn có 1 ảnh tồn tại
            if (!doSaveTpl && DBG_LAST_TPL_PATH = "")
                doSaveTpl := true

            if (doSaveTpl) {
                if (PIPE_MODE = "F4") {
                tplPath := DBG__MakeUniqueBmpPath("f4_" Format("{:03}", g_F4_Index))
            } else {
                tplPath := DBG__MakeUniqueBmpPath("tpl_elem")
            }
                if (!AL_Capture_RectToBMP(
                        cropRect,
                        tplPath,
                        Map(
                            "caller","AL_L4_TemplateCapture",
                            "srcMode","Screen",
                            "hwnd",0
                        )))
                    tplPath := ""
                else
                    DBG_LAST_TPL_PATH := tplPath
            } else {
                tplPath := DBG_LAST_TPL_PATH
                CAP_Log("FAST MODE | throttle skip tpl_elem SAVE (reuse last)")
            }
        } catch {
            tplPath := ""
        }
    }

; ===============================
; MULTI-ICON EXPORT (SCREEN parent): capture each ROI cropRect separately
; ===============================
global F3_MULTI_ICON, AL_MULTI_SAVE_EACH
if (F3_MULTI_ICON && AL_MULTI_SAVE_EACH && IsObject(filtered) && filtered.Length > 1) {
    try {
        dupIouThr := (IsObject(opts) && opts.Has("multiDupIou")) ? opts["multiDupIou"] : 0.92
        savedRects := [rel]
        ; MULTI DUP GUARD: skip near-duplicate rects so không sinh "cắt lại lần nữa" cho cùng 1 icon.
        Loop filtered.Length {
            if (A_Index = 1)
                continue
            rel2 := filtered[A_Index].rectRel
            isDup := false
            for _, rr in savedRects {
                if (AL_IoU(rel2, rr) >= dupIouThr) {
                    isDup := true
                    break
                }
            }
            if (isDup) {
                CAP_Log("MULTI | SKIP DUP idx=" A_Index " (IoU>=" dupIouThr ")", "WARN")
                continue
            }

            sr2 := AL_RelToScreen(parent, rel2)
            cr2 := AL_ExpandRect(sr2, pad)
            tpl2 := DBG__MakeUniqueBmpPath("tpl_elem_" A_Index)
            ok2 := AL_Capture_RectToBMP(
                cr2,
                tpl2,
                Map(
                    "caller","AL_L4_TemplateCapture_MULTI",
                    "srcMode","Screen",
                    "hwnd",0
                )
            )
            if (ok2) {
                CAP_Log("MULTI | SAVE tpl idx=" A_Index " -> " tpl2)
                savedRects.Push(rel2)
            } else
                CAP_Log("MULTI | FAIL tpl idx=" A_Index, "WARN")
        }
    } catch {
    }
}
    ; 4.2 pick anchors (non-ML): choose K points with high local contrast
    ; NOTE: PixelGetColor loop can be extremely slow on some systems (multi-second).
    ; FAST MODE: skip anchor picking to keep F4/learning responsive.
    global AL_FAST_MODE, CAP_FAST_MODE
    anchors := []
    try {
        if (!AL_FAST_MODE && !CAP_FAST_MODE) {
            anchors := AL_PickAnchors(parentCtx, rel, opts["anchorsK"], opts["anchorTol"])
        } else {
            anchors := []
        }
    } catch {
        anchors := []
    }

    model := ElementModel(id, rel, tplPath, anchors, Map("score", best.score))

    ; Optional persist
    if (IsObject(store)) {
        try {
            store.Write("element", "id", id)
            store.Write("element", "template", tplPath)
            store.Write("element", "rectL", rel.L)
            store.Write("element", "rectT", rel.T)
            store.Write("element", "rectR", rel.R)
            store.Write("element", "rectB", rel.B)
            store.Write("element", "anchorCount", anchors.Length)
            for i, a in anchors {
                store.Write("anchor" i, "dx", a["dx"])
                store.Write("anchor" i, "dy", a["dy"])
                store.Write("anchor" i, "rgb", Format("0x{:06X}", a["rgb"]))
                store.Write("anchor" i, "tol", a["tol"])
            }
        } catch {
        }
    }
    return model
}


; ============================================================
; Layer 5 - State / Behavior Learning
; ============================================================
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

SetGuiMode(mode) {
    global GUI_MODE, GUI_OPA_RUN, GUI_OPA_EDIT, g
    GUI_MODE := mode

    ; Nếu GUI chính chưa tồn tại thì bỏ qua
    try {
        if (!IsObject(g) || !g.Hwnd)
            return
    } catch {
        return
    }

    hwnd := g.Hwnd
    if (mode = "RUN") {
        ; RUN = mờ + click-through (không chặn chuột)
        try {
            WinSetTransparent(GUI_OPA_RUN, "ahk_id " hwnd)
        } catch {
        }
        try {
            WinSetExStyle("+0x20", "ahk_id " hwnd) ; WS_EX_TRANSPARENT
        } catch {
        }
        try {
            g.Show("NA")
        } catch {
        }
        return
    }

    ; EDIT = rõ nét + nhận chuột
    try {
        WinSetTransparent(GUI_OPA_EDIT, "ahk_id " hwnd)
    } catch {
    }
    try {
        WinSetExStyle("-0x20", "ahk_id " hwnd) ; remove WS_EX_TRANSPARENT
    } catch {
    }
    try {
        g.Show()
    } catch {
    }
}


Init() {
    ; ---------- Performance ----------
    SetKeyDelay(-1, -1)
    SetMouseDelay(-1)
    SetWinDelay(-1)
    SetControlDelay(-1)
    ProcessSetPriority("High")

    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    CoordMode("ToolTip", "Screen")

    ; ---------- DPI Guard (block-form try/catch ONLY) ----------
    global DPI_AWARE := false
    global SYS_DPI := 96
    global SCALE_PCT := 100
    InitDpiGuard()

    ; ---------- Config ----------
; ---------------- AI_SAFEZONE100:INIT_MODULE_BEGIN -------------------
; Script initialization / hotkeys / startup. Avoid return-with-value here.
; ---------------------------------------------------------------------
    global CFG_FILE := A_ScriptDir "\ScaleCycle.ini"

    ; INI health flag (must be initialized BEFORE any IniReadSafe/IniWriteSafe calls)
    global iniFaulted := 0

    ; ----- F3 commit + debug -----
    global lastF3CommitTick := 0
    global lastF3CommitOk := false
    ; LOG_FILE is defined at top-level as A_ScriptDir "\error.log"
    global iniFaultNotified := false

    EnsureIniFile()
    ; F3 UX options
    ; allowClickPick=1 in [f3] section => click-only pick is accepted (no-drag will NOT cancel).
    global allowClickPick := (ToIntSafe(IniReadSafe(CFG_FILE, "f3", "allowClickPick", "1"), 1) != 0)

    ; Debug toggles
    global DBG_F3_OK_TOOLTIP := true

    global DBG_F3_DIM_TOOLTIP := false  ; DEBUG: show W/H tooltip after pick
    ; DEBUG: show a tooltip while waiting for mouse press during region pick
    global DBG_PICK_WAIT_TOOLTIP := true
    ; Internal: prevent ParentHistOnChange from overwriting status once (used by F3 flow)
    global parentHistSuppressStatusOnce := false
    ; Internal: lock to prevent GUI Change handlers from interfering during atomic F3 flow
    global f3Atomic := false
    ; Internal: hard lock to block late ComboBox Change messages after F3 refresh
    global parentHistHardLock := false
    ; If true, selecting a history item will also persist [parent] to INI.
    ; Default false to prevent late GUI events from reverting the INI after F3.
    global PERSIST_PARENT_ON_HISTORY_SELECT := false
    ; Internal: temporarily lock Parent history ComboBox Change handler during programmatic refresh (F3)
    ; Target window (state-aware gate)
    global targetExe := Trim(IniReadSafe(CFG_FILE, "target", "exe", ""))
    global targetTitle := Trim(IniReadSafe(CFG_FILE, "target", "title", ""))

    ; General
    global tolerance := ToIntSafe(IniReadSafe(CFG_FILE, "main", "tolerance", "40"), 40)
    global clickOffsetX := ToIntSafe(IniReadSafe(CFG_FILE, "main", "clickOffsetX", "6"), 6)
    global clickOffsetY := ToIntSafe(IniReadSafe(CFG_FILE, "main", "clickOffsetY", "6"), 6)

    ; Parent (manual) region (tier0 / coarse)
    global parentL := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "L", "0"), 0)
    global parentT := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "T", "0"), 0)
    global parentR := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "R", "0"), 0)
    global parentB := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "B", "0"), 0)
    global parentHwnd := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "hwnd", "0"), 0)

    ; Runner region (diamond)
    global runnerL := ToIntSafe(IniReadSafe(CFG_FILE, "runner", "L", "0"), 0)
    global runnerT := ToIntSafe(IniReadSafe(CFG_FILE, "runner", "T", "0"), 0)
    global runnerR := ToIntSafe(IniReadSafe(CFG_FILE, "runner", "R", "0"), 0)
    global runnerB := ToIntSafe(IniReadSafe(CFG_FILE, "runner", "B", "0"), 0)

    ; Scale runner region (optional)
    global scaleRunL := ToIntSafe(IniReadSafe(CFG_FILE, "scale_runner", "L", "0"), 0)
    global scaleRunT := ToIntSafe(IniReadSafe(CFG_FILE, "scale_runner", "T", "0"), 0)
    global scaleRunR := ToIntSafe(IniReadSafe(CFG_FILE, "scale_runner", "R", "0"), 0)
    global scaleRunB := ToIntSafe(IniReadSafe(CFG_FILE, "scale_runner", "B", "0"), 0)

    ; Auto offset fallback
    global scaleDx := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "scaleDx", "160"), 160)
    global scaleDy := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "scaleDy", "0"), 0)

    ; Optional relative offset scaling by window size
    global relOffset := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "relOffset", "1"), 1) ; 0=off,1=scale by window size
    global baseWinW := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "baseWinW", "0"), 0)
    global baseWinH := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "baseWinH", "0"), 0)

    ; Cache/Anchor tuning
    global cacheBox := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "cacheBox", "240"), 240)
    global anchorThr := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "anchorThr", "18"), 18)

    ; Cluster needs
    global anchorNeedCluster := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "anchorNeedCluster", "3"), 3)

    ; L-anchor needs (H/V)
    global anchorNeedH := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "anchorNeedH", "2"), 2)
    global anchorNeedV := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "anchorNeedV", "2"), 2)

    ; Retry timing
    global retryMs := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "retryMs", "700"), 700)
    global retryMinSleep := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "retryMinSleep", "25"), 25)
    global retryMaxSleep := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "retryMaxSleep", "60"), 60)

    ; History boxes
    global diaBox := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "diamondBox", "120"), 120)
    global scaBox := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "scaleBox", "160"), 160)



    ; Scan history cap (avoid INI/GUI bloat)
    global maxScanKeep := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "maxScanKeep", "50"), 50)
    ; Cycle values
    global baseV := ToIntSafe(IniReadSafe(CFG_FILE, "cycle", "base", "100"), 100)
    global lowV  := ToIntSafe(IniReadSafe(CFG_FILE, "cycle", "low", "96"), 96)
    global highV := ToIntSafe(IniReadSafe(CFG_FILE, "cycle", "high", "104"), 104)

    ; Workflow
    global workflowMode := IniReadSafe(CFG_FILE, "workflow", "mode", "KEYFRAME_CYCLE") ; KEYFRAME_CYCLE | CLASSIC
    global jumpPreEsc := ToIntSafe(IniReadSafe(CFG_FILE, "workflow", "jumpPreEsc", "1"), 1)

    ; Keys
    global commitKey   := IniReadSafe(CFG_FILE, "keys", "commitKey", "{Enter}")
    global keyframeKey := IniReadSafe(CFG_FILE, "keys", "keyframeKey", "")
    global nextCutKey  := IniReadSafe(CFG_FILE, "keys", "nextCutKey", "/")

    ; Click modes (1=Click, 2=Double)
    global diamondClickMode := ToIntSafe(IniReadSafe(CFG_FILE, "clickmodes", "diamond", "1"), 1)
    global scaleClickMode   := ToIntSafe(IniReadSafe(CFG_FILE, "clickmodes", "scale", "2"), 2)


    ; F3 ROI ordering (multi-icon list order)
    ; LTR|RTL|TTB|BTT|SCORE|AREA
    try {
        sm := StrUpper(Trim(IniReadSafe(CFG_FILE, "f3roi", "sort", F3_SORT_MODE)))
        if (sm = "LTR" || sm = "RTL" || sm = "TTB" || sm = "BTT" || sm = "SCORE" || sm = "AREA")
            F3_SORT_MODE := sm
    } catch {
        ; keep default
    }

    ; Image lists
    global DIA_LIST := []
    global SCA_LIST := []
    global diaSel := 1
    global scaSel := 1
    LoadImageListsFromIni()

    ; Scan history (newest first)
    global SCANS := []
    LoadScansFromIni()

    ; Parent region history (newest first)
    global PARENT_HIST := []
    LoadParentHistoryFromIni()


    ; Runtime state
    global running := false
    global busy := false
    global F4_QUEUED := false
    global stepIndex := 1

    ; F2 scan toggles
    global f2ScanDia := false
    global f2ScanSca := false

    ; Cache last found positions
    global lastDia := Map("x","", "y","")
    global lastSca := Map("x","", "y","")

    ; Anchor packs (cluster + H + V), auto-learned
    global diaPack := MakeEmptyAnchorPack()
    global scaPack := MakeEmptyAnchorPack()

    ; Window cache (invalidate caches if window moved/resized)
    global winCache := Map("hwnd", 0, "x", 0, "y", 0, "w", 0, "h", 0)

    ; Border overlay GUIs (for region picking)
    global borderG := Map()
    global BORDER_SETS := []  ; pool of border sets for ALL ROI (each ROI = 4 line GUIs)

    OnExit(Cleanup)

        ; ---------- GUI ----------
    ; ==================================================================================================
    ; PATCHABLE_ZONE_GUI_BEGIN
    ; Automation-first GUI (Simple by default; Advanced panel optional)
    ; - SIMPLE: A/B cycle + Learn + Start/Stop + clear instructions
    ; - ADVANCED: Setup/Anchors/History/Help for power users
    ; NOTE: UI-only. Engine logic + hotkeys remain unchanged.
    ; ==================================================================================================

    global UI_VIEW := "SIMPLE"
    global UI_ADV_VISIBLE := false
    global UI_AUTOHIDE_WHEN_RUN := true
    global UI_W_SIMPLE := 640
    global UI_H_SIMPLE := 380
    global UI_W_ADV := 1120
    global UI_H_ADV := 760

    global g := Gui("+AlwaysOnTop +OwnDialogs", "CapCut Auto Keyframe Tool (AHK v2)")
    g.MarginX := 12
    g.MarginY := 10
    g.SetFont("s9", "Segoe UI")

    ; Header
    g.SetFont("s14 bold", "Segoe UI")
    global stTitle := g.AddText("x12 y10 w1200 h26 +0x200", T("TXT_CAPCUT_AUTO_KEYFRAME_TOOL"))
    g.SetFont("s9 norm", "Segoe UI")
    global stSub := g.AddText("x12 y+2 w1200 h20 +0x200"
        , T("TXT_FOCUS_A_NUMERIC_FIELD_IN_CAPCUT_F4_L"))

    ; ================================================================================================
    ; SIMPLE PANEL (default)
    ; ================================================================================================

    global gbMain := g.AddGroupBox("x12 y56 w616 h128", T("GRP_AUTO_KEYFRAME_CYCLE_A_B"))
    mx := 28, my := 86
    g.SetFont("s10 bold", "Segoe UI")
    global stA := g.AddText("x" mx " y" my " w20 h22 +0x200", T("TXT_A"))
    g.SetFont("s10 norm", "Segoe UI")
    global edLow := g.AddEdit("x" (mx+24) " y" (my-2) " w120 h28 Number", lowV)
    g.SetFont("s10 bold", "Segoe UI")
    global stB := g.AddText("x" (mx+170) " y" my " w20 h22 +0x200", T("TXT_B"))
    g.SetFont("s10 norm", "Segoe UI")
    global edHigh := g.AddEdit("x" (mx+194) " y" (my-2) " w120 h28 Number", highV)

    global btnLearn := g.AddButton("x" (mx+330) " y" (my-4) " w150 h32", T("BTN_LEARN_DIAMOND_F4"))
    btnLearn.OnEvent("Click", (*) => F4_Queue(true))

    

    ; Quick test: click the learned diamond once (no "/" and no A/B typing)
    global btnTestDia := g.AddButton("x" (mx+490) " y" (my-4) " w110 h32", T("BTN_TEST_CLICK"))
    btnTestDia.OnEvent("Click", UI_TestDiamondClick)
global chkAutoHide := g.AddCheckBox("x" (mx+340) " y" (my+34) " w220 h22 Checked", T("CHK_AUTO_HIDE_WHILE_RUN"))
    chkAutoHide.OnEvent("Click", UI_OnAutoHideToggle)

    global btnAdvanced := g.AddButton("x" (mx+340) " y" (my+60) " w150 h30", T("BTN_ADVANCED"))
    btnAdvanced.OnEvent("Click", UI_ToggleAdvanced)

    ; Legacy fields (kept for engine/backward compatibility, hidden in SIMPLE)
    global edBase := g.AddEdit("x-2000 y-2000 w90 h22 Hidden Number", baseV)
    global edTol  := g.AddEdit("x-2000 y-2000 w80 h22 Hidden Number", tolerance)
    global edDx   := g.AddEdit("x-2000 y-2000 w90 h22 Hidden Number", scaleDx)
    global edDy   := g.AddEdit("x-2000 y-2000 w90 h22 Hidden Number", scaleDy)

    global btnSave := g.AddButton("x28 y" (56+128-34) " w120 h30", T("BTN_SAVE_INI"))
    btnSave.OnEvent("Click", SaveAllToIni)

    ; How-to (always visible)
    global stHow := g.AddEdit("x12 y196 w616 r5 ReadOnly -Tabstop +VScroll -HScroll"
        , T("EDT_HOW_TO_USE_N")
        . "  1) In CapCut, click a numeric field you want to animate (Scale/Position/Effect).\n"
        . "  2) Press F4 once to learn the diamond (keyframe) button.\n"
        . "  3) Press F1 to start. The tool will: / → wait → click ◇ → type A/B.\n"
        . "  4) Press F1 again (or ESC) to stop.")

    ; ================================================================================================
    ; ADVANCED PANEL (hidden by default)
    ; ================================================================================================

    advX := 12
    advY := 310
    advW := UI_W_ADV - 24
    advH := 370

    global gbAdv := g.AddGroupBox("x" advX " y" advY " w" advW " h" advH " Hidden", T("GRP_ADVANCED"))
    global tabAdv := g.AddTab3("x" (advX+12) " y" (advY+26) " w" (advW-24) " h" (advH-40) " Hidden"
        , ["Setup", "Anchors", "History", "Help"])

    ; --- Tab 1: Setup (Parent / ROIs) ---
    tabAdv.UseTab(1)
    sx := advX + 26
    sy := advY + 70
    global stRoiLblParent := g.AddText("x" sx " y" sy " w120 h20 +0x200", T("TXT_PARENT_REGION"))
    global btnParentSet := g.AddButton("x+8 w140 h28", T("BTN_SET_PARENT_F3"))
    global btnParentShow := g.AddButton("x+10 w120 h28", T("BTN_SHOW"))
    btnParentSet.OnEvent("Click", (*) => F3Handler())
    btnParentShow.OnEvent("Click", (*) => F3GuiShowParentBorder())

    sy2 := sy + 44
    global stRoiLblF3 := g.AddText("x" sx " y" sy2 " w120 h20 +0x200", T("TXT_F3_ROIS"))
    global cbF3Order := g.AddComboBox("x+8 w160 h24", ["L→R", "R→L", "T→B", "B→T", "Score", "Size"])
    global cbF3Rois := g.AddComboBox("x+10 w520 r10 h24", [])
    global cbF3RoiMode := g.AddComboBox("x+10 w110 h24", ["Click", "Double"])
    global btnF3Preview := g.AddButton("x+10 w110 h28", T("BTN_PREVIEW"))
    global btnF3Run := g.AddButton("x+10 w110 h28", T("BTN_RUN"))
    global btnF3Borders := g.AddButton("x" sx " y" (sy2+44) " w160 h28", T("BTN_SHOW_BORDERS"))
    global stF3RoiCount := g.AddText("x+10 w180 h20 +0x200", T("TXT_ROIS_0"))

    cbF3Order.OnEvent("Change", F3OrderOnChange)
    cbF3Rois.OnEvent("Change", F3RoiOnChange)
    cbF3RoiMode.OnEvent("Change", F3RoiModeOnChange)
    btnF3Preview.OnEvent("Click", (*) => F3PreviewSelected())
    btnF3Run.OnEvent("Click", (*) => F3RunSequence())
    btnF3Borders.OnEvent("Click", (*) => F3GuiToggleBorders())

    global stRoiLblHistory := g.AddText("x" sx " y" (sy2+86) " w120 h20 +0x200", T("TXT_PARENT_HISTORY"))
    global cbParentHist := g.AddComboBox("x+8 w520 r10 h24", [])
    global stParentHistCount := g.AddText("x+10 w180 h20 +0x200", T("TXT_ITEMS_0"))
    cbParentHist.OnEvent("Change", ParentHistOnChange)

    ; --- Tab 2: Anchors ---
    tabAdv.UseTab(2)
    ax := advX + 26
    ay := advY + 70
    global stAnchLblDia := g.AddText("x" ax " y" ay " w120 h20 +0x200", T("TXT_DIAMOND_ANCHORS"))
    global cbDia := g.AddComboBox("x+8 w620 r10 h24", [])
    global cbDiaMode := g.AddComboBox("x+10 w110 h24", ["Click", "Double"])
    global chkDiaScan := g.AddCheckBox("x+12 w120", T("CHK_F2_SCAN"))
    global btnDiaAdd := g.AddButton("x+10 w90 h28", T("BTN_ADD"))
    global btnDiaUpd := g.AddButton("x+10 w90 h28", T("BTN_UPDATE"))
    global btnDiaDel := g.AddButton("x+10 w100 h28", T("BTN_REMOVE"))

    cbDia.OnEvent("Change", DiaOnChange)
    cbDiaMode.OnEvent("Change", DiaModeOnChange)
    chkDiaScan.OnEvent("Click", DiaScanToggle)
    btnDiaAdd.OnEvent("Click", DiaAddImages)
    btnDiaUpd.OnEvent("Click", DiaUpdateSelected)
    btnDiaDel.OnEvent("Click", DiaRemoveSelected)

    ay2 := ay + 46
    global stAnchLblSca := g.AddText("x" ax " y" ay2 " w120 h20 +0x200", T("TXT_SCALE_ANCHORS"))
    global cbSca := g.AddComboBox("x+8 w620 r10 h24", [])
    global cbScaMode := g.AddComboBox("x+10 w110 h24", ["Click", "Double"])
    global chkScaScan := g.AddCheckBox("x+12 w120", T("CHK_F2_SCAN"))
    global btnScaAdd := g.AddButton("x+10 w90 h28", T("BTN_ADD"))
    global btnScaUpd := g.AddButton("x+10 w90 h28", T("BTN_UPDATE"))
    global btnScaDel := g.AddButton("x+10 w100 h28", T("BTN_REMOVE"))

    cbSca.OnEvent("Change", ScaOnChange)
    cbScaMode.OnEvent("Change", ScaModeOnChange)
    chkScaScan.OnEvent("Click", ScaScanToggle)
    btnScaAdd.OnEvent("Click", ScaAddImages)
    btnScaUpd.OnEvent("Click", ScaUpdateSelected)
    btnScaDel.OnEvent("Click", ScaRemoveSelected)

    ; --- Tab 3: History ---
    tabAdv.UseTab(3)
    hx := advX + 26
    hy := advY + 70
    global stHistLblScan := g.AddText("x" hx " y" hy " w" (advW-60) " h20 +0x200", T("TXT_SCAN_HISTORY_NEWEST_FIRST"))
    global cbScan := g.AddComboBox("x" hx " y+8 w" (advW-60) " h24 r12", [])
    global stHistHint := g.AddText("x" hx " y+10 w" (advW-60) " h60"
        , T("TXT_HISTORY_RECORDS_LAST_CAPTURES_AND_CO"))

    ; --- Tab 4: Help ---
    tabAdv.UseTab(4)
    kx := advX + 26
    ky := advY + 70
    global stHelp1 := g.AddEdit("x" kx " y" ky " w" (advW-60) " r14 ReadOnly -Tabstop +VScroll -HScroll"
        , T("EDT_QUICK_START_N")
        . "  1) Activate CapCut window\n"
        . "  2) Focus a numeric field (Scale/Position/Effect)\n"
        . "  3) Learn diamond once (F4)\n"
        . "  4) Start/Stop with F1\n\n"
        . "Notes:\n"
        . "  - Tool runs keyboard-first; avoid clicking the tool while running.\n"
        . "  - If CapCut loses focus, the tool may auto-stop for safety.")

    tabAdv.UseTab(0)

    ; ================================================================================================
    ; ACTION BAR (always visible)
    ; ================================================================================================

    global gbActions := g.AddGroupBox("x12 y" (UI_H_SIMPLE-86) " w616 h76", T("GRP_ACTIONS"))
    bx := 28
    by := UI_H_SIMPLE-58
    global btnRunMain := g.AddButton("x" bx " y" by " w130 h34", T("BTN_START_F1"))
    global btnStopMain := g.AddButton("x+10 w130 h34", T("BTN_STOP"))
    global btnResetMain := g.AddButton("x+10 w130 h34 Hidden", T("BTN_RESET_UI"))

    btnRunMain.OnEvent("Click", (*) => ToggleRun())
    btnStopMain.OnEvent("Click", (*) => StopRun())
    btnResetMain.OnEvent("Click", (*) => UI_ResetUiOnly())

    g.SetFont("s12 bold", "Segoe UI")
    global stStateDot := g.AddText("x+22 y" by " w18 h28 +0x200", T("TXT_TXT_01"))
    g.SetFont("s10 bold", "Segoe UI")
    global stStateText := g.AddText("x+6 y" by+2 " w140 h28 +0x200", T("TXT_READY"))
    g.SetFont("s9 norm", "Segoe UI")

    global stStatus := g.AddText("x12 y" (UI_H_SIMPLE-26) " w616 h20 +0x200", T("TXT_STATUS_READY"))

    ; Module registry (for enable/disable gating)
    global UI_MODULES := Map()
    UI_MODULES["Main"] := [edLow, edHigh, btnLearn, chkAutoHide, btnAdvanced, btnSave]
    UI_MODULES["Advanced"] := [gbAdv, tabAdv, stRoiLblParent, btnParentSet, btnParentShow, stRoiLblF3, cbF3Order, cbF3Rois, cbF3RoiMode, btnF3Preview, btnF3Run, btnF3Borders, stF3RoiCount, stRoiLblHistory, cbParentHist, stParentHistCount, stAnchLblDia, cbDia, cbDiaMode, chkDiaScan, btnDiaAdd, btnDiaUpd, btnDiaDel, stAnchLblSca, cbSca, cbScaMode, chkScaScan, btnScaAdd, btnScaUpd, btnScaDel, stHistLblScan, cbScan, stHistHint, stHelp1]

    ; Populate UI data
    RefreshDiaCombo()
    RefreshScaCombo()
    SetModeCombos()
    SetF3OrderCombo()
    RefreshF3RoiCombo()
    RefreshScanCombo()
    RefreshParentHistCombo()
    SyncScanChecks()

    ; Initial state badge + enable policy
    UI_UpdateStateBadge()
    UI_ApplyEnablePolicy(true)

    ; Show (no-activate)
    g.Show("w" UI_W_SIMPLE " h" UI_H_SIMPLE " NA")

    ; Hide advanced by default
    UI_SetAdvancedVisible(false)

    ; PATCHABLE_ZONE_GUI_END
    ; ==================================================================================================
; ---------- GUI MODE / HOTSPOT ----------
    ; Tạo hotspot riêng để toggle GUI RUN/EDIT.
    ; RUN: g mờ + click-through (không chặn chuột)
    ; EDIT: g rõ nét + nhận chuột để chỉnh ROI
    InitGuiHotspot()
    SetGuiMode(GUI_MODE)

    ; ---------- Hotkeys ----------
    Hotkey("F1", (*) => ToggleRun())
    Hotkey("F2", (*) => F2Handler())
    Hotkey("F3", (*) => F3Handler())
    Hotkey("F4", (*) => F4_Queue(true))
    Hotkey("^F4", (*) => F4_Queue(false))

    ; ---------- F3 Overlay Order (direct on-screen) ----------
    ; F6: Toggle overlay | F8: Clear orders | F9: Run (can be changed in globals)
    try {
        InitF3OverlayHotkeys()
    } catch {
    }
    ; return   ; (removed) avoid #Warn unreachable definitions below. GUI+Hotkeys keep script running.

    ; =========================================================
    ; DPI Guard
    ; =========================================================
}

; -------------------------
; AUTO-EXEC
; -------------------------

Init()
return