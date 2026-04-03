package com.metrology.app

import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.view.inputmethod.EditorInfo
import androidx.activity.enableEdgeToEdge
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import com.metrology.app.databinding.ActivityLoginBinding
import kotlinx.coroutines.launch

class LoginActivity : FontScaleActivity() {

    private lateinit var binding: ActivityLoginBinding
    private var passwordVisible = false
    private val viewModel: LoginViewModel by lazy {
        ViewModelProvider(
            this,
            AppViewModelFactory { LoginViewModel(AppGraph.repository) }
        )[LoginViewModel::class.java]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)
        applyInsets()
        setupActions()
        observeState()
    }

    private fun applyInsets() {
        ViewCompat.setOnApplyWindowInsetsListener(binding.loginRoot) { view, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(
                view.paddingLeft,
                systemBars.top + 24,
                view.paddingRight,
                systemBars.bottom + 20
            )
            insets
        }
        ViewCompat.requestApplyInsets(binding.loginRoot)
    }

    private fun setupActions() {
        binding.buttonLogin.setOnClickListener {
            doLogin()
        }
        binding.buttonTogglePassword.setOnClickListener {
            passwordVisible = !passwordVisible
            updatePasswordFieldMode()
        }
        binding.inputPassword.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                doLogin()
                true
            } else {
                false
            }
        }
        updatePasswordFieldMode()
    }

    private fun updatePasswordFieldMode() {
        val selection = binding.inputPassword.selectionStart.coerceAtLeast(0)
        binding.inputPassword.inputType = if (passwordVisible) {
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
        } else {
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        }
        binding.inputPassword.setSelection(selection)
        binding.buttonTogglePassword.alpha = if (passwordVisible) 1f else 0.6f
    }

    private fun doLogin() {
        viewModel.login(
            username = binding.inputUsername.text?.toString().orEmpty(),
            password = binding.inputPassword.text?.toString().orEmpty()
        )
    }

    private fun observeState() {
        lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                binding.loginProgress.visibility = if (state.loading) android.view.View.VISIBLE else android.view.View.GONE
                binding.loginError.visibility = if (state.error.isNullOrBlank()) android.view.View.GONE else android.view.View.VISIBLE
                binding.loginError.text = state.error
                binding.buttonLogin.isEnabled = !state.loading
            }
        }

        lifecycleScope.launch {
            viewModel.loginSuccess.collect {
                PushWorkScheduler.ensureScheduled(this@LoginActivity)
                startActivity(Intent(this@LoginActivity, MainActivity::class.java))
                finish()
            }
        }
    }
}
