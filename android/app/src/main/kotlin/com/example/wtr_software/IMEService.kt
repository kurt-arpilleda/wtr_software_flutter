package com.example.wtr_software

import android.inputmethodservice.InputMethodService
import android.view.inputmethod.InputConnection

class IMEService : InputMethodService() {
    override fun onCreateInputView(): android.view.View {
        return android.view.LayoutInflater.from(this).inflate(
            resources.getIdentifier("keyboard", "layout", packageName),
            null
        )
    }
}