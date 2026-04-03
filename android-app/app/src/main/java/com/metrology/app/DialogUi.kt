package com.metrology.app

import android.app.AlertDialog
import android.widget.Button
import android.widget.LinearLayout
import kotlin.math.roundToInt

enum class DialogPositiveStyle {
    PRIMARY,
    DANGER
}

fun AlertDialog.applyMetrologyDialogStyle(
    positiveStyle: DialogPositiveStyle = DialogPositiveStyle.PRIMARY
) {
    window?.setBackgroundDrawableResource(R.drawable.bg_card)
    window?.let { window ->
        val metrics = context.resources.displayMetrics
        val width = (metrics.widthPixels * 0.92f).roundToInt()
        window.setLayout(width, LinearLayout.LayoutParams.WRAP_CONTENT)
    }

    val negativeButton = getButton(AlertDialog.BUTTON_NEGATIVE)
    val positiveButton = getButton(AlertDialog.BUTTON_POSITIVE)
    val neutralButton = getButton(AlertDialog.BUTTON_NEUTRAL)

    if (negativeButton != null) {
        styleDialogButton(
            button = negativeButton,
            backgroundRes = R.drawable.bg_dialog_action_cancel,
            textColorRes = R.color.dialogActionCancelText
        )
    }

    if (positiveButton != null) {
        val (backgroundRes, textColorRes) = when (positiveStyle) {
            DialogPositiveStyle.PRIMARY -> R.drawable.bg_dialog_action_save to R.color.white
            DialogPositiveStyle.DANGER -> R.drawable.bg_dialog_action_danger to R.color.dialogActionDangerText
        }
        styleDialogButton(
            button = positiveButton,
            backgroundRes = backgroundRes,
            textColorRes = textColorRes
        )
    }

    if (neutralButton != null) {
        styleDialogButton(
            button = neutralButton,
            backgroundRes = R.drawable.bg_secondary_button,
            textColorRes = R.color.textPrimary
        )
    }

    val anchor = positiveButton ?: negativeButton ?: neutralButton ?: return
    val parent = anchor.parent as? LinearLayout ?: return
    if (parent.orientation == LinearLayout.HORIZONTAL) {
        layoutDialogButton(negativeButton, marginStart = 0, marginEnd = dp(6))
        layoutDialogButton(neutralButton, marginStart = dp(6), marginEnd = dp(6))
        layoutDialogButton(positiveButton, marginStart = dp(6), marginEnd = 0)
    } else {
        layoutDialogButton(negativeButton, marginStart = 0, marginEnd = 0)
        layoutDialogButton(neutralButton, marginStart = 0, marginEnd = 0)
        layoutDialogButton(positiveButton, marginStart = 0, marginEnd = 0)
    }
}

private fun AlertDialog.styleDialogButton(
    button: Button,
    backgroundRes: Int,
    textColorRes: Int
) {
    button.setAllCaps(false)
    button.textSize = 14f
    button.minHeight = dp(42)
    button.alpha = 1f
    button.backgroundTintList = null
    button.setBackgroundResource(backgroundRes)
    button.setTextColor(context.getColor(textColorRes))
    button.stateListAnimator = null
    button.elevation = dp(1).toFloat()
    button.translationZ = 0f
    button.setPadding(dp(12), 0, dp(12), 0)
}

private fun AlertDialog.layoutDialogButton(
    button: Button?,
    marginStart: Int,
    marginEnd: Int
) {
    if (button == null) return
    val params = button.layoutParams as? LinearLayout.LayoutParams ?: return
    params.width = 0
    params.weight = 1f
    params.marginStart = marginStart
    params.marginEnd = marginEnd
    params.topMargin = dp(6)
    params.bottomMargin = dp(2)
    button.layoutParams = params
}

private fun AlertDialog.dp(value: Int): Int {
    val density = context.resources.displayMetrics.density
    return (value * density).roundToInt()
}
