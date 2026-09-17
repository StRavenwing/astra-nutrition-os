package com.astra.nutrition

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

object AstraTheme {
    val blue = Color(0xFFE8732A)
    val blueDark = Color(0xFFFF9153)
    val green = Color(0xFFE8732A)
    val greenDark = Color(0xFFFF9153)
    val amber = Color(0xFFE8732A)
    val ink = Color(0xFF1A1A1A)
    val inkDark = Color(0xFFFAFAF8)
    val muted = Color(0xFFA09E9B)
    val mutedDark = Color(0xFFA0A0A0)
    val canvas = Color(0xFFFFFFFF)
    val canvasDark = Color(0xFF0A0908)
    val surface = Color(0xFFFFFFFF)
    val surfaceDark = Color(0xFF161513)
    val surfaceElevatedDark = Color(0xFF1A1A1A)
    val line = Color(0xFFF0EEEA)
    val lineDark = Color(0xFF3A332E)
    val danger = Color(0xFFFF3B30)
}

private val lightColors = lightColorScheme(
    primary = AstraTheme.blue,
    secondary = AstraTheme.blue,
    background = AstraTheme.canvas,
    surface = AstraTheme.surface,
    surfaceVariant = AstraTheme.line,
    outline = AstraTheme.line,
    onBackground = AstraTheme.ink,
    onSurface = AstraTheme.ink,
    onSurfaceVariant = AstraTheme.muted
)

private val darkColors = darkColorScheme(
    primary = AstraTheme.blueDark,
    secondary = AstraTheme.blueDark,
    background = AstraTheme.canvasDark,
    surface = AstraTheme.surfaceDark,
    surfaceVariant = AstraTheme.surfaceElevatedDark,
    outline = AstraTheme.lineDark,
    onBackground = AstraTheme.inkDark,
    onSurface = AstraTheme.inkDark,
    onSurfaceVariant = AstraTheme.mutedDark
)

@Composable
fun AstraTheme(darkTheme: Boolean = true, content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (darkTheme) darkColors else lightColors,
        typography = Typography(),
        content = content
    )
}

/** Full-page replacement for modal forms and confirmations on mobile. */
@Composable
fun MobileFullScreenDialog(
    onDismissRequest: () -> Unit,
    title: @Composable () -> Unit,
    text: @Composable () -> Unit,
    confirmButton: @Composable () -> Unit,
    dismissButton: @Composable () -> Unit
) {
    BackHandler(onBack = onDismissRequest)
    Column(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            TextButton(onClick = onDismissRequest) { Text("‹ Назад") }
            Box(Modifier.weight(1f).padding(top = 8.dp)) { title() }
        }
        Column(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            text()
        }
        Row(
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.End)
        ) {
            dismissButton()
            confirmButton()
        }
    }
}

// Existing call sites use the Material-style API, but every instance is rendered as a screen.
@Composable
fun MobileModalScreen(
    onDismissRequest: () -> Unit,
    title: (@Composable () -> Unit)? = null,
    text: (@Composable () -> Unit)? = null,
    confirmButton: @Composable () -> Unit,
    dismissButton: (@Composable () -> Unit)? = null
) {
    MobileFullScreenDialog(
        onDismissRequest = onDismissRequest,
        title = { title?.invoke() },
        text = { text?.invoke() },
        confirmButton = confirmButton,
        dismissButton = { dismissButton?.invoke() }
    )
}
