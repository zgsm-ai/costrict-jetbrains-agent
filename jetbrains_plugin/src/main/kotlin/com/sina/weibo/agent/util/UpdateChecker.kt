// SPDX-FileCopyrightText: 2025 Weibo, Inc.
//
// SPDX-License-Identifier: Apache-2.0

package com.sina.weibo.agent.util

import com.intellij.ide.actions.ShowLogAction
import com.intellij.ide.plugins.*
import com.intellij.notification.NotificationAction
import com.intellij.notification.NotificationGroup
import com.intellij.notification.NotificationType
import com.intellij.openapi.Disposable
import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.components.Service
import com.intellij.openapi.components.service
import com.intellij.openapi.diagnostic.logger
import com.intellij.openapi.extensions.PluginDescriptor
import com.intellij.openapi.extensions.PluginId
import com.intellij.openapi.progress.ProgressIndicator
import com.intellij.openapi.progress.ProgressManager
import com.intellij.openapi.progress.Task
import com.intellij.openapi.updateSettings.impl.PluginDownloader
import com.intellij.openapi.updateSettings.impl.UpdateSettings
import com.intellij.util.Alarm
import com.sina.weibo.agent.util.PluginConstants.PLUGIN_ID
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.prefs.Preferences

@Service(Service.Level.APP)
class UpdateChecker : Disposable {
    private val logger = logger<UpdateChecker>()
    override fun dispose() {}

    companion object {
        const val UPDATE_URL = "http://wecode.api.weibo.com/idea/download/updatePlugins.xml"

        val instance: UpdateChecker
            get() = service()
    }

    val STICKY_GROUP: NotificationGroup? = NotificationGroup.findRegisteredGroup("roo-cline-sticky")

    private val preferences: Preferences = Preferences.userNodeForPackage(UpdateChecker::class.java)
    private val alarm = Alarm(Alarm.ThreadToUse.POOLED_THREAD, this)
    private val checkQueued = AtomicBoolean(false)

    fun startChecking() {
        if (checkQueued.compareAndSet(/* expectedValue = */ false, /* newValue = */ true)) {
            alarm.addRequest(
                {
                    try {
                        checkForUpdates()
                    } catch (e: Exception) {
                        logger.warn("checkForUpdates fail.", e)
                    } finally {
                        checkQueued.set(false)
                    }
                },
                2000L,
            )
        }
    }

    private fun checkForUpdates() {
        if (!UpdateSettings.getInstance().isPluginsCheckNeeded) return
        if (ApplicationManager.getApplication().isHeadlessEnvironment) return
        if (!needCheckDelay()) return

        val pluginId = PluginId.getId(PLUGIN_ID)
        val currentPluginDesc = PluginManagerCore.getPlugin(pluginId)

        currentPluginDesc?.let {
            val url = it.url ?: UPDATE_URL
            val currentVersion = currentPluginDesc.version
            val nodes = RepositoryHelper.loadPlugins(url, null, null)
            val lastPluginDesc = nodes.find { pluginNode -> pluginId.idString == pluginNode.pluginId.idString }
            lastPluginDesc?.let {
                val latestVersion = lastPluginDesc.version
                if (isNewVersionAvailable(currentVersion, latestVersion) && needLastNewVersionAvailableNotify(lastPluginDesc)) {
                    installPluginUpdate(lastPluginDesc)
                }
            }
        }
    }

    private fun installPluginUpdate(
        descriptor: IdeaPluginDescriptor
    ) {
        val pluginDownloader = PluginDownloader.createDownloader(descriptor, descriptor.url, null)
        ProgressManager.getInstance().run(object : Task.Backgroundable(
            null, "Downloading plugins",true, PluginManagerUISettings.getInstance(),
        ) {
            override fun run(indicator: ProgressIndicator) {
                var installed = false
                val prepareResult = try {
                    pluginDownloader.prepareToInstall(indicator)
                } catch (e: IOException) {
                    false
                }

                if (prepareResult) {
                    installed = true
                    pluginDownloader.install()
                    // Update successful, record version information
                    preferences.putBoolean(descriptor.version, true)
                    ApplicationManager.getApplication().invokeLater {
                        PluginManagerMain.notifyPluginsUpdated(null)
                    }
                }

                ApplicationManager.getApplication().invokeLater {
                    if (!installed) {
                        notifyNotInstalled()
                    }
                }
            }

            override fun onCancel() {
                // do nothing
            }
        })
    }

    private fun isNewVersionAvailable(currentVersion: String, latestVersion: String): Boolean {
        return compareVersions(latestVersion, currentVersion) && !preferences.getBoolean(latestVersion, false)
    }

    private fun compareVersions(version1: String, version2: String): Boolean {
        val v1Parts = version1.split(".").map { it.toInt() }
        val v2Parts = version2.split(".").map { it.toInt() }

        val maxLength = maxOf(v1Parts.size, v2Parts.size)
        for (i in 0 until maxLength) {
            val v1 = if (i < v1Parts.size) v1Parts[i] else 0
            val v2 = if (i < v2Parts.size) v2Parts[i] else 0

            if (v1 > v2) {
                return true
            } else if (v1 < v2) {
                return false
            }
        }
        return false
    }

    private fun needLastNewVersionAvailableNotify(lastPluginDescriptor: PluginDescriptor): Boolean {
        val lastNotificationTime = preferences.getLong(getNotifyNewVersionTimeKey(lastPluginDescriptor.version), -1L)
        val currentTime = System.currentTimeMillis()
        return lastNotificationTime == -1L // Never notified
                || (currentTime - lastNotificationTime >= (7 * 24 * 60 * 60 * 1000)) // For the same version, notify once every 7 days
    }

    private fun needCheckDelay(): Boolean {
        val lastNotificationTime = preferences.getLong("check_delay", -1L)
        val currentTime = System.currentTimeMillis()
        return lastNotificationTime == -1L // Never notified
                || (currentTime - lastNotificationTime >= (60 * 60 * 1000)) // For the same version, check for updates every 1 hour
    }

    private fun notifyNotInstalled() {
        STICKY_GROUP?.createNotification("roo-cline", "roo-cline update was not installed", NotificationType.INFORMATION)
            ?.addAction(
                NotificationAction.createSimpleExpiring("See the log for more information") {
                    ShowLogAction.showLog()
                }
            )?.notify(null)
    }

    private fun getNotifyNewVersionTimeKey(version: String): String {
        return "time_${version}"
    }
}
