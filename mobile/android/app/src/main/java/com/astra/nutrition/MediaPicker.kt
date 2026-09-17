package com.astra.nutrition

import android.content.Context
import android.net.Uri
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import kotlinx.coroutines.launch

private suspend fun Uri.toDataUrl(context: Context): String {
    val mimeType = context.contentResolver.getType(this) ?: "application/octet-stream"
    val bytes = context.contentResolver.openInputStream(this)?.use { it.readBytes() }
        ?: error("Не удалось прочитать выбранный файл")
    return "data:$mimeType;base64,${Base64.encodeToString(bytes, Base64.NO_WRAP)}"
}

@Composable
fun MobileImagePickerButton(
    label: String,
    enabled: Boolean = true,
    onPicked: (List<String>) -> Unit,
    onError: (String) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        scope.launch {
            runCatching { uris.map { it.toDataUrl(context) } }
                .onSuccess(onPicked)
                .onFailure { onError(it.message ?: "Не удалось загрузить фото") }
        }
    }
    OutlinedButton(onClick = { launcher.launch(arrayOf("image/*")) }, enabled = enabled, modifier = Modifier) {
        Text(label, maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
fun MobileVideoPickerButton(
    label: String,
    enabled: Boolean = true,
    onPicked: (String) -> Unit,
    onError: (String) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            runCatching { uri.toDataUrl(context) }
                .onSuccess(onPicked)
                .onFailure { onError(it.message ?: "Не удалось загрузить видео") }
        }
    }
    OutlinedButton(onClick = { launcher.launch("video/*") }, enabled = enabled, modifier = Modifier) {
        Text(label, maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis)
    }
}
