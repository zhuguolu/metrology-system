package com.metrology.app

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.util.TypedValue
import android.view.MotionEvent
import android.view.View
import android.view.animation.DecelerateInterpolator
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.roundToLong

class ValidityDonutChartView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    private var valid: Long = 0L
    private var warning: Long = 0L
    private var expired: Long = 0L
    private var animationProgress: Float = 1f
    private var revealAnimator: ValueAnimator? = null
    private var onSegmentClickListener: ((Segment) -> Unit)? = null

    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(24f)
        color = context.getColor(R.color.surfaceCardSoftBlue)
    }

    private val segmentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(24f)
        strokeCap = Paint.Cap.BUTT
    }

    private val centerValuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = context.getColor(R.color.textPrimary)
        textSize = sp(22f)
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }

    private val centerLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = context.getColor(R.color.textMuted)
        textSize = sp(12f)
        textAlign = Paint.Align.CENTER
    }

    fun setDistribution(valid: Long, warning: Long, expired: Long) {
        this.valid = valid.coerceAtLeast(0L)
        this.warning = warning.coerceAtLeast(0L)
        this.expired = expired.coerceAtLeast(0L)
        startRevealAnimation()
    }

    fun setOnSegmentClickListener(listener: ((Segment) -> Unit)?) {
        onSegmentClickListener = listener
        isClickable = listener != null
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val listener = onSegmentClickListener ?: return super.onTouchEvent(event)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> return true
            MotionEvent.ACTION_UP -> {
                performClick()
                resolveSegmentAt(event.x, event.y)?.let {
                    listener.invoke(it)
                    return true
                }
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val size = min(width, height).toFloat()
        val radius = size * 0.35f
        val cx = width / 2f
        val cy = height / 2f
        val rect = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        canvas.drawArc(rect, 0f, 360f, false, trackPaint)

        val total = valid + warning + expired
        if (total > 0L) {
            val gap = 2.8f
            var start = -90f
            drawSegment(canvas, rect, start, valid, total, context.getColor(R.color.statusValid), gap).also { start += it }
            drawSegment(canvas, rect, start, warning, total, context.getColor(R.color.statusWarning), gap).also { start += it }
            drawSegment(canvas, rect, start, expired, total, context.getColor(R.color.statusExpired), gap)
        }

        val animatedTotal = (total.toFloat() * animationProgress).roundToLong()
        canvas.drawText(animatedTotal.toString(), cx, cy + dp(6f), centerValuePaint)
        canvas.drawText("设备总数", cx, cy + dp(26f), centerLabelPaint)
    }

    private fun drawSegment(
        canvas: Canvas,
        rect: RectF,
        start: Float,
        value: Long,
        total: Long,
        color: Int,
        gap: Float
    ): Float {
        if (value <= 0L || total <= 0L) return 0f
        val fullSweep = value.toFloat() / total.toFloat() * 360f
        val animatedSweep = fullSweep * animationProgress
        val sweep = (animatedSweep - gap).coerceAtLeast(0f)
        if (sweep <= 0f) return fullSweep
        segmentPaint.color = color
        canvas.drawArc(rect, start + gap / 2f, sweep, false, segmentPaint)
        return fullSweep
    }

    private fun resolveSegmentAt(x: Float, y: Float): Segment? {
        val total = valid + warning + expired
        if (total <= 0L) return null

        val size = min(width, height).toFloat()
        val radius = size * 0.35f
        val cx = width / 2f
        val cy = height / 2f
        val dx = x - cx
        val dy = y - cy
        val distance = hypot(dx, dy)
        val stroke = trackPaint.strokeWidth
        val tolerance = dp(12f)
        val outer = radius + stroke / 2f + tolerance
        val inner = (radius - stroke / 2f - tolerance).coerceAtLeast(0f)
        if (distance > outer || distance < inner) return null

        val angleFromTop = normalizeAngle(Math.toDegrees(atan2(dy.toDouble(), dx.toDouble())).toFloat() + 90f)
        val gap = 2.8f
        var start = -90f

        val validSweep = valid.toFloat() / total.toFloat() * 360f
        if (matchesSegment(angleFromTop, start, validSweep, gap)) return Segment.VALID
        start += validSweep

        val warningSweep = warning.toFloat() / total.toFloat() * 360f
        if (matchesSegment(angleFromTop, start, warningSweep, gap)) return Segment.WARNING
        start += warningSweep

        val expiredSweep = expired.toFloat() / total.toFloat() * 360f
        if (matchesSegment(angleFromTop, start, expiredSweep, gap)) return Segment.EXPIRED

        return null
    }

    private fun matchesSegment(
        angleFromTop: Float,
        startFromRight: Float,
        fullSweep: Float,
        gap: Float
    ): Boolean {
        if (fullSweep <= 0f) return false
        val animatedSweep = fullSweep * animationProgress
        val visibleSweep = (animatedSweep - gap).coerceAtLeast(0f)
        if (visibleSweep <= 0f) return false
        val segmentStart = normalizeAngle(startFromRight + gap / 2f + 90f)
        return isAngleInSweep(angleFromTop, segmentStart, visibleSweep)
    }

    private fun isAngleInSweep(angle: Float, start: Float, sweep: Float): Boolean {
        val normalizedAngle = normalizeAngle(angle)
        val normalizedStart = normalizeAngle(start)
        val end = normalizeAngle(normalizedStart + sweep)
        return if (normalizedStart <= end) {
            normalizedAngle in normalizedStart..end
        } else {
            normalizedAngle >= normalizedStart || normalizedAngle <= end
        }
    }

    private fun normalizeAngle(angle: Float): Float {
        var normalized = angle % 360f
        if (normalized < 0f) normalized += 360f
        return normalized
    }

    private fun startRevealAnimation() {
        revealAnimator?.cancel()
        val total = valid + warning + expired
        if (total <= 0L) {
            animationProgress = 1f
            invalidate()
            return
        }
        animationProgress = 0f
        revealAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 760L
            interpolator = DecelerateInterpolator(1.2f)
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

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
    private fun sp(v: Float): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, v, resources.displayMetrics)

    enum class Segment {
        VALID,
        WARNING,
        EXPIRED
    }
}
