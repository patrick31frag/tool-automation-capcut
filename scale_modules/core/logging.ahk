; ==================================================================================================
; LOGGING MODULE
; --------------------------------------------------------------------------------------------------
; Log, LogWarn, LogError, LogRuntimeError, OnError hook
; ==================================================================================================

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
