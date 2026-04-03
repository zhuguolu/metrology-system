package com.metrology.app

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import com.metrology.app.databinding.FragmentSystemMaintenanceBinding
import kotlinx.coroutines.launch

class SystemMaintenanceFragment : Fragment() {
    private var _binding: FragmentSystemMaintenanceBinding? = null
    private val binding get() = _binding!!

    private val viewModel: SystemMaintenanceViewModel by lazy {
        ViewModelProvider(
            this,
            AppViewModelFactory { SystemMaintenanceViewModel(AppGraph.repository) }
        )[SystemMaintenanceViewModel::class.java]
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentSystemMaintenanceBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.buttonSaveSettings.setOnClickListener {
            val current = viewModel.uiState.value.settings
            val payload = SettingsDto(
                warningDays = binding.inputWarningDays.text?.toString()?.toIntOrNull() ?: current?.warningDays,
                expiredDays = binding.inputExpiredDays.text?.toString()?.toIntOrNull() ?: current?.expiredDays,
                autoLedgerExportEnabled = binding.checkAutoExport.isChecked,
                databaseBackupEnabled = binding.checkAutoBackup.isChecked,
                cmsRootPath = binding.inputCmsPath.text?.toString(),
                ledgerExportPath = current?.ledgerExportPath,
                databaseBackupPath = current?.databaseBackupPath
            )
            viewModel.save(payload)
        }
        binding.buttonRunMaintenance.setOnClickListener {
            viewModel.runNow()
        }

        observeState()
        if (savedInstanceState == null) {
            viewModel.load()
        }
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                val settings = state.settings
                if (settings != null) {
                    if (!binding.inputWarningDays.hasFocus()) {
                        binding.inputWarningDays.setText((settings.warningDays ?: 315).toString())
                    }
                    if (!binding.inputExpiredDays.hasFocus()) {
                        binding.inputExpiredDays.setText((settings.expiredDays ?: 360).toString())
                    }
                    if (!binding.inputCmsPath.hasFocus()) {
                        binding.inputCmsPath.setText(settings.cmsRootPath.orEmpty())
                    }
                    binding.checkAutoExport.isChecked = settings.autoLedgerExportEnabled == true
                    binding.checkAutoBackup.isChecked = settings.databaseBackupEnabled == true
                    binding.txtExportPath.text = "${getString(R.string.settings_export_file)}: ${settings.ledgerExportPath.orEmpty()}"
                    binding.txtBackupPath.text = "${getString(R.string.settings_backup_file)}: ${settings.databaseBackupPath.orEmpty()}"
                }

                binding.txtMaintenanceStatus.text = when {
                    state.loading -> getString(R.string.label_loading)
                    !state.error.isNullOrBlank() -> state.error
                    !state.statusMessage.isNullOrBlank() -> state.statusMessage
                    else -> ""
                }
                binding.buttonSaveSettings.isEnabled = !state.loading
                binding.buttonRunMaintenance.isEnabled = !state.loading
            }
        }
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }
}
