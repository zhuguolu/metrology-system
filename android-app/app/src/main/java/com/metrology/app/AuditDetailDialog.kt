package com.metrology.app

import android.app.AlertDialog
import android.view.LayoutInflater
import android.widget.TextView
import androidx.fragment.app.Fragment
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.metrology.app.databinding.DialogAuditDetailBinding
import com.metrology.app.databinding.ItemAuditDiffRowBinding
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt

private data class AuditDiffRow(
    val key: String,
    val label: String,
    val before: String,
    val after: String
)

fun Fragment.showAuditDetailDialog(record: AuditRecordDto) {
    val context = requireContext()
    val inflater = LayoutInflater.from(context)
    val binding = DialogAuditDetailBinding.inflate(inflater)
    val diffRows = buildAuditDiffRows(record)

    val actionLabel = auditActionLabel(record.type)
    val entityLabel = auditEntityLabel(record.entityType)
    val statusLabel = auditStatusLabel(record.status)
    binding.txtAuditDetailTitle.text = "${actionLabel}${entityLabel}申请 · $statusLabel"

    val submitMeta = "${record.submittedBy.fixMojibakeOrDash()} · ${formatAuditDateTime(record.submittedAt)}"
    binding.txtFlowSubmitTitle.text = "提交申请"
    binding.txtFlowSubmitMeta.text = submitMeta
    styleTimelineBadge(
        badge = binding.txtFlowSubmitBadge,
        text = "✓",
        backgroundRes = R.drawable.bg_chip_valid,
        textColor = context.getColor(R.color.statusValid)
    )

    val statusCode = record.status.fixMojibake().uppercase(Locale.ROOT)
    when (statusCode) {
        "APPROVED" -> {
            binding.txtFlowApproveTitle.text = "管理员审核"
            binding.txtFlowApproveMeta.text =
                "${record.approvedBy.fixMojibakeOrDash()} · ${formatAuditDateTime(record.approvedAt)}"
            styleTimelineBadge(
                badge = binding.txtFlowApproveBadge,
                text = "✓",
                backgroundRes = R.drawable.bg_chip_valid,
                textColor = context.getColor(R.color.statusValid)
            )
            binding.viewFlowLine.setBackgroundColor(context.getColor(R.color.statusValid))
        }

        "REJECTED" -> {
            binding.txtFlowApproveTitle.text = "管理员驳回"
            binding.txtFlowApproveMeta.text =
                "${record.approvedBy.fixMojibakeOrDash()} · ${formatAuditDateTime(record.approvedAt)}"
            styleTimelineBadge(
                badge = binding.txtFlowApproveBadge,
                text = "!",
                backgroundRes = R.drawable.bg_chip_expired,
                textColor = context.getColor(R.color.statusExpired)
            )
            binding.viewFlowLine.setBackgroundColor(context.getColor(R.color.statusExpired))
        }

        else -> {
            binding.txtFlowApproveTitle.text = "等待审核"
            binding.txtFlowApproveMeta.text = "待管理员处理"
            styleTimelineBadge(
                badge = binding.txtFlowApproveBadge,
                text = "…",
                backgroundRes = R.drawable.bg_chip_warning,
                textColor = context.getColor(R.color.statusWarning)
            )
            binding.viewFlowLine.setBackgroundColor(context.getColor(R.color.statusWarning))
        }
    }

    val finalRows = if (diffRows.isNotEmpty()) {
        diffRows
    } else {
        listOf(AuditDiffRow("no_change", "无字段变化", "-", "-"))
    }
    binding.txtAuditDiffCount.text = "${finalRows.size} 项已修改"

    finalRows.forEach { row ->
        val rowBinding = ItemAuditDiffRowBinding.inflate(inflater, binding.layoutAuditDiffRows, false)
        rowBinding.txtDiffField.text = row.label
        rowBinding.txtDiffBefore.text = row.before
        rowBinding.txtDiffAfter.text = row.after
        applyValueTone(row.key, row.before, rowBinding.txtDiffBefore)
        applyValueTone(row.key, row.after, rowBinding.txtDiffAfter)
        binding.layoutAuditDiffRows.addView(rowBinding.root)
    }

    val dialog = AlertDialog.Builder(context)
        .setView(binding.root)
        .create()
    dialog.window?.setBackgroundDrawableResource(R.drawable.bg_card)

    binding.buttonCloseAuditDetail.setOnClickListener { dialog.dismiss() }
    binding.buttonAuditDetailCloseAction.setOnClickListener { dialog.dismiss() }

    dialog.setOnShowListener {
        val metrics = resources.displayMetrics
        val width = (metrics.widthPixels * 0.96f).roundToInt()
        val maxHeight = (metrics.heightPixels * 0.82f).roundToInt()
        dialog.window?.setLayout(width, maxHeight)
    }

    dialog.show()
}

private fun styleTimelineBadge(
    badge: TextView,
    text: String,
    backgroundRes: Int,
    textColor: Int
) {
    badge.text = text
    badge.setBackgroundResource(backgroundRes)
    badge.setTextColor(textColor)
}

private fun applyValueTone(key: String, value: String, view: TextView) {
    val tone = resolveTone(key, value) ?: return
    when (tone) {
        AuditValueTone.VALID -> view.setTextColor(view.context.getColor(R.color.statusValid))
        AuditValueTone.WARNING -> view.setTextColor(view.context.getColor(R.color.statusWarning))
        AuditValueTone.EXPIRED -> view.setTextColor(view.context.getColor(R.color.statusExpired))
        AuditValueTone.NEUTRAL -> view.setTextColor(view.context.getColor(R.color.textSecondary))
    }
}

private enum class AuditValueTone {
    VALID,
    WARNING,
    EXPIRED,
    NEUTRAL
}

private fun resolveTone(key: String, value: String): AuditValueTone? {
    val raw = value.fixMojibake().trim()
    if (raw.isBlank() || raw == "-") return AuditValueTone.NEUTRAL
    val leaf = key.substringAfterLast(".")
    val statusText = when (leaf) {
        "status", "validity", "useStatus", "calibrationResult", "result" -> raw
        else -> raw
    }
    return when {
        statusText.contains("有效") ||
            statusText.equals("正常", ignoreCase = true) ||
            statusText.equals("合格", ignoreCase = true) ||
            statusText.equals("APPROVED", ignoreCase = true) -> AuditValueTone.VALID

        statusText.contains("即将") ||
            statusText.contains("预警") ||
            statusText.equals("故障", ignoreCase = true) ||
            statusText.equals("PENDING", ignoreCase = true) -> AuditValueTone.WARNING

        statusText.contains("失效") ||
            statusText.contains("报废") ||
            statusText.equals("不合格", ignoreCase = true) ||
            statusText.equals("REJECTED", ignoreCase = true) -> AuditValueTone.EXPIRED

        else -> null
    }
}

private fun buildAuditDiffRows(record: AuditRecordDto): List<AuditDiffRow> {
    val beforeMap = parseAuditDataToFlatMap(record.originalData)
    val afterMap = parseAuditDataToFlatMap(record.newData)
    if (beforeMap.isEmpty() && afterMap.isEmpty()) {
        val beforeRaw = record.originalData.fixMojibakeOrDash()
        val afterRaw = record.newData.fixMojibakeOrDash()
        return if (beforeRaw != afterRaw) {
            listOf(AuditDiffRow("raw", "变更内容", beforeRaw, afterRaw))
        } else {
            emptyList()
        }
    }

    val recordType = record.type.fixMojibake().uppercase(Locale.ROOT)
    val candidateKeys = when (recordType) {
        "UPDATE" -> afterMap.keys
        "CREATE" -> afterMap.keys
        "DELETE" -> beforeMap.keys
        else -> (beforeMap.keys + afterMap.keys)
    }
        .distinct()
        .filterNot(::shouldSkipAuditDiffField)
        .sortedWith(
            compareBy<String> { auditFieldOrder(it.substringAfterLast(".")) }
                .thenBy { auditFieldLabel(it) }
        )

    return when (recordType) {
        "UPDATE" -> candidateKeys.mapNotNull { key ->
            val submitted = isSubmittedAuditValue(afterMap[key])
            if (!submitted) return@mapNotNull null

            val beforeValue = normalizeAuditFieldValue(key, beforeMap[key])
            val afterValue = normalizeAuditFieldValue(key, afterMap[key])
            if (!isAuditValueChanged(beforeValue, afterValue)) return@mapNotNull null

            AuditDiffRow(
                key = key,
                label = auditFieldLabel(key),
                before = beforeValue,
                after = afterValue
            )
        }

        "CREATE" -> candidateKeys.mapNotNull { key ->
            val afterValue = normalizeAuditFieldValue(key, afterMap[key])
            if (!hasAuditDisplayValue(afterValue)) return@mapNotNull null
            AuditDiffRow(
                key = key,
                label = auditFieldLabel(key),
                before = "",
                after = afterValue
            )
        }

        "DELETE" -> candidateKeys.mapNotNull { key ->
            val beforeValue = normalizeAuditFieldValue(key, beforeMap[key])
            if (!hasAuditDisplayValue(beforeValue)) return@mapNotNull null
            AuditDiffRow(
                key = key,
                label = auditFieldLabel(key),
                before = beforeValue,
                after = ""
            )
        }

        else -> candidateKeys.mapNotNull { key ->
            val beforeValue = normalizeAuditFieldValue(key, beforeMap[key])
            val afterValue = normalizeAuditFieldValue(key, afterMap[key])
            if (!isAuditValueChanged(beforeValue, afterValue)) return@mapNotNull null
            AuditDiffRow(
                key = key,
                label = auditFieldLabel(key),
                before = beforeValue,
                after = afterValue
            )
        }
    }
}

private val auditDiffSkipFields = setOf(
    "id",
    "nextCalDate",
    "nextDate",
    "validity",
    "daysPassed"
)

private fun shouldSkipAuditDiffField(key: String): Boolean {
    val leaf = key.substringAfterLast(".")
    return leaf in auditDiffSkipFields
}

private fun isSubmittedAuditValue(value: String?): Boolean {
    val normalized = value.fixMojibake().trim()
    return normalized.isNotBlank() &&
        normalized != "-" &&
        !normalized.equals("null", ignoreCase = true)
}

private fun hasAuditDisplayValue(value: String?): Boolean {
    val normalized = value.fixMojibake().trim()
    return normalized.isNotBlank() &&
        normalized != "-" &&
        !normalized.equals("null", ignoreCase = true)
}

private fun isAuditValueChanged(before: String, after: String): Boolean {
    return comparableAuditValue(before) != comparableAuditValue(after)
}

private fun comparableAuditValue(value: String): String? {
    val normalized = value.fixMojibake().trim()
    if (normalized.isBlank() || normalized == "-" || normalized.equals("null", ignoreCase = true)) {
        return null
    }
    return normalized
}

private fun parseAuditDataToFlatMap(raw: String?): Map<String, String> {
    val content = raw.fixMojibake().trim()
    if (content.isBlank() || content == "-" || content.equals("null", ignoreCase = true)) {
        return emptyMap()
    }
    val element = runCatching { JsonParser.parseString(content) }.getOrNull() ?: return emptyMap()
    val result = linkedMapOf<String, String>()
    flattenJsonElement(element, "", result)
    return result
}

private fun flattenJsonElement(
    element: JsonElement,
    prefix: String,
    output: MutableMap<String, String>
) {
    when {
        element.isJsonNull -> {
            if (prefix.isNotBlank()) output[prefix] = "-"
        }

        element.isJsonPrimitive -> {
            if (prefix.isNotBlank()) output[prefix] = jsonElementToString(element)
        }

        element.isJsonObject -> {
            val obj: JsonObject = element.asJsonObject
            if (obj.entrySet().isEmpty()) {
                if (prefix.isNotBlank()) output[prefix] = "-"
                return
            }
            obj.entrySet()
                .sortedBy { it.key }
                .forEach { entry ->
                    val nextKey = if (prefix.isBlank()) entry.key else "$prefix.${entry.key}"
                    flattenJsonElement(entry.value, nextKey, output)
                }
        }

        element.isJsonArray -> {
            if (prefix.isBlank()) return
            val values = element.asJsonArray.map { item ->
                if (item.isJsonPrimitive) {
                    jsonElementToString(item)
                } else {
                    item.toString().fixMojibake()
                }
            }
            output[prefix] = values.joinToString(separator = ", ").ifBlank { "-" }
        }
    }
}

private fun jsonElementToString(element: JsonElement): String {
    val primitive = element.asJsonPrimitive
    return when {
        primitive.isString -> primitive.asString.fixMojibake().ifBlank { "-" }
        primitive.isBoolean -> if (primitive.asBoolean) "是" else "否"
        primitive.isNumber -> primitive.asNumber.toString()
        else -> primitive.toString().fixMojibake()
    }
}

private fun normalizeAuditFieldValue(key: String, value: String?): String {
    val leaf = key.substringAfterLast(".")
    val normalized = value.fixMojibake().trim().ifBlank { "-" }
    if (normalized.equals("null", ignoreCase = true)) return "-"

    return when (leaf) {
        "type" -> auditActionLabel(normalized)
        "entityType" -> auditEntityLabel(normalized)
        "status" -> translateStatusValue(normalized)
        "validity" -> translateValidityValue(normalized)
        "calibrationResult", "result" -> translateCalibrationResult(normalized)
        "cycle" -> translateCycleValue(normalized)
        "purchasePrice" -> formatNumber(normalized)
        "submittedAt", "approvedAt" -> formatAuditDateTime(normalized)
        "purchaseDate", "calDate", "nextDate" -> formatAuditDate(normalized)
        else -> normalized
    }
}

private fun formatNumber(input: String): String {
    return input.toDoubleOrNull()?.let { value ->
        if (value % 1.0 == 0.0) {
            value.toLong().toString()
        } else {
            value.toString()
        }
    } ?: input
}

private fun formatAuditDate(input: String): String {
    return runCatching { LocalDate.parse(input).format(DateTimeFormatter.ofPattern("yyyy-MM-dd")) }
        .getOrElse { input }
}

private fun formatAuditDateTime(input: String?): String {
    return input.formatToMinuteDateTime()
}

private fun translateCycleValue(value: String): String {
    val cycle = value.toIntOrNull() ?: return value
    return when (cycle) {
        6 -> "半年"
        12 -> "一年"
        else -> "${cycle}个月"
    }
}

private fun translateCalibrationResult(value: String): String {
    return when (value.uppercase(Locale.ROOT)) {
        "QUALIFIED" -> "合格"
        "UNQUALIFIED" -> "不合格"
        else -> value
    }
}

private fun translateValidityValue(value: String): String {
    return when (value.uppercase(Locale.ROOT)) {
        "VALID" -> "有效"
        "WARNING", "EXPIRING", "NEAR_EXPIRY" -> "即将过期"
        "EXPIRED", "INVALID" -> "失效"
        else -> value
    }
}

private fun translateStatusValue(value: String): String {
    return when (value.uppercase(Locale.ROOT)) {
        "NORMAL" -> "正常"
        "FAULT", "BROKEN" -> "故障"
        "SCRAP", "DISCARDED" -> "报废"
        "APPROVED" -> "已通过"
        "REJECTED" -> "已驳回"
        "PENDING" -> "待审批"
        else -> value
    }
}

private fun auditActionLabel(value: String?): String {
    val key = value.fixMojibake().uppercase(Locale.ROOT)
    return when (key) {
        "CREATE" -> "新增"
        "UPDATE" -> "修改"
        "DELETE" -> "删除"
        else -> "变更"
    }
}

private fun auditEntityLabel(value: String?): String {
    val key = value.fixMojibake().uppercase(Locale.ROOT)
    return when (key) {
        "DEVICE" -> "设备"
        "CALIBRATION" -> "校准"
        "USER" -> "用户"
        "DEPARTMENT" -> "部门"
        else -> "数据"
    }
}

private fun auditStatusLabel(value: String?): String {
    val key = value.fixMojibake().uppercase(Locale.ROOT)
    return when (key) {
        "APPROVED" -> "已通过"
        "PENDING" -> "待审批"
        "REJECTED" -> "已驳回"
        else -> value.fixMojibakeOrDash()
    }
}

private fun auditFieldLabel(path: String): String {
    val key = path.substringAfterLast(".")
    return auditFieldLabels[key] ?: key
}

private fun auditFieldOrder(key: String): Int = auditFieldSortOrder[key] ?: Int.MAX_VALUE

private val auditFieldLabels: Map<String, String> = mapOf(
    "name" to "设备名称",
    "metricNo" to "计量编号",
    "assetNo" to "资产编号",
    "serialNo" to "出厂编号",
    "abcClass" to "ABC分类",
    "dept" to "使用部门",
    "location" to "设备位置",
    "responsiblePerson" to "责任人",
    "useStatus" to "使用状态",
    "status" to "设备状态",
    "validity" to "有效性",
    "cycle" to "鉴定周期",
    "calDate" to "本次校准时间",
    "nextDate" to "下次校准时间",
    "calibrationResult" to "校准结果",
    "remark" to "备注",
    "manufacturer" to "制造厂",
    "model" to "设备型号",
    "purchaseDate" to "采购时间",
    "purchasePrice" to "采购价格",
    "graduationValue" to "分度值",
    "testRange" to "测试范围",
    "allowableError" to "允许误差",
    "serviceLife" to "使用年限",
    "submittedBy" to "提交人",
    "submittedAt" to "提交时间",
    "approvedBy" to "审批人",
    "approvedAt" to "审批时间",
    "rejectReason" to "驳回原因",
    "entityType" to "对象类型",
    "type" to "操作类型"
)

private val auditFieldSortOrder: Map<String, Int> = mapOf(
    "name" to 1,
    "metricNo" to 2,
    "assetNo" to 3,
    "serialNo" to 4,
    "abcClass" to 5,
    "dept" to 6,
    "location" to 7,
    "responsiblePerson" to 8,
    "useStatus" to 9,
    "status" to 10,
    "validity" to 11,
    "cycle" to 12,
    "calDate" to 13,
    "nextDate" to 14,
    "calibrationResult" to 15,
    "remark" to 16,
    "manufacturer" to 17,
    "model" to 18,
    "purchaseDate" to 19,
    "purchasePrice" to 20,
    "graduationValue" to 21,
    "testRange" to 22,
    "allowableError" to 23,
    "serviceLife" to 24
)
