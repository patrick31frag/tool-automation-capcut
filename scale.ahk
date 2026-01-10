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

; ==================================================================================================
;  SPLIT MODULE INCLUDES (auto-generated) — DO NOT REORDER
; ==================================================================================================

#Include Scale_01_Logger.ahk
#Include Scale_02_Logger.ahk
#Include Scale_03_Pixel.ahk
#Include Scale_04_Logger.ahk
#Include Scale_05_Logger.ahk
#Include Scale_06_Logger.ahk
#Include Scale_07_Logger.ahk
#Include Scale_08_Pixel.ahk
#Include Scale_09_Action.ahk
#Include Scale_10_Engine.ahk
#Include Scale_11_Logger.ahk
#Include Scale_12_Action.ahk
#Include Scale_13_Action.ahk
#Include Scale_14_Action.ahk
#Include Scale_15_Action.ahk
#Include Scale_16_Logger.ahk
#Include Scale_17_Logger.ahk
#Include Scale_18_Engine.ahk
#Include Scale_19_Logger.ahk
#Include Scale_20_Logger.ahk
#Include Scale_21_Logger.ahk
#Include Scale_22_Logger.ahk
#Include Scale_23_Logger.ahk
#Include Scale_24_Pixel.ahk
#Include Scale_25_Logger.ahk
#Include Scale_26_GUI.ahk
