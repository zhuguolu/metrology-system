package com.metrology.app

import android.app.AlertDialog
import android.content.Intent
import android.content.res.ColorStateList
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.fragment.app.Fragment
import com.metrology.app.databinding.FragmentMoreModulesBinding
import com.metrology.app.databinding.ItemMoreEntryBinding
import kotlin.math.roundToInt

class MoreModulesFragment : Fragment() {
    private var _binding: FragmentMoreModulesBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentMoreModulesBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        configureCards()
        configureActions()
    }

    private fun configureCards() {
        configureMoreCard(binding.moreFiles, R.drawable.ic_nav_files, "我的文件", R.drawable.bg_more_icon_chip_blue, R.color.moreIconTintBlue)
        configureMoreCard(binding.moreWebdav, R.drawable.ic_nav_webdav, "网络挂载", R.drawable.bg_more_icon_chip_green, R.color.moreIconTintGreen)
        configureMoreCard(binding.moreChanges, R.drawable.ic_nav_changes, "变更记录", R.drawable.bg_more_icon_chip_blue, R.color.moreIconTintBlue)
        configureMoreCard(binding.moreStatus, R.drawable.ic_nav_status, "使用状态", R.drawable.bg_more_icon_chip_green, R.color.moreIconTintGreen)
        configureMoreCard(binding.moreDepartments, R.drawable.ic_nav_departments, "部门管理", R.drawable.bg_more_icon_chip_orange, R.color.moreIconTintOrange)
        configureMoreCard(binding.moreUsers, R.drawable.ic_nav_users, "用户管理", R.drawable.bg_more_icon_chip_purple, R.color.moreIconTintPurple)
        configureMoreCard(binding.moreSettings, R.drawable.ic_nav_settings, "系统维护", R.drawable.bg_more_icon_chip_slate, R.color.moreIconTintSlate)
    }

    private fun configureActions() {
        binding.moreFiles.root.setOnClickListener { open(MainDestination.FILES) }
        binding.moreStatus.root.setOnClickListener { open(MainDestination.STATUS) }
        binding.moreDepartments.root.setOnClickListener { open(MainDestination.DEPARTMENTS) }
        binding.moreChanges.root.setOnClickListener { open(MainDestination.CHANGES) }
        binding.moreWebdav.root.setOnClickListener { open(MainDestination.WEBDAV) }
        binding.moreUsers.root.setOnClickListener { open(MainDestination.USERS) }
        binding.moreSettings.root.setOnClickListener { open(MainDestination.SETTINGS) }
        binding.moreLogout.setOnClickListener { showLogoutConfirmDialog() }
    }

    private fun showLogoutConfirmDialog() {
        val content = layoutInflater.inflate(R.layout.dialog_logout_confirm, null)
        val dialog = AlertDialog.Builder(requireContext())
            .setView(content)
            .create()
        dialog.window?.setBackgroundDrawableResource(R.drawable.bg_card)
        dialog.setOnShowListener {
            val width = (resources.displayMetrics.widthPixels * 0.92f).roundToInt()
            dialog.window?.setLayout(width, ViewGroup.LayoutParams.WRAP_CONTENT)
        }

        content.findViewById<TextView>(R.id.txtLogoutAccountName).text =
            AppGraph.repository.username().ifBlank { "-" }
        content.findViewById<View>(R.id.buttonCancelLogout).setOnClickListener {
            dialog.dismiss()
        }
        content.findViewById<View>(R.id.buttonConfirmLogout).setOnClickListener {
            dialog.dismiss()
            logoutNow()
        }

        dialog.show()
    }

    private fun open(destination: MainDestination) {
        (activity as? MainActivity)?.navigateFromMore(destination)
    }

    private fun logoutNow() {
        PushWorkScheduler.cancel(requireContext())
        AppGraph.repository.logout()
        startActivity(Intent(requireContext(), LoginActivity::class.java))
        requireActivity().finish()
    }

    private fun configureMoreCard(
        card: ItemMoreEntryBinding,
        iconRes: Int,
        label: String,
        iconChipBgRes: Int,
        iconTintColorRes: Int
    ) {
        card.moreCardIconChip.setBackgroundResource(iconChipBgRes)
        card.moreCardIconLight.setImageResource(iconRes)
        card.moreCardIcon.setImageResource(iconRes)
        card.moreCardIcon.imageTintList = ColorStateList.valueOf(requireContext().getColor(iconTintColorRes))
        card.moreCardLabel.text = label
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }
}
