// SPDX-FileCopyrightText: 2025 Weibo, Inc.
//
// SPDX-License-Identifier: Apache-2.0

package com.sina.weibo.agent.ui

import com.intellij.openapi.actionSystem.ActionManager
import com.intellij.openapi.actionSystem.AnAction
import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.diagnostic.Logger
import com.intellij.openapi.project.Project
import com.intellij.openapi.wm.ToolWindow
import com.intellij.openapi.wm.ToolWindowFactory
import com.intellij.ui.content.ContentFactory
import com.sina.weibo.agent.actions.OpenDevToolsAction
import com.sina.weibo.agent.plugin.WecoderPlugin
import com.sina.weibo.agent.plugin.WecoderPluginService
import com.sina.weibo.agent.plugin.DEBUG_MODE
import com.sina.weibo.agent.webview.WebViewCreationCallback
import com.sina.weibo.agent.webview.WebViewInstance
import com.sina.weibo.agent.webview.WebViewManager
import java.awt.BorderLayout
import javax.swing.JLabel
import javax.swing.JPanel

class RooToolWindowFactory : ToolWindowFactory {

    override fun createToolWindowContent(project: Project, toolWindow: ToolWindow) {
        // Initialize plugin service
        val pluginService = WecoderPlugin.getInstance(project)
        pluginService.initialize(project)

        // toolbar
        val titleActions = mutableListOf<AnAction>()
        val action = ActionManager.getInstance().getAction("WecoderToolbarGroup")
        if (action != null) {
            titleActions.add(action)
        }
        // Add developer tools button only in debug mode
        if ( WecoderPluginService.getDebugMode() != DEBUG_MODE.NONE) {
            titleActions.add(OpenDevToolsAction { project.getService(WebViewManager::class.java).getLatestWebView() })
        }
        
        toolWindow.setTitleActions(titleActions)

        // webview panel
        val rooToolWindowContent = RooToolWindowContent(project, toolWindow)
        val contentFactory = ContentFactory.getInstance()
        val content = contentFactory.createContent(
            rooToolWindowContent.content,
            "",
            false
        )
        toolWindow.contentManager.addContent(content)
    }

    private class RooToolWindowContent(
        private val project: Project,
        private val toolWindow: ToolWindow
    ) : WebViewCreationCallback {
        private val logger = Logger.getInstance(RooToolWindowContent::class.java)
        
        // Get WebViewManager instance
        private val webViewManager = project.getService(WebViewManager::class.java)
        
        // Content panel
        private val contentPanel = JPanel(BorderLayout())
        
        // Placeholder label
        private val placeholderLabel = JLabel("Waiting for WebView initialization...")
        
        // Main panel
        val content: JPanel = JPanel(BorderLayout()).apply {
            // Add placeholder info
            add(placeholderLabel, BorderLayout.CENTER)
            
            // Set content panel
            contentPanel.add(placeholderLabel, BorderLayout.CENTER)
            add(contentPanel, BorderLayout.CENTER)
        }
        
        init {
            // Try to get existing WebView
            webViewManager.getLatestWebView()?.let { webView ->
                ApplicationManager.getApplication().invokeLater {
                    updateUIWithWebView(webView)
                }
            }?:webViewManager.addCreationCallback(this, toolWindow.disposable)
        }
        
        /**
         * WebView creation callback implementation
         */
        override fun onWebViewCreated(instance: WebViewInstance) {
            // Ensure UI update in EDT thread
            ApplicationManager.getApplication().invokeLater {
                updateUIWithWebView(instance)
            }
        }
        
        /**
         * Update UI with WebView
         */
        private fun updateUIWithWebView(webView: WebViewInstance) {
            logger.info("Received WebView creation notification, updating UI: ${webView.viewType}/${webView.viewId}")
            
            // Remove old content
            contentPanel.removeAll()
            
            // Add WebView component
            contentPanel.add(webView.browser.component, BorderLayout.CENTER)
            
            // Relayout
            contentPanel.revalidate()
            contentPanel.repaint()
            
            logger.info("WebView loaded into tool window")
        }
    }
}