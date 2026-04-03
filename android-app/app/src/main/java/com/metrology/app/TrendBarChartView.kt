package com.metrology.app

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.util.TypedValue
import android.util.AttributeSet
import android.view.View
import android.view.animation.DecelerateInterpolator
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow

class TrendBarChartView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    private var data: List<TrendPointUi> = emptyList()
    private var animationProgress: Float = 1f
    private var revealAnimator: ValueAnimator? = null

    private val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(1f)
        color = Color.parseColor("#DDE6F3")
    }

    private val axisTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = context.getColor(R.color.textMuted)
        textSize = sp(11f)
        textAlign = Paint.Align.RIGHT
    }

    private val xTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = context.getColor(R.color.textSecondary)
        textSize = sp(12f)
        textAlign = Paint.Align.CENTER
    }

    private val valuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = context.getColor(R.color.navActive)
        textSize = sp(12f)
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }

    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val emptyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = context.getColor(R.color.textMuted)
        textSize = sp(13f)
        textAlign = Paint.Align.CENTER
    }

    fun setTrendData(points: List<TrendPointUi>) {
        data = points.takeLast(6)
        startRevealAnimation()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (data.isEmpty()) {
            canvas.drawText("暂无趋势数据", width / 2f, height / 2f, emptyPaint)
            return
        }

        val left = dp(34f)
        val top = dp(16f)
        val right = width - dp(10f)
        val bottom = height - dp(34f)
        val chartWidth = right - left
        val chartHeight = bottom - top

        if (chartWidth <= 0f || chartHeight <= 0f) return

        val rawMax = data.maxOf { it.value.toFloat() }
        val maxValue = niceMax(max(10f, rawMax))
        val rows = 5

        for (i in 0..rows) {
            val ratio = i / rows.toFloat()
            val y = bottom - ratio * chartHeight
            canvas.drawLine(left, y, right, y, gridPaint)
            val value = (maxValue * ratio).toInt().toString()
            canvas.drawText(value, left - dp(6f), y + dp(4f), axisTextPaint)
        }

        val slotWidth = chartWidth / data.size
        val barWidth = slotWidth * 0.68f
        val radius = dp(8f)
        data.forEachIndexed { index, point ->
            val centerX = left + index * slotWidth + slotWidth / 2f
            val barHeight = if (maxValue <= 0f) 0f else (point.value.toFloat() / maxValue) * chartHeight
            val animatedHeight = barHeight * animationProgress
            val barTop = bottom - animatedHeight
            val barRect = RectF(
                centerX - barWidth / 2f,
                barTop,
                centerX + barWidth / 2f,
                bottom
            )

            barPaint.shader = LinearGradient(
                0f,
                barTop,
                0f,
                bottom,
                intArrayOf(Color.parseColor("#4E8BFF"), context.getColor(R.color.navActive)),
                null,
                Shader.TileMode.CLAMP
            )
            canvas.drawRoundRect(barRect, radius, radius, barPaint)

            val valueAlpha = (animationProgress * 255).toInt().coerceIn(0, 255)
            valuePaint.alpha = valueAlpha
            val currentValue = (point.value * animationProgress).toLong().coerceAtLeast(0L)
            canvas.drawText(currentValue.toString(), centerX, barTop - dp(6f), valuePaint)
            valuePaint.alpha = 255
            canvas.drawText(point.label, centerX, bottom + dp(20f), xTextPaint)
        }
    }

    private fun startRevealAnimation() {
        revealAnimator?.cancel()
        if (data.isEmpty()) {
            animationProgress = 1f
            invalidate()
            return
        }
        animationProgress = 0f
        revealAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 700L
            interpolator = DecelerateInterpolator(1.15f)
            addUpdateListener { animator ->
                animationProgress = animator.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    override fun onDetachedFromWindow() {
        revealAnimator?.cancel()
        revealAnimator = null
        super.onDetachedFromWindow()
    }

    private fun niceMax(value: Float): Float {
        if (value <= 0f) return 10f
        val exp = floor(log10(value.toDouble())).toInt()
        val base = 10f.pow(exp)
        val norm = value / base
        val nice = when {
            norm <= 1f -> 1f
            norm <= 2f -> 2f
            norm <= 5f -> 5f
            else -> 10f
        }
        return ceil((nice * base).toDouble()).toFloat()
    }

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
    private fun sp(v: Float): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, v, resources.displayMetrics)
}
