package com.metrology.app

import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Dispatcher
import okhttp3.Protocol
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

object ApiClient {
    private const val DEFAULT_BASE_URL = "https://cms.zglweb.cn:6606/"

    fun create(sessionManager: SessionManager): ApiService {
        val baseUrl = resolveBaseUrl()
        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(createStandardClient(sessionManager))
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }

    fun createFileTransfer(sessionManager: SessionManager): ApiService {
        val baseUrl = resolveBaseUrl()
        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(createFileTransferClient(sessionManager))
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }

    private fun createStandardClient(sessionManager: SessionManager): OkHttpClient {
        val authInterceptor = Interceptor { chain ->
            val original = chain.request()
            val token = sessionManager.token
            val req = if (!token.isNullOrBlank()) {
                original.newBuilder()
                    .header("Authorization", "Bearer $token")
                    .build()
            } else {
                original
            }
            chain.proceed(req)
        }

        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        }

        return OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .addInterceptor(authInterceptor)
            .addInterceptor(logging)
            .build()
    }

    private fun createFileTransferClient(sessionManager: SessionManager): OkHttpClient {
        val authInterceptor = Interceptor { chain ->
            val original = chain.request()
            val token = sessionManager.token
            val req = if (!token.isNullOrBlank()) {
                original.newBuilder()
                    .header("Authorization", "Bearer $token")
                    .build()
            } else {
                original
            }
            chain.proceed(req)
        }
        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        }
        val dispatcher = Dispatcher().apply {
            maxRequests = 4
            maxRequestsPerHost = 1
        }
        return OkHttpClient.Builder()
            .dispatcher(dispatcher)
            .protocols(listOf(Protocol.HTTP_1_1))
            .connectTimeout(20, TimeUnit.SECONDS)
            // Large file preview/download should not fail because of client-side read timeout.
            .readTimeout(0, TimeUnit.SECONDS)
            .writeTimeout(0, TimeUnit.SECONDS)
            .callTimeout(0, TimeUnit.SECONDS)
            .addInterceptor(authInterceptor)
            .addInterceptor(logging)
            .build()
    }

    private fun resolveBaseUrl(): String {
        val raw = BuildConfig.MOBILE_WEB_URL.trim()
        val normalized = when {
            raw.isBlank() -> DEFAULT_BASE_URL
            raw.startsWith("http://", ignoreCase = true) -> raw
            raw.startsWith("https://", ignoreCase = true) -> raw
            else -> "https://$raw"
        }
        return normalized.trimEnd('/') + "/"
    }
}
